import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/supabase_service.dart';

Future<void> bootstrap() {
  final startup = runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      _installErrorHandlers();

      try {
        await SupabaseService.initialize();
        runApp(const MatchAManApp());
      } catch (error, stackTrace) {
        _logStartupError(error, stackTrace);
        runApp(const StartupFailureApp());
      }
    },
    _logStartupError,
  );
  return startup ?? Future.value();
}

void _installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _logStartupError(details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _logStartupError(error, stackTrace);
    return true;
  };
}

void _logStartupError(Object error, StackTrace? stackTrace) {
  debugPrint('[Startup] ${error.runtimeType}: $error');
}

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StartupFailureScreen(),
    );
  }
}

class StartupFailureScreen extends StatelessWidget {
  const StartupFailureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48),
                SizedBox(height: 16),
                Text(
                  'Uygulama başlatılamadı',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                Text(
                  'Yapılandırma eksik. Lütfen geliştiriciyle iletişime geç.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
