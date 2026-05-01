import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFoci = List.generate(6, (_) => FocusNode());
  bool _otpError = false;

  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _passFormKey = GlobalKey<FormState>();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  double _passStrength = 0;

  bool _success = false;

  int _resendSeconds = 0;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    _passCtrl.addListener(_updateStrength);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFoci) {
      f.dispose();
    }
    _passCtrl.removeListener(_updateStrength);
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  int _deriveStep(AuthStatus status) {
    switch (status) {
      case AuthStatus.pendingReset:
        return 2;
      case AuthStatus.resetVerified:
        return 3;
      default:
        return 1;
    }
  }

  void _updateStrength() {
    final p = _passCtrl.text;
    double s = 0;
    if (p.length >= 8) s += 0.25;
    if (p.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (p.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) s += 0.25;
    setState(() => _passStrength = s);
  }

  Color get _strengthColor {
    if (_passStrength <= 0.25) return const Color(0xFFEF4444);
    if (_passStrength <= 0.5) return const Color(0xFFF97316);
    if (_passStrength <= 0.75) return const Color(0xFF3B82F6);
    return const Color(0xFF22C55E);
  }

  String get _strengthLabel {
    if (_passStrength <= 0.25) return 'Weak';
    if (_passStrength <= 0.5) return 'Fair';
    if (_passStrength <= 0.75) return 'Good';
    return 'Strong';
  }

  String get _otp => _otpCtrls.map((c) => c.text).join();

  void _clearOtp() {
    for (final c in _otpCtrls) c.clear();
    setState(() => _otpError = false);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _otpFoci[0].requestFocus();
    });
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authProvider.notifier)
        .forgotPassword(_emailCtrl.text.trim());
    if (ok && mounted) {
      _startResendTimer();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _otpFoci[0].requestFocus();
      });
    }
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;
    _clearOtp();
    final ok = await ref
        .read(authProvider.notifier)
        .forgotPassword(_emailCtrl.text.trim());
    if (ok && mounted) {
      _startResendTimer();
    }
  }

  void _startResendTimer() {
    setState(() => _resendSeconds = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _resendSeconds <= 0) return false;
      setState(() => _resendSeconds--);
      return _resendSeconds > 0;
    });
  }

  Future<void> _verifyOtp() async {
    final code = _otp;
    if (code.length != 6) return;

    final ok = await ref.read(authProvider.notifier).verifyResetOtp(code);
    if (!mounted) return;

    if (!ok) {
      setState(() => _otpError = true);
      _shakeCtrl.forward(from: 0);
      _clearOtp();
    }
  }

  void _autoVerify() {
    final code = _otp;
    if (code.length == 6 && _otpCtrls.every((c) => c.text.isNotEmpty)) {
      _verifyOtp();
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length == 6) {
      for (int i = 0; i < 6; i++) {
        _otpCtrls[i].text = i < value.length ? value[i] : '';
      }
      _otpFoci[5].requestFocus();
      setState(() => _otpError = false);
      _autoVerify();
      return;
    }
    if (value.length > 1) {
      _otpCtrls[index].text = value[value.length - 1];
      _otpCtrls[index].selection = const TextSelection.collapsed(offset: 1);
    }
    if (value.isNotEmpty && index < 5) {
      _otpFoci[index + 1].requestFocus();
    } else if (value.isNotEmpty && index == 5) {
      _otpFoci[index].unfocus();
    }
    if (value.isNotEmpty) setState(() => _otpError = false);
    _autoVerify();
  }

  Future<void> _resetPassword() async {
    if (!_passFormKey.currentState!.validate()) return;
    final ok =
        await ref.read(authProvider.notifier).resetPassword(_passCtrl.text);
    if (ok && mounted) {
      setState(() => _success = true);
      await Future.delayed(const Duration(milliseconds: 2200));
      if (mounted) context.go(AppRoutes.login);
    }
  }

  void _goBack(AuthStatus status, int step) {
    if (step > 1) {
      ref.read(authProvider.notifier).cancelReset();
      _clearOtp();
      _passCtrl.clear();
      _confirmCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final status = auth.status;
    final isLoading = status == AuthStatus.loading;
    final error = auth.errorMessage;
    final step = _deriveStep(status);

    if (_success) return const _SuccessView();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack(status, step);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    _goBack(status, step);
                    context.go(AppRoutes.login);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 28),
                _StepIndicator(current: step),
                const SizedBox(height: 32),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: step == 1
                      ? _EmailForm(
                          key: const ValueKey('email'),
                          controller: _emailCtrl,
                          formKey: _formKey,
                          isLoading: isLoading,
                          error: error,
                          onSend: _sendOtp,
                        )
                      : step == 2
                          ? _OtpForm(
                              key: const ValueKey('otp'),
                              email: auth.pendingEmail ?? '',
                              controllers: _otpCtrls,
                              focusNodes: _otpFoci,
                              isLoading: isLoading,
                              hasError: _otpError,
                              shakeAnim: _shakeAnim,
                              shakeCtrl: _shakeCtrl,
                              resendSeconds: _resendSeconds,
                              onOtpChanged: _onOtpChanged,
                              onVerify: _verifyOtp,
                              onResend: _resendOtp,
                            )
                          : _PasswordForm(
                              key: const ValueKey('password'),
                              passCtrl: _passCtrl,
                              confirmCtrl: _confirmCtrl,
                              formKey: _passFormKey,
                              isLoading: isLoading,
                              error: error,
                              obscurePass: _obscurePass,
                              obscureConfirm: _obscureConfirm,
                              passStrength: _passStrength,
                              strengthColor: _strengthColor,
                              strengthLabel: _strengthLabel,
                              onTogglePass: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                              onToggleConfirm: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                              onReset: _resetPassword,
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Step Indicator ───────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final step = i + 1;
        final isDone = step < current;
        final isActive = step == current;
        return Expanded(
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone || isActive
                      ? AppColors.primary
                      : const Color(0xFFE2E8F0),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : Text(
                          '$step',
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : const Color(0xFFA0AEC0),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
              if (step < 3)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 2,
                    color: step < current
                        ? AppColors.primary
                        : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  const _PrimaryBtn(
      {required this.label, required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

// ─── Step 1: Email ────────────────────────────────────────

class _EmailForm extends StatelessWidget {
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final String? error;
  final VoidCallback onSend;

  const _EmailForm({
    super.key,
    required this.controller,
    required this.formKey,
    required this.isLoading,
    required this.error,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(
            title: 'Forgot password?',
            subtitle:
                "Enter your account email and we'll send you a 6-digit reset code.",
          ),
          const SizedBox(height: 36),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSend(),
            decoration: _buildInputDecor(
                'Email address', Icons.alternate_email_rounded),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!RegExp(r'^[\w.+-]+@[\w-]+\.\w+$').hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(error!),
          ],
          const SizedBox(height: 28),
          _PrimaryBtn(
              label: 'Send reset code',
              isLoading: isLoading,
              onPressed: onSend),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms);
  }

  InputDecoration _buildInputDecor(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

// ─── Step 2: OTP ──────────────────────────────────────────

class _OtpForm extends StatelessWidget {
  final String email;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool isLoading;
  final bool hasError;
  final Animation<double> shakeAnim;
  final AnimationController shakeCtrl;
  final int resendSeconds;
  final void Function(int, String) onOtpChanged;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  const _OtpForm({
    super.key,
    required this.email,
    required this.controllers,
    required this.focusNodes,
    required this.isLoading,
    required this.hasError,
    required this.shakeAnim,
    required this.shakeCtrl,
    required this.resendSeconds,
    required this.onOtpChanged,
    required this.onVerify,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          title: 'Check your email',
          subtitle:
              'A 6-digit code was sent to ${_maskEmail(email)}. It expires in 15 minutes.',
        ),
        const SizedBox(height: 36),
        AnimatedBuilder(
          animation: shakeAnim,
          builder: (context, child) {
            final offset =
                shakeCtrl.isAnimating ? ((shakeAnim.value * 2 - 1) * 10) : 0.0;
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
                6,
                (i) => _OtpBox(
                      controller: controllers[i],
                      focusNode: focusNodes[i],
                      index: i,
                      hasError: hasError,
                      isFilled: controllers[i].text.isNotEmpty,
                      onChanged: (v) => onOtpChanged(i, v),
                      onBackspace: () {
                        if (controllers[i].text.isEmpty && i > 0) {
                          controllers[i - 1].clear();
                          focusNodes[i - 1].requestFocus();
                        }
                      },
                    )),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 14),
          const _ErrorBanner('Incorrect code. Please try again.'),
        ],
        const SizedBox(height: 28),
        _PrimaryBtn(
          label: isLoading ? 'Verifying…' : 'Verify code',
          isLoading: isLoading,
          onPressed: onVerify,
        ),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: resendSeconds > 0 ? null : onResend,
            child: RichText(
              text: TextSpan(
                text: "Didn't get it? ",
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textMuted),
                children: [
                  TextSpan(
                    text: resendSeconds > 0
                        ? 'Resend in ${resendSeconds}s'
                        : 'Resend code',
                    style: TextStyle(
                      color: resendSeconds > 0
                          ? AppColors.textMuted
                          : AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Check your spam or junk folder if you can't find it.",
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF92400E), height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 280.ms);
  }

  static String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return email;
    return '${name[0]}${'•' * (name.length - 2)}${name[name.length - 1]}@$domain';
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int index;
  final bool isFilled;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.index,
    required this.isFilled,
    required this.hasError,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 58,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            color: hasError ? const Color(0xFFB91C1C) : const Color.fromARGB(255, 7, 7, 215),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: hasError
                ? const Color(0xFFFEF2F2)
                : isFilled
                    ? Colors.amber
                    : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFFCA5A5)
                    : isFilled
                        ? Colors.amber
                        : const Color(0xFFE2E8F0),
                width: isFilled ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: hasError ? const Color(0xFFEF4444) : AppColors.primary,
                width: 2,
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    )
        .animate(delay: (index * 50).ms)
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.25, end: 0, curve: Curves.easeOutBack);
  }
}

// ─── Step 3: New Password ─────────────────────────────────

class _PasswordForm extends StatelessWidget {
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final String? error;
  final bool obscurePass;
  final bool obscureConfirm;
  final double passStrength;
  final Color strengthColor;
  final String strengthLabel;
  final VoidCallback onTogglePass;
  final VoidCallback onToggleConfirm;
  final VoidCallback onReset;

  const _PasswordForm({
    super.key,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.formKey,
    required this.isLoading,
    required this.error,
    required this.obscurePass,
    required this.obscureConfirm,
    required this.passStrength,
    required this.strengthColor,
    required this.strengthLabel,
    required this.onTogglePass,
    required this.onToggleConfirm,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(
            title: 'New password',
            subtitle:
                'Choose a strong password — mix letters, numbers, and symbols.',
          ),
          const SizedBox(height: 36),
          TextFormField(
            controller: passCtrl,
            obscureText: obscurePass,
            textInputAction: TextInputAction.next,
            decoration:
                _buildInputDecor('New password', Icons.lock_outline_rounded)
                    .copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                    obscurePass
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                    color: AppColors.textMuted),
                onPressed: onTogglePass,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a new password';
              if (v.length < 8) return 'Must be at least 8 characters';
              return null;
            },
          ),
          if (passCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: passStrength,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  strengthLabel,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: strengthColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: confirmCtrl,
            obscureText: obscureConfirm,
            textInputAction: TextInputAction.done,
            decoration:
                _buildInputDecor('Confirm password', Icons.lock_outline_rounded)
                    .copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                    obscureConfirm
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                    color: AppColors.textMuted),
                onPressed: onToggleConfirm,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              if (v != passCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(error!),
          ],
          const SizedBox(height: 28),
          _PrimaryBtn(
              label: 'Update password',
              isLoading: isLoading,
              onPressed: onReset),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: AppColors.primary, size: 14),
                    const SizedBox(width: 6),
                    const Text('Tips for a strong password',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                ...[
                  'At least 8 characters long',
                  'Mix uppercase and lowercase letters',
                  'Include at least one number',
                  'Add a symbol like ! @ # \$ %',
                ].map((tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.primary)),
                            Expanded(
                              child: Text(tip,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                      height: 1.4)),
                            ),
                          ]),
                    )),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms);
  }

  InputDecoration _buildInputDecor(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

// ─── Success Screen ───────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF006B64), Color(0xFF009E95), Color(0xFF004E49)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 50),
                )
                    .animate()
                    .scale(
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                        begin: const Offset(0.3, 0.3))
                    .fadeIn(),
                const SizedBox(height: 32),
                const Text(
                  'Password updated!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                const SizedBox(height: 12),
                Text(
                  'You can now log in with\nyour new password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 450.ms),
                const SizedBox(height: 40),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(50),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Taking you to login…',
                        style: TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 600.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
