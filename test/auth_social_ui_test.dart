import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/features/auth/auth_provider.dart';
import 'package:match_a_man/features/auth/auth_service.dart';
import 'package:match_a_man/features/auth/register_page.dart';
import 'package:match_a_man/features/auth/widgets/social_auth_buttons.dart';
import 'package:match_a_man/features/profile/profile_provider.dart';
import 'package:match_a_man/features/profile/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  testWidgets('Android social auth shows Google without Facebook or Apple', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialAuthButtons(
            isLoading: false,
            onGooglePressed: () {},
            onApplePressed: () {},
            showAppleButton: false,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Google ile devam et'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Google ile devam et'), findsNothing);
    expect(find.textContaining('Apple'), findsNothing);
    expect(find.textContaining('yakında'), findsNothing);
    expect(find.textContaining('Yakında'), findsNothing);
    expect(find.textContaining('Facebook'), findsNothing);
  });

  testWidgets('iOS social auth can show Apple without coming soon copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialAuthButtons(
            isLoading: false,
            onGooglePressed: () {},
            onApplePressed: () {},
            showAppleButton: true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Google ile devam et'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('Google ile devam et'), findsNothing);
    expect(find.byTooltip('Apple ile devam et'), findsOneWidget);
    expect(find.text('Apple ile devam et'), findsNothing);
    expect(find.textContaining('yakında'), findsNothing);
    expect(find.textContaining('Yakında'), findsNothing);
    expect(find.textContaining('Facebook'), findsNothing);
  });

  testWidgets('register social auth keeps terms acceptance gate', (
    tester,
  ) async {
    var googleStarted = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _FakeAuthService(onGoogleStart: () => googleStarted = true),
          ),
          profileServiceProvider.overrideWithValue(const _FakeProfileService()),
        ],
        child: const MaterialApp(home: RegisterPage()),
      ),
    );

    await tester.ensureVisible(find.byTooltip('Google ile devam et'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Google ile devam et'));
    await tester.pump();

    expect(googleStarted, isFalse);
    expect(
      find.textContaining('Devam etmek için Kullanıcı Sözleşmesi'),
      findsOneWidget,
    );
    expect(find.textContaining('Apple'), findsNothing);
  });

  testWidgets('Apple button stays hidden without a real callback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialAuthButtons(
            isLoading: false,
            onGooglePressed: () {},
            showAppleButton: true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Google ile devam et'), findsOneWidget);
    expect(find.byTooltip('Apple ile devam et'), findsNothing);
    expect(find.textContaining('yakÄ±nda'), findsNothing);
  });
}

class _FakeAuthService extends AuthService {
  const _FakeAuthService({required this.onGoogleStart});

  final VoidCallback onGoogleStart;

  @override
  supabase.User? get currentUser => null;

  @override
  Stream<supabase.AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<bool> signInWithGoogle() async {
    onGoogleStart();
    return true;
  }

  @override
  Future<bool> signInWithApple() async {
    return true;
  }
}

class _FakeProfileService extends ProfileService {
  const _FakeProfileService();
}
