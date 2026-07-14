import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app.dart';
import 'services/supabase_service.dart';

Future<void> bootstrap() {
  final startup = runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    _installErrorHandlers();

    try {
      await SupabaseService.initialize();
      final firebaseReady = await initializeFirebaseForPush();
      if (firebaseReady) {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      }
      runApp(const MatchAManApp());
    } catch (error, stackTrace) {
      _logStartupError(error, stackTrace);
      runApp(const StartupFailureApp());
    }
  }, _logStartupError);
  return startup ?? Future.value();
}

@visibleForTesting
Future<bool> initializeFirebaseForPush({
  Future<FirebaseApp> Function()? initializeApp,
}) async {
  try {
    debugPrint('[Startup] Firebase push init started');
    await (initializeApp ?? Firebase.initializeApp)();
    debugPrint('[Startup] Firebase initialized for push transport');
    return true;
  } catch (error) {
    debugPrint('[Startup] Firebase push init skipped: ${error.runtimeType}');
    return false;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (error) {
    debugPrint(
      '[Notifications] background Firebase init skipped: '
      '${error.runtimeType}',
    );
  }
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
      locale: Locale('tr', 'TR'),
      supportedLocales: [Locale('tr', 'TR')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
