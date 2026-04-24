import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

// ─── Score result ─────────────────────────────────────────────────────────────

class CrisisRiskScore {
  final double safe;
  final double distress;
  final double crisis;
  final bool available;

  const CrisisRiskScore({
    required this.safe,
    required this.distress,
    required this.crisis,
    this.available = true,
  });

  static const CrisisRiskScore unavailable = CrisisRiskScore(
    safe: 1.0,
    distress: 0.0,
    crisis: 0.0,
    available: false,
  );

  @override
  String toString() =>
      'CrisisRiskScore(safe=${safe.toStringAsFixed(3)}, '
      'distress=${distress.toStringAsFixed(3)}, '
      'crisis=${crisis.toStringAsFixed(3)})';
}

// ─── Isolate worker (top-level: required by Isolate.spawn) ───────────────────

void _mlWorkerMain(SendPort mainSendPort) {
  final inbox = ReceivePort();
  mainSendPort.send(inbox.sendPort); // handshake

  OrtSession? session;
  Map<String, int> vocab = {};

  inbox.listen((msg) {
    if (msg is! Map) return;
    final type    = msg['type']    as String?   ?? '';
    final replyTo = msg['replyTo'] as SendPort?;

    switch (type) {
      case 'init':
        try {
          OrtEnv.instance.init();
          final bytes          = msg['modelBytes'] as Uint8List;
          final raw            = msg['vocab']      as Map;
          final sessionOptions = OrtSessionOptions();
          session              = OrtSession.fromBuffer(bytes, sessionOptions);
          sessionOptions.release();
          vocab = Map<String, int>.from(raw);
          replyTo?.send({'status': 'ready'});
        } catch (e) {
          replyTo?.send({'status': 'error', 'message': e.toString()});
        }

      case 'score':
        if (session == null) {
          replyTo?.send([1.0, 0.0, 0.0]);
          return;
        }
        try {
          final text   = msg['text'] as String;
          final scores = _runInference(session!, vocab, text);
          replyTo?.send(scores);
        } catch (_) {
          replyTo?.send([1.0, 0.0, 0.0]);
        }

      case 'dispose':
        session?.release();
        inbox.close();
    }
  });
}

/// Runs tokenisation + model inference.
/// Called inside the background isolate — never on the UI thread.
List<double> _runInference(
  OrtSession session,
  Map<String, int> vocab,
  String text,
) {
  const maxLen = 128;

  // Tokenise: lowercase, strip non-alpha, split on whitespace
  final tokens = text
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9\s'']"), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .take(maxLen)
      .toList();

  // Encode: 0 = PAD, 1 = OOV, 2+ = known words
  final ids = Int32List(maxLen);
  for (var i = 0; i < tokens.length; i++) {
    ids[i] = vocab[tokens[i]] ?? 1;
  }

  // input: [1, 128] int32    output: [1, 3] float32
  final inputTensor = OrtValueTensor.createTensorWithDataList(ids, [1, maxLen]);
  final runOptions  = OrtRunOptions();
  try {
    final inputs  = {session.inputNames.first: inputTensor};
    final outputs = session.run(runOptions, inputs);
    final raw     = outputs.first?.value as List;
    return List<double>.from(raw.first as List);
  } finally {
    inputTensor.release();
    runOptions.release();
  }
}

// ─── Public service ───────────────────────────────────────────────────────────

class CrisisMlService {
  CrisisMlService._();

  static bool      _available  = false;
  static SendPort? _workerPort;
  static Isolate?  _isolate;

  static double distressMin = 0.42;
  static double crisisMin   = 0.72;
  static double tier3Min    = 0.91;

  static bool get isAvailable => _available;

