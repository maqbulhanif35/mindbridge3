import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

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

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://fdkwqzeyrcvxgqlpbjnp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZka3dxemV5cmN2eGdxbHBiam5wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1MjUwOTcsImV4cCI6MjA4ODEwMTA5N30.ZpseLUTBAcFuJkYt33ojeswf0b3GlCLfOa3AuG6mmRM',
  );

  runApp(
    const ProviderScope(
      child: MindBridgeApp(),
    ),
  );
}
