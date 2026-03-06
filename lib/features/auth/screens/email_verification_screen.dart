import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen>
    with TickerProviderStateMixin {
  static const _codeLength = 6;
  static const _cooldownSeconds = 60;

  final _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final _focusNodes = List.generate(_codeLength, (_) => FocusNode());

  int _secondsLeft = _cooldownSeconds; // start with cooldown after sign-up
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMsg;
  bool _codeComplete = false;

  Timer? _cooldownTimer;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Start cooldown immediately (email was just sent on register)
    _startCooldown();

    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsLeft = _cooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) t.cancel();
      });
    });
  }

  String get _currentCode =>
      _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    // Handle paste of full code
    if (value.length == _codeLength) {
      for (int i = 0; i < _codeLength; i++) {
        _controllers[i].text = value[i];
      }
      _focusNodes[_codeLength - 1].requestFocus();
      _checkComplete();
      return;
    }

    if (value.isNotEmpty) {
      // Only keep last character
      if (value.length > 1) {
        _controllers[index].text = value[value.length - 1];
        _controllers[index].selection = TextSelection.fromPosition(
          TextPosition(offset: 1),
        );
      }
      // Move to next box
      if (index < _codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
    _checkComplete();
  }

  void _checkComplete() {
    final complete = _currentCode.length == _codeLength &&
        _controllers.every((c) => c.text.isNotEmpty);
    if (complete != _codeComplete) {
      setState(() => _codeComplete = complete);
    }
    if (complete) _verify();
  }

  Future<void> _verify() async {
    final code = _currentCode;
    if (code.length != _codeLength) return;

    setState(() {
      _isVerifying = true;
      _errorMsg = null;
    });

    final ok = await ref.read(authProvider.notifier).verifyOtp(code);

    if (!mounted) return;

    if (ok) {
      context.go(AppRoutes.home);
    } else {
      final authState = ref.read(authProvider);
      setState(() {
        _isVerifying = false;
        _errorMsg = authState.errorMessage ?? 'Invalid code. Please try again.';
        _codeComplete = false;
      });
      // Clear all boxes and refocus
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      _shakeController.forward(from: 0);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _isResending) return;
    setState(() {
      _isResending = true;
      _errorMsg = null;
    });

    final ok = await ref.read(authProvider.notifier).resendVerificationEmail();
    if (!mounted) return;

    if (ok) {
      _startCooldown();
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      setState(() {
        _isResending = false;
        _codeComplete = false;
      });
    } else {
      final authState = ref.read(authProvider);
      setState(() {
        _isResending = false;
        _errorMsg = authState.errorMessage ?? 'Failed to resend. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final email = authState.pendingEmail ?? '';
    final scheme = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ─── Gradient Background ──────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF006B64),
                    Color(0xFF009E95),
                    Color(0xFF004E49),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // ─── Content ──────────────────────────────────
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        // ─── Icon ─────────────────────────
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                AppColors.primary.withValues(alpha: 0.15),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.mark_email_read_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        )
                            .animate()
                            .scale(
                              duration: 600.ms,
                              curve: Curves.elasticOut,
                              begin: const Offset(0.5, 0.5),
                            )
                            .fadeIn(),

                        const SizedBox(height: 28),

                        // ─── Title ────────────────────────
                        const Text(
                          'Verify your email',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        )
                            .animate()
                            .fadeIn(delay: 150.ms)
                            .slideY(begin: 0.2, end: 0),

                        const SizedBox(height: 10),

                        Text(
                          'Enter the 6-digit code sent to',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 4),

                        Text(
                          email,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 220.ms),

                        const SizedBox(height: 36),

                        // ─── OTP boxes ────────────────────
                        AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            final offset = _shakeController.isAnimating
                                ? ((_shakeAnimation.value * 2 - 1) * 8)
                                : 0.0;
                            return Transform.translate(
                              offset: Offset(offset, 0),
                              child: child,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _codeLength,
                              (i) => _OtpBox(
                                controller: _controllers[i],
                                focusNode: _focusNodes[i],
                                index: i,
                                isFilled: _controllers[i].text.isNotEmpty,
                                hasError: _errorMsg != null,
                                onChanged: (v) => _onDigitChanged(i, v),
                                onBackspace: () {
                                  if (_controllers[i].text.isEmpty &&
                                      i > 0) {
                                    _controllers[i - 1].clear();
                                    _focusNodes[i - 1].requestFocus();
                                    setState(() => _codeComplete = false);
                                  }
                                },
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15),

                        const SizedBox(height: 20),

                        // ─── Error message ────────────────
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          child: _errorMsg != null
                              ? Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          Colors.red.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMsg!,
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                  .animate()
                                  .fadeIn()
                                  .slideY(begin: -0.2)
                              : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 8),

                        // ─── Verify button ────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: _codeComplete && !_isVerifying
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF5A52C8),
                                        AppColors.primary,
                                        AppColors.primaryLight,
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    )
                                  : LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.08),
                                        Colors.white.withValues(alpha: 0.08),
                                      ],
                                    ),
                              boxShadow: _codeComplete && !_isVerifying
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: (_codeComplete && !_isVerifying)
                                    ? _verify
                                    : null,
                                child: Center(
                                  child: _isVerifying
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Verify & Continue',
                                              style: TextStyle(
                                                color: _codeComplete
                                                    ? Colors.white
                                                    : Colors.white
                                                        .withValues(alpha: 0.35),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              color: _codeComplete
                                                  ? Colors.white
                                                  : Colors.white
                                                      .withValues(alpha: 0.35),
                                              size: 17,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 350.ms),

                        const SizedBox(height: 28),

                        // ─── Divider ──────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                "Didn't receive it?",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 400.ms),

                        const SizedBox(height: 16),

                        // ─── Resend button ────────────────
                        GestureDetector(
                          onTap: (_secondsLeft > 0 || _isResending)
                              ? null
                              : _resend,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: (_secondsLeft > 0 || _isResending)
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (_secondsLeft > 0 || _isResending)
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isResending)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 15,
                                    color: _secondsLeft > 0
                                        ? Colors.white.withValues(alpha: 0.35)
                                        : Colors.white,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  _isResending
                                      ? 'Sending...'
                                      : _secondsLeft > 0
                                          ? 'Resend in ${_secondsLeft}s'
                                          : 'Resend code',
                                  style: TextStyle(
                                    color: _secondsLeft > 0
                                        ? Colors.white.withValues(alpha: 0.35)
                                        : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 450.ms),

                        const SizedBox(height: 24),

                        // ─── Back to login ────────────────
                        TextButton.icon(
                          onPressed: () async {
                            await ref.read(authProvider.notifier).logout();
                            if (mounted) context.go(AppRoutes.login);
                          },
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          label: Text(
                            'Use a different email',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                          ),
                        ).animate().fadeIn(delay: 500.ms),

                        const SizedBox(height: 12),

                        // ─── Spam tip ─────────────────────
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 14,
                                color: Colors.yellow.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Check your spam or junk folder if you don\'t see the email. The code expires in 10 minutes.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.45),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 550.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Individual OTP Box ───────────────────────────────────

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
    return Container(
      width: 48,
      height: 58,
      margin: const EdgeInsets.symmetric(horizontal: 4),
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
          maxLength: _OtpBox._maxLen,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: isFilled
                ? AppColors.primary.withValues(alpha: hasError ? 0 : 0.20)
                : Colors.white.withValues(alpha: 0.07),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: hasError
                    ? Colors.red.withValues(alpha: 0.6)
                    : isFilled
                        ? AppColors.primary.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.15),
                width: isFilled ? 2 : 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: hasError ? Colors.redAccent : AppColors.primary,
                width: 2,
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    )
        .animate(delay: (index * 60).ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.3, end: 0, curve: Curves.easeOutBack);
  }

  static const int _maxLen = 1;
}