  /// Call once from main() before runApp().
  /// Safe to await — loads assets and warms up the background isolate.
  /// On web or if the model asset is missing, sets isAvailable = false
  /// and returns silently so the keyword fallback takes over.
  static Future<void> initialize() async {
    // ONNX Runtime native bindings do not exist on web
    if (kIsWeb) {
      debugPrint('[CrisisMlService] Web platform — ONNX Runtime not supported, '
          'keyword fallback active.');
      return;
    }

    try {
      // rootBundle is only accessible from the main isolate, so we load
      // everything here and pass raw bytes into the worker.
      final modelData = await rootBundle.load(
          'assets/models/crisis_classifier.onnx');
      final modelBytes = modelData.buffer.asUint8List();

      if (modelBytes.isEmpty || modelBytes.length < 8) {
        debugPrint('[CrisisMlService] Model file missing or empty — '
            'run: python -m tf2onnx.convert --tflite crisis_classifier.tflite '
            '--output crisis_classifier.onnx --opset 13');
        return;
      }

      final vocabJson = await rootBundle
          .loadString('assets/models/crisis_vocab.json');
      final vocabRaw = jsonDecode(vocabJson) as Map;
      final vocab    = vocabRaw.map((k, v) =>
          MapEntry(k as String, (v as num).toInt()));

      if (vocab.isEmpty) {
        debugPrint('[CrisisMlService] Placeholder vocab detected — '
            'run the training script first.');
        return;
      }

      final threshJson = await rootBundle
          .loadString('assets/models/crisis_thresholds.json');
      final thresh = jsonDecode(threshJson) as Map;
      distressMin = (thresh['distress_min'] as num).toDouble();
      crisisMin   = (thresh['crisis_min']   as num).toDouble();
      tier3Min    = (thresh['tier3_min']    as num).toDouble();

      // Spawn a long-lived background isolate that owns the session.
      final handshake = ReceivePort();
      _isolate    = await Isolate.spawn(_mlWorkerMain, handshake.sendPort);
      _workerPort = await handshake.first as SendPort;

      // Send model bytes + vocab to the worker for one-time setup.
      final initReply = ReceivePort();
      _workerPort!.send({
        'type':       'init',
        'modelBytes': modelBytes,
        'vocab':      vocab,
        'replyTo':    initReply.sendPort,
      });

      final reply = await initReply.first as Map;
      initReply.close();

      _available = reply['status'] == 'ready';
      if (_available) {
        debugPrint('[CrisisMlService] ✓ Ready. '
            'distress≥$distressMin  crisis≥$crisisMin  tier3≥$tier3Min');
      } else {
        debugPrint('[CrisisMlService] ✗ Worker error: ${reply['message']}');
      }
    } catch (e) {
      _available = false;
      debugPrint('[CrisisMlService] ✗ Init failed: $e');
    }
  }

  /// Score [text] for crisis risk.
  /// Runs entirely in the background isolate — never blocks the UI thread.
  /// Returns [CrisisRiskScore.unavailable] if the model is not loaded or
  /// if inference takes longer than 500 ms (safety timeout).
  static Future<CrisisRiskScore> score(String text) async {
    if (!_available || _workerPort == null) {
      return CrisisRiskScore.unavailable;
    }

    final replyPort = ReceivePort();
    try {
      _workerPort!.send({
        'type':    'score',
        'text':    text,
        'replyTo': replyPort.sendPort,
      });

      final raw = await replyPort.first
          .timeout(const Duration(milliseconds: 500));

      final scores = raw as List;
      return CrisisRiskScore(
        safe:     (scores[0] as num).toDouble(),
        distress: (scores[1] as num).toDouble(),
        crisis:   (scores[2] as num).toDouble(),
      );
    } catch (_) {
      return CrisisRiskScore.unavailable;
    } finally {
      replyPort.close();
    }
  }

  /// Release the background isolate. Called when the app terminates.
  static void dispose() {
    _workerPort?.send({'type': 'dispose'});
    _isolate?.kill(priority: Isolate.immediate);
    _isolate    = null;
    _workerPort = null;
    _available  = false;
  }
}
