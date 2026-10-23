import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../core/auth/auth_diagnostics.dart';
import '../core/auth/email_otp_auth_service.dart';
import '../services/data_service.dart';
import '../widgets/exercise_3d_viewer.dart';

enum _AuthStage {
  splash,
  welcome,
  login,
  register,
  verifyOtp,
}

class AuthOnboardingScreen extends StatefulWidget {
  const AuthOnboardingScreen({super.key});

  @override
  State<AuthOnboardingScreen> createState() => _AuthOnboardingScreenState();
}

class _AuthOnboardingScreenState extends State<AuthOnboardingScreen> {
  _AuthStage _stage = _AuthStage.splash;
  Timer? _resendCooldownTimer;

  // Login controllers (empty by default — no pre-filled demo credentials)
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _loginObscure = true;
  bool _rememberSession = true;
  bool _isSigningIn = false;
  String? _loginError;

  // Registration controllers
  final _regUsernameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();
  bool _regObscure = true;
  bool _confirmObscure = true;
  bool _acceptedTerms = false;
  String? _regError;
  bool _isRegistering = false;
  String? _regUsernameError;
  String? _regEmailError;
  String? _regPasswordError;
  String? _regConfirmError;
  String? _regTermsError;

  // 6-Digit OTP Verification controllers & state
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  int _resendSecondsRemaining = 60;
  String? _otpError;
  String? _otpSuccess;
  bool _isVerifyingOtp = false;
  bool _isResendingOtp = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 6; i++) {
      final index = i;
      _otpFocusNodes[index].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _otpControllers[index].text.isEmpty &&
            index > 0) {
          _otpFocusNodes[index - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
    _bootstrapSession();
  }

  /// Runs the encrypted-session check behind the splash without ever blocking
  /// it. A stalled secure-storage / platform-channel call previously left the
  /// app frozen on "Checking secure session…" forever, so the splash now always
  /// advances and the restore continues in the background: if a valid session
  /// is found, `notifyListeners()` switches the shell to the dashboard.
  Future<void> _bootstrapSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    final data = DataService.instance;
    if (!data.isAuthenticated && _stage == _AuthStage.splash) {
      setState(() {
        _stage = _AuthStage.welcome;
      });
    }

    if (data.isAuthenticated) return;
    unawaited(() async {
      try {
        await data
            .tryRestorePersistedSession()
            .timeout(const Duration(seconds: 3));
      } catch (error) {
        AuthDiagnostics.record(operation: 'restore_session', category: 'unexpected_failure');
      }
    }());
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regUsernameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmCtrl.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  double _calculatePasswordStrength(String pwd) {
    if (pwd.isEmpty) return 0.0;
    double score = 0;
    if (pwd.length >= 8) score += 0.25;
    if (pwd.length >= 12) score += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(pwd) && RegExp(r'[a-z]').hasMatch(pwd)) {
      score += 0.20;
    }
    if (RegExp(r'[0-9]').hasMatch(pwd)) score += 0.20;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(pwd)) score += 0.20;
    return score.clamp(0.0, 1.0);
  }

  String _passwordStrengthLabel(double s) {
    if (s <= 0.0) return 'Enter a password (8+ chars, upper/lower, number, symbol)';
    if (s < 0.45) return 'Weak — Add numbers, uppercase letters & symbols';
    if (s < 0.75) return 'Good — Meets minimum security requirements';
    return 'Strong — High-entropy password';
  }

  Color _passwordStrengthColor(double s) {
    if (s < 0.45) return AppTheme.errorColor;
    if (s < 0.75) return AppTheme.powerliftingAmber;
    return AppTheme.successColor;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataService.instance,
      builder: (context, _) {
        final data = DataService.instance;

        // If authenticated but onboarding is incomplete, show First-Time Fitness Onboarding
        if (data.isAuthenticated && !data.hasCompletedOnboarding) {
          return const FirstTimeFitnessOnboardingScreen();
        }

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: _buildCurrentStage(context, data),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentStage(BuildContext context, DataService data) {
    switch (_stage) {
      case _AuthStage.splash:
        return _buildSplashView();
      case _AuthStage.welcome:
        return _buildWelcomeView(context, data);
      case _AuthStage.login:
        return _buildLoginView(context, data);
      case _AuthStage.register:
        return _buildRegisterView(context, data);
      case _AuthStage.verifyOtp:
        return _buildVerifyOtpView(context, data);
    }
  }

  // ============================================================================
  // 1. SPLASH SCREEN WITH AUTOMATIC SESSION CHECK
  // ============================================================================
  Widget _buildSplashView() {
    return Center(
      key: const ValueKey('splash'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primaryColor, width: 2),
              ),
              child: const Icon(
                Icons.fitness_center,
                color: AppTheme.primaryColor,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'LIFTING LIFE',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Train. Progress. Compete. Inspire.',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _stage = _AuthStage.welcome),
              child: const Text(
                'Checking secure session...',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 2. WELCOME SCREEN (FACEBOOK, APPLE ID, EMAIL)
  // ============================================================================
  Widget _buildWelcomeView(BuildContext context, DataService data) {
    final showcaseEx = data.exercises.firstWhere(
      (e) => e.id == 'ex_tibialis_raise',
      orElse: () => data.exercises.first,
    );

    return Center(
      key: const ValueKey('welcome'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIFTING LIFE',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'Train. Progress. Compete. Inspire.',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Realistic 3D Muscular Anatomy Model Preview
              AnatomyExerciseViewer(
                exercise: showcaseEx,
                height: 225,
                compactMode: true,
              ),
              const SizedBox(height: 16),

              const Text(
                'Welcome to Lifting Life',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Discover 210+ realistic 3D anatomy exercises with neon-green muscle activation, track Bodybuilding & Powerlifting PRs, compete on friend leaderboards, and learn from verified coaches.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),


              // 3. Continue with Email (Navigates to Email Registration)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.backgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => setState(() {
                  _regError = null;
                  _stage = _AuthStage.register;
                }),
                icon: const Icon(Icons.email_outlined, size: 20),
                label: const Text(
                  'Continue with Email',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Sign Up / Log In row
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _regError = null;
                      _stage = _AuthStage.register;
                    }),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Text(
                    '•',
                    style: TextStyle(color: AppTheme.textTertiary),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Already have an account?',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _loginError = null;
                      _stage = _AuthStage.login;
                    }),
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Terms & Privacy Policy Notice
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showTermsAndPrivacyModal(context),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 3. EMAIL REGISTRATION SCREEN
  // ============================================================================
  Widget _buildRegisterView(BuildContext context, DataService data) {
    final pwdStrength = _calculatePasswordStrength(_regPasswordCtrl.text);

    return Center(
      key: const ValueKey('register'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () =>
                            setState(() => _stage = _AuthStage.welcome),
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                      ),
                      TextButton(
                        onPressed: () => setState(() => _stage = _AuthStage.login),
                        child: const Text('Log In'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Create Your Account',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Join Lifting Life to train, track, and compete',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 12),
                  if (_regError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.errorColor),
                      ),
                      child: Text(
                        _regError!,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _regUsernameCtrl,
                    enabled: !_isRegistering,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (_regUsernameError != null) {
                        setState(() => _regUsernameError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Unique Username',
                      hintText: 'e.g. alex_lifts (3–30 chars)',
                      prefixIcon: const Icon(Icons.alternate_email),
                      errorText: _regUsernameError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _regEmailCtrl,
                    enabled: !_isRegistering,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) {
                      if (_regEmailError != null) {
                        setState(() => _regEmailError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'athlete@example.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      errorText: _regEmailError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _regPasswordCtrl,
                    autocorrect: false,
                    enableSuggestions: false,
                    enabled: !_isRegistering,
                    obscureText: _regObscure,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) {
                      setState(() {
                        _regPasswordError = null;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: _regPasswordError,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _regObscure = !_regObscure),
                        icon: Icon(
                          _regObscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: pwdStrength,
                    backgroundColor: AppTheme.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _passwordStrengthColor(pwdStrength),
                    ),
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _passwordStrengthLabel(pwdStrength),
                    style: TextStyle(
                      color: _passwordStrengthColor(pwdStrength),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _regConfirmCtrl,
                    enabled: !_isRegistering,
                    obscureText: _confirmObscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (_) {
                      if (_regConfirmError != null) {
                        setState(() => _regConfirmError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      suffixIcon: IconButton(
                        tooltip: _confirmObscure ? 'Show confirm password' : 'Hide confirm password',
                        onPressed: () => setState(() => _confirmObscure = !_confirmObscure),
                        icon: Icon(_confirmObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                      prefixIcon: const Icon(Icons.lock_reset),
                      errorText: _regConfirmError,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppTheme.primaryColor,
                    value: _acceptedTerms,
                    onChanged: _isRegistering
                        ? null
                        : (v) => setState(() {
                              _acceptedTerms = v ?? false;
                              _regTermsError = null;
                            }),
                    title: const Text(
                      'I accept the Terms of Service and Privacy Policy',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (_regTermsError != null) ...[
                    Text(
                      _regTermsError!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 4),
                  ElevatedButton(
                    onPressed: _isRegistering
                        ? null
                        : () => _handleCreateAccount(context, data),
                    child: _isRegistering
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('CREATING ACCOUNT...'),
                            ],
                          )
                        : const Text('CREATE ACCOUNT'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _stage = _AuthStage.login),
                    child: const Text('Already have an account? Log In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreateAccount(
    BuildContext context,
    DataService data,
  ) async {
    // Guard against double taps while a request is in flight.
    if (_isRegistering) return;

    final username = _regUsernameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final pwd = _regPasswordCtrl.text;
    final confirm = _regConfirmCtrl.text;

    String? usernameError;
    String? emailError;
    String? passwordError;
    String? confirmError;
    String? termsError;

    if (username.length < 3 || username.length > 30) {
      usernameError = 'Username must be between 3 and 30 characters.';
    } else if (data.isUsernameTaken(username)) {
      usernameError = 'That username is already taken. Please choose another.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      emailError = 'Please enter a valid email address.';
    }
    if (pwd.length < 8 || _calculatePasswordStrength(pwd) < 0.45) {
      passwordError = 'Please choose a stronger password.';
    }
    if (pwd != confirm) {
      confirmError = 'Passwords do not match.';
    }
    if (!_acceptedTerms) {
      termsError = 'Please accept the Terms of Service and Privacy Policy.';
    }

    setState(() {
      _regUsernameError = usernameError;
      _regEmailError = emailError;
      _regPasswordError = passwordError;
      _regConfirmError = confirmError;
      _regTermsError = termsError;
      _regError = null;
    });

    if (usernameError != null ||
        emailError != null ||
        passwordError != null ||
        confirmError != null ||
        termsError != null) {
      return;
    }

    setState(() => _isRegistering = true);

    try {
      // Real Supabase Auth signup: creates the account, stores the username in
      // user metadata and triggers the confirmation email containing
      // `{{ .Token }}`. No code is generated or stored on the device.
      final outcome = await data.registerWithEmail(
        username: username,
        email: email,
        password: pwd,
      );

      if (!mounted) return;

      if (!outcome.isSuccess) {
        setState(() {
          _regError = _registrationErrorMessage(outcome.status);
        });
        return;
      }

      _clearOtpBoxes();
      _startResendCooldown();
      setState(() {
        _regError = null;
        _otpError = null;
        _otpSuccess = null;
        _stage = _AuthStage.verifyOtp;
      });
    } catch (error) {
      // Never surface backend details (and never log credentials).
      AuthDiagnostics.record(operation: 'sign_up', category: 'unexpected_failure');
      if (!mounted) return;
      setState(() {
        _regError = 'Unable to connect. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  String _registrationErrorMessage(EmailAuthStatus status) {
    switch (status) {
      case EmailAuthStatus.invalidEmail:
        return 'Please enter a valid email address.';
      case EmailAuthStatus.weakPassword:
        return 'Please choose a stronger password.';
      case EmailAuthStatus.networkError:
        return 'Unable to connect. Please try again.';
      case EmailAuthStatus.rateLimited:
      case EmailAuthStatus.tooManyAttempts:
        return 'Too many attempts. Please try again later.';
      case EmailAuthStatus.deliveryFailed:
        return 'Verification email could not be sent.';
      case EmailAuthStatus.emailAlreadyRegistered:
        return 'An account with this email address already exists. Please log in.';
      case EmailAuthStatus.notConfigured:
        return 'Registration is temporarily unavailable. Please try again later.';
      case EmailAuthStatus.serverMisconfigured:
        return 'Email verification is not enabled. Please try again later.';
      default:
        return 'We could not create your account. Please try again.';
    }
  }

  String _verificationErrorMessage(EmailAuthStatus status) {
    switch (status) {
      case EmailAuthStatus.invalidCode:
        return 'Invalid verification code. Please try again.';
      case EmailAuthStatus.expiredCode:
        return 'Your code has expired. Request a new one.';
      case EmailAuthStatus.deliveryFailed:
        return "We couldn't send your verification email. Please try again.";
      case EmailAuthStatus.networkError:
        return 'Connection error. Check your internet and try again.';
      case EmailAuthStatus.rateLimited:
      case EmailAuthStatus.tooManyAttempts:
        return 'Too many attempts. Please try again later.';
      case EmailAuthStatus.notConfigured:
        return 'Email verification is temporarily unavailable. Please try again later.';
      default:
        return 'Verification failed. Please try again.';
    }
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();
    _resendSecondsRemaining = 60;
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsRemaining <= 1) {
        setState(() {
          _resendSecondsRemaining = 0;
        });
        timer.cancel();
      } else {
        setState(() {
          _resendSecondsRemaining--;
        });
      }
    });
  }

  void _clearOtpBoxes() {
    for (final ctrl in _otpControllers) {
      ctrl.clear();
    }
  }

  void _fillOtpBoxesWithCode(String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return;
    for (int i = 0; i < 6; i++) {
      _otpControllers[i].text =
          i < digitsOnly.length ? digitsOnly[i] : '';
    }
    setState(() {
      _otpError = null;
    });
    if (digitsOnly.length >= 6) {
      _otpFocusNodes[5].requestFocus();
    }
  }

  String _collectEnteredOtp() {
    return _otpControllers.map((c) => c.text.trim()).join();
  }

  Future<void> _handleVerifyOtp(
    BuildContext context,
    DataService data,
  ) async {
    if (_isVerifyingOtp) return;

    final entered = _collectEnteredOtp();
    if (entered.length < 6) {
      setState(() {
        _otpError = 'Enter all 6 digits of the verification code.';
        _otpSuccess = null;
      });
      return;
    }

    final email = data.pendingEmail ?? _regEmailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() {
        _otpError = 'Enter your email address again to verify it.';
        _otpSuccess = null;
      });
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _otpError = null;
      _otpSuccess = null;
    });

    try {
      // Supabase Auth verifies the code, its expiry and its attempt limits.
      final outcome = await data.verifySignupCode(
        email: email,
        token: entered,
      );

      if (!mounted) return;

      if (!outcome.isSuccess) {
        setState(() {
          _otpError = _verificationErrorMessage(outcome.status);
        });
        return;
      }

      setState(() {
        _otpSuccess = 'Email Verified Successfully!';
      });
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.successColor,
          content: Text(
            'Email Verified Successfully!',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
      // `verifySignupCode` marks the session authenticated; the screen routes
      // itself to FirstTimeFitnessOnboardingScreen.
    } catch (error) {
      AuthDiagnostics.record(operation: 'verify_signup', category: 'unexpected_failure');
      if (!mounted) return;
      setState(() {
        _otpError = 'Unable to connect. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isVerifyingOtp = false);
      }
    }
  }

  Future<void> _handleResendOtp(
    BuildContext context,
    DataService data,
  ) async {
    if (_isResendingOtp || _resendSecondsRemaining > 0) return;

    final email = data.pendingEmail ?? _regEmailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() {
        _otpError = 'Enter your email address again to receive a new code.';
      });
      return;
    }

    setState(() {
      _isResendingOtp = true;
      _otpError = null;
      _otpSuccess = null;
    });

    try {
      final outcome = await data.resendSignupCode(email: email);
      if (!mounted) return;

      if (!outcome.isSuccess) {
        setState(() {
          _otpError = _verificationErrorMessage(outcome.status);
        });
        return;
      }

      _clearOtpBoxes();
      _startResendCooldown();
      final masked = DataService.maskEmail(email);
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text('A new 6-digit code was sent to $masked.'),
        ),
      );
    } catch (error) {
      AuthDiagnostics.record(operation: 'resend_signup', category: 'unexpected_failure');
      if (!mounted) return;
      setState(() {
        _otpError = 'Unable to connect. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isResendingOtp = false);
      }
    }
  }

  // ============================================================================
  // 3B. DEDICATED 6-DIGIT EMAIL OTP VERIFICATION SCREEN
  // ============================================================================
  Widget _buildVerifyOtpView(BuildContext context, DataService data) {
    final targetEmail = data.pendingEmail ?? _regEmailCtrl.text.trim();
    final maskedEmail = DataService.maskEmail(targetEmail);

    return Center(
      key: const ValueKey('verify_otp'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Centered Lifting Life Logo Badge
                  Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: AppTheme.primaryColor,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Animated Glowing Email Icon
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.12 + 0.08 * value,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.25 * value,
                                ),
                                blurRadius: 18 * value,
                                spreadRadius: 3 * value,
                              ),
                            ],
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.5 + 0.5 * value,
                              ),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_rounded,
                            color: AppTheme.primaryColor,
                            size: 36,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Heading
                  const Center(
                    child: Text(
                      'Verify Your Email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  const Center(
                    child: Text(
                      "We've sent a 6-digit verification code to your email address.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Masked Email Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Text(
                        maskedEmail.isNotEmpty ? maskedEmail : targetEmail,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Enter the code sent to $targetEmail. This code expires in 10 minutes.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_otpError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.errorColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.errorColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _otpError!,
                              style: const TextStyle(
                                color: AppTheme.errorColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_otpSuccess != null) ...[
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.successColor,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.successColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.black,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Email Verified Successfully!',
                                        style: TextStyle(
                                          color: AppTheme.successColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Welcome to Lifting Life',
                                        style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 6 Individual OTP Digit Boxes with auto-advance, backspace navigation & paste support
                  Row(
                    children: List.generate(6, (index) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Semantics(
                            label: 'Digit ${index + 1} of 6',
                            child: TextField(
                              key: ValueKey('otp_box_$index'),
                              controller: _otpControllers[index],
                              focusNode: _otpFocusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                filled: true,
                                fillColor: AppTheme.backgroundColor,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color:
                                        _otpControllers[index].text.isNotEmpty
                                            ? AppTheme.primaryColor
                                            : AppTheme.borderColor,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppTheme.primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                final digits = value.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                );
                                if (digits.length > 1) {
                                  // User pasted full 6-digit code into a box
                                  _fillOtpBoxesWithCode(digits);
                                  return;
                                }
                                if (digits.isNotEmpty) {
                                  _otpControllers[index].text = digits;
                                  _otpControllers[index].selection =
                                      TextSelection.fromPosition(
                                        const TextPosition(offset: 1),
                                      );
                                  if (index < 5) {
                                    _otpFocusNodes[index + 1].requestFocus();
                                  }
                                } else {
                                  _otpControllers[index].text = '';
                                  if (index > 0) {
                                    _otpFocusNodes[index - 1].requestFocus();
                                  }
                                }
                                setState(() {
                                  _otpError = null;
                                });
                              },
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),

                  // Paste Code button
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        final clip = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        if (clip?.text != null &&
                            clip!.text!.trim().isNotEmpty) {
                          _fillOtpBoxesWithCode(clip.text!);
                        }
                      },
                      icon: const Icon(Icons.content_paste, size: 16),
                      label: const Text(
                        'Paste 6-Digit Code',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Verify Email Primary CTA
                  ElevatedButton.icon(
                    onPressed: _isVerifyingOtp
                        ? null
                        : () => _handleVerifyOtp(context, data),
                    icon: _isVerifyingOtp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.verified_outlined, size: 20),
                    label: Text(
                      _isVerifyingOtp ? 'VERIFYING...' : 'Verify Email',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Resend Wrap with "Didn't receive a code?" and 60s countdown
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "Didn't receive a code?",
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed:
                            (_resendSecondsRemaining > 0 || _isResendingOtp)
                                ? null
                                : () => _handleResendOtp(context, data),
                        child: Text(
                          _isResendingOtp
                              ? 'Sending...'
                              : _resendSecondsRemaining > 0
                                  ? 'Resend Code (${_resendSecondsRemaining}s)'
                                  : 'Resend Code',
                          style: TextStyle(
                            color:
                                (_resendSecondsRemaining > 0 || _isResendingOtp)
                                    ? AppTheme.textTertiary
                                    : AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Change Email Address button
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        data.clearPendingEmailRegistration();
                        setState(() {
                          _stage = _AuthStage.register;
                          _otpError = null;
                          _otpSuccess = null;
                        });
                      },
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text(
                        'Change Email Address',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 4. LOGIN SCREEN (EMAIL, REMEMBER SESSION, FORGOT PASSWORD, FACEBOOK, APPLE)
  // ============================================================================
  Widget _buildLoginView(BuildContext context, DataService data) {
    return Center(
      key: const ValueKey('login'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () =>
                            setState(() => _stage = _AuthStage.welcome),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Expanded(
                        child: Text(
                          'Log In to Lifting Life',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loginError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.errorColor),
                      ),
                      child: Text(
                        _loginError!,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _loginEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _loginPasswordCtrl,
                    obscureText: _loginObscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _loginObscure = !_loginObscure),
                        icon: Icon(
                          _loginObscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Checkbox(
                              value: _rememberSession,
                              activeColor: AppTheme.primaryColor,
                              onChanged: (v) => setState(
                                () => _rememberSession = v ?? true,
                              ),
                            ),
                            const Flexible(
                              child: Text(
                                'Remember session',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showForgotPasswordModal(context),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _isSigningIn
                        ? null
                        : () async {
                            final email = _loginEmailCtrl.text.trim();
                            final pwd = _loginPasswordCtrl.text;
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(email)) {
                              setState(() {
                                _loginError =
                                    'Please enter a valid email address.';
                              });
                              return;
                            }
                            if (pwd.isEmpty) {
                              setState(() {
                                _loginError = 'Please enter your password.';
                              });
                              return;
                            }

                            setState(() {
                              _isSigningIn = true;
                              _loginError = null;
                            });

                            try {
                              final result = data.isEmailAuthConfigured
                                  ? await data.signInWithEmail(
                                      email: email,
                                      password: pwd,
                                      rememberSession: _rememberSession,
                                    )
                                  : data.signIn(
                                      email: email,
                                      password: pwd,
                                      rememberSession: _rememberSession,
                                    );

                              if (!mounted) return;
                              if (result.isSuccess) return;

                              if (result.requiresEmailVerification) {
                                _clearOtpBoxes();
                                _startResendCooldown();
                                setState(() {
                                  _otpError = result.message;
                                  _otpSuccess = null;
                                  _stage = _AuthStage.verifyOtp;
                                });
                              } else {
                                setState(() {
                                  _loginError = result.message;
                                });
                              }
                            } catch (error) {
                              AuthDiagnostics.record(operation: 'sign_in', category: 'unexpected_failure');
                              if (!mounted) return;
                              setState(() {
                                _loginError =
                                    'Unable to connect. Please try again.';
                              });
                            } finally {
                              if (mounted) {
                                setState(() => _isSigningIn = false);
                              }
                            }
                          },
                    child: _isSigningIn
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.black,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('SIGNING IN...'),
                            ],
                          )
                        : const Text('LOG IN'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () =>
                        setState(() => _stage = _AuthStage.register),
                    child: const Text("Don't have an account? Sign Up"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _showForgotPasswordModal(BuildContext context) {
    final resetEmailCtrl = TextEditingController(text: _loginEmailCtrl.text);
    final codeCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    bool codeSent = false;
    bool busy = false;
    String? dialogFeedback;
    bool feedbackIsError = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text('Account Recovery & Password Reset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                codeSent
                    ? 'Enter the 6-digit recovery code sent to your email and your new password.'
                    : 'Enter your registered email address to receive a 6-digit password recovery code.',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              if (dialogFeedback != null) ...[
                Text(
                  dialogFeedback!,
                  style: TextStyle(
                    color: feedbackIsError
                        ? AppTheme.errorColor
                        : AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: resetEmailCtrl,
                enabled: !codeSent && !busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              if (codeSent) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: codeCtrl,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '6-Digit Recovery Code',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPwdCtrl,
                  enabled: !busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password (8+ chars)',
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final email = resetEmailCtrl.text.trim();
                      if (!codeSent) {
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          setDialogState(() {
                            dialogFeedback = 'Please enter a valid email address.';
                            feedbackIsError = true;
                          });
                          return;
                        }
                        setDialogState(() {
                          busy = true;
                          dialogFeedback = null;
                        });
                        final outcome = await DataService.instance
                            .sendPasswordResetCode(email: email);
                        if (!ctx.mounted) return;
                        setDialogState(() {
                          busy = false;
                          feedbackIsError = !outcome.isSuccess;
                          if (outcome.isSuccess) {
                            codeSent = true;
                            dialogFeedback =
                                'Recovery code sent to ${DataService.maskEmail(email)}.';
                          } else {
                            dialogFeedback =
                                _verificationErrorMessage(outcome.status);
                          }
                        });
                      } else {
                        final code = codeCtrl.text.trim();
                        final newPassword = newPwdCtrl.text;
                        if (code.length != 6) {
                          setDialogState(() {
                            dialogFeedback =
                                'Enter the 6-digit recovery code.';
                            feedbackIsError = true;
                          });
                          return;
                        }
                        if (newPassword.length < 8) {
                          setDialogState(() {
                            dialogFeedback =
                                'Please choose a stronger password.';
                            feedbackIsError = true;
                          });
                          return;
                        }
                        setDialogState(() {
                          busy = true;
                          dialogFeedback = null;
                        });
                        final outcome = await DataService.instance
                            .resetPasswordWithCode(
                          email: email,
                          token: code,
                          newPassword: newPassword,
                        );
                        if (!ctx.mounted) return;
                        if (!outcome.isSuccess) {
                          setDialogState(() {
                            busy = false;
                            feedbackIsError = true;
                            dialogFeedback =
                                _verificationErrorMessage(outcome.status);
                          });
                          return;
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password updated. Log in with your new password.',
                            ),
                          ),
                        );
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(codeSent ? 'Reset Password' : 'Send Recovery Code'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsAndPrivacyModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Terms of Service & Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Account Security: Lifting Life uses managed OAuth (Facebook, Apple ID) and encrypted email authentication. Raw passwords and OAuth secrets are never stored in application tables.\n\n'
            '2. Ethical Leaderboards: Rankings reward training consistency (capped at 5 weekly sessions) and educational milestones—never body weight or extreme volume.\n\n'
            '3. Mandatory Course Review: All community-submitted fitness courses remain private in Pending Review until approved by the App Owner.\n\n'
            '4. Data Rights: You may export your full workout & PR history as JSON or permanently delete your account at any time from Profile & Settings.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION 3: FIRST-TIME FITNESS ONBOARDING WIZARD
// ============================================================================
class FirstTimeFitnessOnboardingScreen extends StatefulWidget {
  const FirstTimeFitnessOnboardingScreen({super.key});

  @override
  State<FirstTimeFitnessOnboardingScreen> createState() =>
      _FirstTimeFitnessOnboardingScreenState();
}

class _FirstTimeFitnessOnboardingScreenState
    extends State<FirstTimeFitnessOnboardingScreen> {
  String _trainingInterest = 'Hybrid Training';
  String _experienceLevel = 'Intermediate';
  String _workoutFrequency = '4 days per week';
  final Set<String> _mainFocusGoals = {
    'Build muscle',
    'Improve strength',
    'Learn gym techniques',
  };
  String _weightUnit = 'metric'; // 'metric' (kg) or 'imperial' (lb)
  late TextEditingController _usernameCtrl;
  final TextEditingController _tiktokCtrl = TextEditingController();

  static const List<String> _interests = [
    'Bodybuilding',
    'Powerlifting',
    'Hybrid Training',
    'General Fitness',
  ];

  static const List<String> _levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  static const List<String> _frequencies = [
    '2 days per week',
    '3 days per week',
    '4 days per week',
    '5 days per week',
    'Custom schedule',
  ];

  static const List<String> _focusOptions = [
    'Learn gym techniques',
    'Improve strength',
    'Build muscle',
    'Improve general fitness',
    'Track training progress',
  ];

  @override
  void initState() {
    super.initState();
    final user = DataService.instance.currentUser;
    _usernameCtrl = TextEditingController(
      text: user?.username ?? 'alex_titan',
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _tiktokCtrl.dispose();
    super.dispose();
  }

  void _finishOnboarding() {
    DataService.instance.completeOnboarding(
      experienceLevel: _experienceLevel,
      trainingInterest: _trainingInterest,
      workoutFrequency: _workoutFrequency,
      preferredDays: const ['Mon', 'Tue', 'Thu', 'Fri'],
      goals: _mainFocusGoals.toList(),
      units: _weightUnit,
      username: _usernameCtrl.text.trim(),
      tiktokUsername: _tiktokCtrl.text.trim().isEmpty
          ? null
          : _tiktokCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalize Lifting Life'),
        actions: [
          TextButton(
            onPressed: _finishOnboarding,
            child: const Text(
              'Skip Optional',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.successColor,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.successColor.withValues(alpha: 0.15),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.successColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.successColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Email Verified Successfully!',
                                    style: TextStyle(
                                      color: AppTheme.successColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Welcome to Lifting Life',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Your email is verified (${DataService.instance.currentUser?.email ?? ''}). Complete your 1-minute fitness onboarding below.',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary.withValues(alpha: 0.9),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Text(
                  'Tailor Your 3D Training & Programs',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'We use these answers to recommend your ideal Bodybuilding or Powerlifting split, 3D tutorials, and weekly targets.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 18),

                // 1. Training Interest
                _OnboardingSectionCard(
                  title: '1. Select Your Primary Training Interest',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interests.map((interest) {
                      final selected = _trainingInterest == interest;
                      return ChoiceChip(
                        label: Text(interest),
                        selected: selected,
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppTheme.backgroundColor
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) =>
                            setState(() => _trainingInterest = interest),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Experience Level
                _OnboardingSectionCard(
                  title: '2. Your Gym Experience Level',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _levels.map((lvl) {
                      final selected = _experienceLevel == lvl;
                      return ChoiceChip(
                        label: Text(lvl),
                        selected: selected,
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppTheme.backgroundColor
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) =>
                            setState(() => _experienceLevel = lvl),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Workout Frequency
                _OnboardingSectionCard(
                  title: '3. Weekly Workout Frequency',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _frequencies.map((freq) {
                      final selected = _workoutFrequency == freq;
                      return ChoiceChip(
                        label: Text(freq),
                        selected: selected,
                        selectedColor: AppTheme.secondaryAccent,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppTheme.backgroundColor
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) =>
                            setState(() => _workoutFrequency = freq),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Main Training Focus
                _OnboardingSectionCard(
                  title: '4. Main Training Focus (Select all that apply)',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _focusOptions.map((focus) {
                      final selected = _mainFocusGoals.contains(focus);
                      return FilterChip(
                        label: Text(focus),
                        selected: selected,
                        selectedColor:
                            AppTheme.primaryColor.withValues(alpha: 0.25),
                        checkmarkColor: AppTheme.primaryColor,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _mainFocusGoals.add(focus);
                            } else if (_mainFocusGoals.length > 1) {
                              _mainFocusGoals.remove(focus);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // 5. Personalization (Units & Username)
                _OnboardingSectionCard(
                  title: '5. Personalization & Weight Units',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Kilograms (kg)'),
                              selected: _weightUnit == 'metric',
                              selectedColor: AppTheme.primaryColor,
                              labelStyle: TextStyle(
                                color: _weightUnit == 'metric'
                                    ? AppTheme.backgroundColor
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              onSelected: (_) =>
                                  setState(() => _weightUnit = 'metric'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Pounds (lb)'),
                              selected: _weightUnit == 'imperial',
                              selectedColor: AppTheme.primaryColor,
                              labelStyle: TextStyle(
                                color: _weightUnit == 'imperial'
                                    ? AppTheme.backgroundColor
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              onSelected: (_) =>
                                  setState(() => _weightUnit = 'imperial'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _usernameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Unique Athlete Username',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _tiktokCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Optional TikTok Username (@handle)',
                          prefixIcon: Icon(Icons.videocam_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: _finishOnboarding,
                  icon: const Icon(Icons.rocket_launch),
                  label: const Text('COMPLETE SETUP & ENTER DASHBOARD'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _OnboardingSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
