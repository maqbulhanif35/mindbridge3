import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '_csv_download_web.dart' if (dart.library.io) '_csv_download_stub.dart';

class CsvExporter {
  static void export({
    required String csvData,
    required String fileName,
    required void Function(String message) onMessage,
  }) {
    if (kIsWeb) {
      triggerCsvDownload(csvData, fileName);
      onMessage('CSV export started');
    } else {
      Clipboard.setData(ClipboardData(text: csvData));
      onMessage('CSV data copied to clipboard');
    }
  }
}
