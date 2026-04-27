import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/services/crisis_ml_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (only exists locally — silently ignored in production)
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Initialize on-device ML crisis scorer (non-blocking: falls back to
  // keyword-only mode if the model asset is not yet present).
  await CrisisMlService.initialize();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://fdkwqzeyrcvxgqlpbjnp.supabase.co',
    anonKey:dotenv.env["ANON_KEY"]??"NULL_KEY",    // PKCE is the default and most secure flow for web OAuth
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(
    const ProviderScope(
      child: MindBridgeApp(),
    ),
  );
}
