import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_a_man/core/constants/auth_redirects.dart';
import 'package:match_a_man/core/router/route_names.dart';
import 'package:match_a_man/core/utils/error_messages.dart';
import 'package:match_a_man/core/utils/validators.dart';
import 'package:match_a_man/features/auth/auth_models.dart';

void main() {
  group('email confirmation link flow', () {
    test('signup session null maps to confirmation pending result', () {
      const result = EmailVerificationRequired(email: 'tester@example.com');

      expect(result.email, 'tester@example.com');
      expect(
        const AuthState.emailVerificationRequired(
          pendingEmail: 'tester@example.com',
        ).needsEmailVerification,
        isTrue,
      );
    });

    test('register submit handles null-session signup with launch dialog', () {
      final page = File(
        'lib/features/auth/register_page.dart',
      ).readAsStringSync();

      expect(page, contains('final result = await ref'));
      expect(page, contains('signUpWithEmailAndPassword'));
      expect(page, contains('result is EmailVerificationRequired'));
      expect(
        page,
        contains(
          'Hesabını oluşturduk. Devam etmek için e-posta adresine gönderilen doğrulama bağlantısına tıkla.',
        ),
      );
      expect(page, contains('E-postanı kontrol et'));
      expect(page, contains('Giriş ekranına dön'));
      expect(page, contains('_showEmailVerificationDialog'));
      expect(page, contains('RouteNames.login'));
      expect(page, isNot(contains("queryParameters: {'password'")));
      expect(page, isNot(contains('RouteNames.usernameOnboarding')));
    });

    test('auth controller returns signup outcome for register navigation', () {
      final provider = File(
        'lib/features/auth/auth_provider.dart',
      ).readAsStringSync();

      expect(
        provider,
        contains('Future<EmailSignUpResult?> signUpWithEmailAndPassword'),
      );
      expect(provider, contains('return result;'));
      expect(provider, contains('AuthState.emailVerificationRequired'));
      expect(provider, contains('E-posta adresini doğrulaman gerekiyor.'));
      expect(provider, isNot(contains('RouteNames.usernameOnboarding')));
    });

    test('route constants expose pending, forgot, and reset screens', () {
      expect(RouteNames.emailVerification, 'emailVerification');
      expect(RoutePaths.emailVerification, '/auth/email-verification');
      expect(RouteNames.forgotPassword, 'forgotPassword');
      expect(RoutePaths.forgotPassword, '/auth/forgot-password');
      expect(RouteNames.resetPassword, 'resetPassword');
      expect(RoutePaths.resetPassword, '/reset-password');
      expect(RouteNames.usernameOnboarding, 'usernameOnboarding');
      expect(RoutePaths.usernameOnboarding, '/onboarding/username');
    });

    test('mobile redirect URLs use app scheme', () {
      expect(
        AuthRedirects.emailConfirmationUrl(isWeb: false),
        'matchaman://auth/callback',
      );
      expect(
        AuthRedirects.passwordResetUrl(isWeb: false),
        'matchaman://reset-password',
      );
    });

    test('friendly auth link errors stay Turkish and generic', () {
      expect(
        AuthLinkMessages.resendConfirmationError(Exception('rate limit')),
        'Çok sık bağlantı istedin. Biraz bekleyip tekrar dene.',
      );
      expect(
        AuthLinkMessages.passwordResetError(Exception('network down')),
        'Bağlantı sorunu var. Lütfen tekrar dene.',
      );
      expect(
        AuthLinkMessages.updatePasswordError(Exception('expired token')),
        'Şifre sıfırlama bağlantısı geçersiz veya süresi dolmuş olabilir.',
      );
    });

    test('central auth error mapper returns Turkish messages', () {
      expect(
        friendlyErrorMessage(Exception('Email not confirmed')),
        'E-posta adresini doğrulaman gerekiyor.',
      );
      expect(
        friendlyErrorMessage(Exception('Invalid login credentials')),
        'E-posta veya şifre hatalı.',
      );
      expect(
        friendlyErrorMessage(Exception('weak password')),
        'Daha güçlü bir şifre belirlemelisin.',
      );
      expect(
        friendlyErrorMessage(Exception('expired recovery token')),
        'Bağlantının süresi dolmuş olabilir. Yeni bağlantı iste.',
      );
      expect(
        friendlyErrorMessage(Exception('invalid recovery token')),
        'Bu bağlantı geçersiz görünüyor.',
      );
    });

    test('forgot and reset password validation is local', () {
      expect(Validators.email('bad-email'), 'Geçerli bir e-posta adresi gir.');
      expect(Validators.password('short'), 'Şifre en az 8 karakter olmalı.');
      expect(
        Validators.confirmPassword('password-1', 'password-2'),
        'Şifreler eşleşmiyor.',
      );
    });

    test('auth service uses link APIs without service role', () {
      final service = File(
        'lib/features/auth/auth_service.dart',
      ).readAsStringSync();

      expect(service, contains('signUp('));
      expect(service, contains('emailRedirectTo'));
      expect(service, contains('resendSignupConfirmationEmail'));
      expect(service, contains('OtpType.signup'));
      expect(service, contains('resetPasswordForEmail'));
      expect(service, contains('updateUser'));
      expect(service, isNot(contains('service_role')));
      expect(service, isNot(contains('verifyOTP')));
    });

    test('pending screen has no OTP/code input', () {
      final page = File(
        'lib/features/auth/email_verification_page.dart',
      ).readAsStringSync();

      expect(page, contains('E-postanı doğrula'));
      expect(
        page,
        contains(
          'Hesabını oluşturduk. Devam etmek için e-posta adresine gönderilen doğrulama bağlantısına tıkla.',
        ),
      );
      expect(
        page,
        contains(
          'Bağlantıyı açtıktan sonra uygulamaya dönüp giriş yapabilirsin.',
        ),
      );
      expect(page, contains('E-postayı tekrar gönder'));
      expect(page, contains('Giriş ekranına dön'));
      expect(page, contains('E-postayı değiştir'));
      expect(page, isNot(contains('TextFormField')));
      expect(page.toLowerCase(), isNot(contains('otp')));
      expect(page, isNot(contains('Doğrulama kodu')));
      expect(page, isNot(contains('123456')));
    });

    test('auth provider keeps unverified users out of the main app', () {
      final provider = File(
        'lib/features/auth/auth_provider.dart',
      ).readAsStringSync();

      expect(provider, contains('AuthState.emailVerificationRequired'));
      expect(provider, contains('E-posta adresini'));
      expect(provider, contains('doğrulaman gerekiyor.'));
      expect(provider, contains('_isEmailNotConfirmedError'));
      expect(provider, isNot(contains('RouteNames.events')));
      expect(provider, isNot(contains('verifyOTP')));
    });

    test('router sends missing-username users to username onboarding', () {
      final router = File('lib/core/router/app_router.dart').readAsStringSync();

      expect(router, contains('needsEmailVerification'));
      expect(
        router,
        contains('authState.status == AuthStatus.emailVerificationRequired'),
      );
      expect(router, contains('needsEmailVerification && !isAuthRoute'));
      expect(router, contains('RoutePaths.emailVerification'));
      expect(
        router,
        contains(
          '[Router] email confirmation pending allowed unauthenticated=true',
        ),
      );
      expect(router, contains('needsUsernameOnboarding'));
      expect(router, contains('RoutePaths.usernameOnboarding'));
      expect(router, contains('RoutePaths.resetPassword'));
      expect(router, contains('RoutePaths.accountDeletionPending'));
      expect(router, isNot(contains('needsProfileCompletion')));
    });

    test('setup doc uses ConfirmationURL as primary flow', () {
      final doc = File('docs/email_auth_link_setup.md').readAsStringSync();

      expect(doc, contains('{{ .ConfirmationURL }}'));
      expect(doc, contains('matchaman://auth/callback'));
      expect(doc, contains('matchaman://reset-password'));
      expect(doc, contains('matchaman://**'));
      expect(doc, contains('Do not use the 6-digit OTP token'));
    });

    test('real device QA doc covers manual email auth flows', () {
      final doc = File('docs/email_auth_real_device_qa.md').readAsStringSync();

      expect(doc, contains('Fresh Email Signup'));
      expect(doc, contains('Confirmation Link'));
      expect(doc, contains('Unverified Login'));
      expect(doc, contains('Password Reset'));
      expect(doc, contains('flutter build apk --debug'));
      expect(doc, contains('YOUR_SUPABASE_URL'));
      expect(doc, contains('matchaman://auth/callback'));
      expect(doc, contains('matchaman://reset-password'));
    });

    test('auth onboarding QA doc covers first-user manual pass', () {
      final doc = File(
        'docs/auth_onboarding_real_device_qa.md',
      ).readAsStringSync();

      expect(doc, contains('Fresh Install'));
      expect(doc, contains('Email Confirmation'));
      expect(doc, contains('Username Onboarding'));
      expect(doc, contains('Password Reset'));
      expect(doc, contains('Tap register and do not press login manually.'));
      expect(doc, contains('Confirm the confirmation email arrives.'));
      expect(doc, contains('E-postanı doğrula'));
      expect(doc, contains('Kullanıcı adını seç'));
      expect(doc, contains('npx supabase db push'));
      expect(doc, contains('YOUR_SUPABASE_URL'));
      expect(doc, contains('YOUR_SUPABASE_ANON_KEY'));
    });
  });
}
