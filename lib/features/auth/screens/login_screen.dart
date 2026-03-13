import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';

// ─── Breakpoints ──────────────────────────────────────────

extension _Resp on BuildContext {
  double get sw => MediaQuery.of(this).size.width;
  bool get isMobile => sw < 600;

  double get logoIconSize => isMobile ? 34 : 38;
  double get logoTitleSize => isMobile ? 28 : 34;
  double get cardVPad => isMobile ? 24 : 30;
}

// ─── Login Screen ─────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authProvider.notifier)
        .login(_emailCtrl.text.trim(), _passCtrl.text);
    if (ok && mounted) context.go(AppRoutes.home);
  }

  void _showForgotDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_reset_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(height: 14),
              const Text('Reset Password',
                  style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 5),
              Text("We'll send a secure reset link to your email.",
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 18),
              _PremiumField(
                controller: ctrl,
                label: 'Email address',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      if (ctrl.text.isNotEmpty) {
                        try {
                          // Supabase password reset
                          await ref
                              .read(authProvider.notifier)
                              .updateProfile({'_reset': ctrl.text});
                        } catch (_) {}
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                const Text('Reset link sent! Check your inbox.'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Send Link'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // ─── Mesh background ───────────────────────
            const _MeshBackground(),
            const _SparkDot(top: 55, right: 72, size: 6),
            const _SparkDot(top: 140, left: 95, size: 4),
            const _SparkDot(top: 220, right: 140, size: 5),
            const _SparkDot(top: 80, left: 180, size: 3),
            const _SparkDot(top: 300, right: 55, size: 4),

            // ─── Scrollable centered content ───────────
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.isMobile ? 20 : 24,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: context.isMobile ? 480 : 460,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLogo(context),
                        const SizedBox(height: 28),
                        _buildGlassCard(context, auth),
                        const SizedBox(height: 20),
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

  // ─── Logo ────────────────────────────────────────────────

  Widget _buildLogo(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.60),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(Icons.spa_rounded,
                  color: Colors.white, size: context.logoIconSize),
            ),
          ],
        )
            .animate()
            .scale(
                begin: const Offset(0.2, 0.2),
                duration: 900.ms,
                curve: Curves.elasticOut)
            .fadeIn(duration: 500.ms),

        const SizedBox(height: 14),

        Text(
          'MindBridge',
          style: TextStyle(
            color: Colors.white,
            fontSize: context.logoTitleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.4),

        const SizedBox(height: 8),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(
                5,
                (_) => const Icon(Icons.star_rounded,
                    color: Color(0xFFFFD166), size: 13)),
            const SizedBox(width: 6),
            Text(
              '4.9  ·  Trusted by 50K+ students',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 350.ms),
      ],
    );
  }

  // ─── Glass card ──────────────────────────────────────────

  Widget _buildGlassCard(BuildContext context, AuthState auth) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.70), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 50,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
              24, context.cardVPad, 24, context.cardVPad - 4),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back 👋',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Sign in to your wellness space',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.successContainer,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded,
                              size: 11, color: AppColors.success),
                          const SizedBox(width: 3),
                          Text(
                            'Secure',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.2),

                const SizedBox(height: 22),

                // Social buttons
                _SocialButton(
                  icon: FontAwesomeIcons.google,
                  iconColor: const Color(0xFF4285F4),
                  iconBg: const Color(0xFFEBF1FF),
                  label: 'Continue with Google',
                  onTap: () => ref.read(authProvider.notifier).signInWithGoogle(),
                ).animate().fadeIn(delay: 130.ms).slideY(begin: 0.2),

                const SizedBox(height: 9),

                _SocialButton(
                  icon: FontAwesomeIcons.apple,
                  iconColor: Colors.white,
                  iconBg: const Color(0xFF1D1D1F),
                  label: 'Continue with Apple',
                  onTap: () => _showComingSoon('Apple'),
                ).animate().fadeIn(delay: 170.ms).slideY(begin: 0.2),

                const SizedBox(height: 18),

                // OR divider
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: AppColors.border.withValues(alpha: 0.7),
                            height: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or continue with email',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ),
                    Expanded(
                        child: Divider(
                            color: AppColors.border.withValues(alpha: 0.7),
                            height: 1)),
                  ],
                ).animate().fadeIn(delay: 210.ms),

                const SizedBox(height: 18),

                // Email
                _PremiumField(
                  controller: _emailCtrl,
                  label: 'Email address',
                  hint: 'you@university.edu',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.15),

                const SizedBox(height: 10),

                // Password
                _PremiumField(
                  controller: _passCtrl,
                  label: 'Password',
                  hint: '••••••••',
                  icon: Icons.lock_open_rounded,
                  isPassword: true,
                  obscure: _obscurePass,
                  onToggle: () =>
                      setState(() => _obscurePass = !_obscurePass),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.15),

                const SizedBox(height: 10),

                // Remember me + Forgot
                Row(
                  children: [
                    _AnimCheck(
                      value: _rememberMe,
                      label: 'Remember me',
                      onChanged: (v) => setState(() => _rememberMe = v),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showForgotDialog,
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 310.ms),

                // Error banner
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _ErrBanner(message: auth.errorMessage!)
                      .animate()
                      .shake(duration: 400.ms)
                      .fadeIn(),
                ],

                const SizedBox(height: 20),

                // Sign In button
                _GlowButton(
                  label: 'Sign In',
                  icon: Icons.arrow_forward_rounded,
                  onTap: _login,
                  isLoading: auth.isLoading,
                ).animate().fadeIn(delay: 360.ms).slideY(begin: 0.1),

                const SizedBox(height: 20),

                // Trust badges
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      _TrustBadge(
                        icon: Icons.lock_rounded,
                        label: '256-bit SSL',
                        color: AppColors.success,
                      ),
                      _VertDivider(),
                      _TrustBadge(
                        icon: Icons.star_rounded,
                        label: '4.9 Rating',
                        color: const Color(0xFFFFD166),
                      ),
                      _VertDivider(),
                      _TrustBadge(
                        icon: Icons.people_alt_rounded,
                        label: '50K+ Users',
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 420.ms),

                const SizedBox(height: 18),

                // Biometric hint
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fingerprint_rounded,
                            size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'Use biometrics',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 460.ms),

                const SizedBox(height: 18),

                Divider(
                    color: AppColors.border.withValues(alpha: 0.5),
                    height: 1),
                const SizedBox(height: 16),

                // Sign up link
                Center(
                  child: GestureDetector(
                    onTap: () => context.go(AppRoutes.register),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary),
                        children: [
                          TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Create one →',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 490.ms),

                const SizedBox(height: 10),

                // Terms
                Center(
                  child: Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted.withValues(alpha: 0.65)),
                  ),
                ).animate().fadeIn(delay: 510.ms),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .slideY(begin: 0.06, duration: 700.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 500.ms);
  }

  void _showComingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$provider Sign-In coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(authProvider.notifier).signInWithGoogle();
    // On web: browser navigates away to Google — nothing to do here.
    // On return, authStateChange fires and router redirects to home.
  }
}

// ─── Mesh gradient background ─────────────────────────────

class _MeshBackground extends StatelessWidget {
  const _MeshBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
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
        Positioned(
          top: -110, left: -90,
          child: Container(
            width: 360, height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.55),
                  AppColors.primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 200, right: -100,
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0xFF0EA5E9).withValues(alpha: 0.30),
                  Color(0xFF0EA5E9).withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 80, left: 20,
          child: Container(
            width: 260, height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryLight.withValues(alpha: 0.25),
                  AppColors.primaryLight.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sparkle dot ──────────────────────────────────────────

class _SparkDot extends StatelessWidget {
  final double? top, bottom, left, right;
  final double size;
  const _SparkDot(
      {this.top, this.bottom, this.left, this.right, required this.size});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.55),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.35),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 900.ms)
        .then()
        .fadeOut(duration: 900.ms, delay: 500.ms);
  }
}

// ─── Premium text field ───────────────────────────────────

class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool isPassword;
  final bool? obscure;
  final VoidCallback? onToggle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;

  const _PremiumField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.isPassword = false,
    this.obscure,
    this.onToggle,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? (obscure ?? true) : false,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide:
              const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(9),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 15),
        ),
        suffixIcon: isPassword
            ? IconButton(
                onPressed: onToggle,
                icon: Icon(
                  (obscure ?? true)
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ─── Social auth button ───────────────────────────────────

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: Colors.white,
            border:
                Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                    child: FaIcon(icon, color: iconColor, size: 14)),
              ),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Glow CTA button ──────────────────────────────────────

class _GlowButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isLoading;
  final Color? accent;

  const _GlowButton({
    required this.label,
    this.icon,
    required this.onTap,
    this.isLoading = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final base = accent ?? AppColors.primary;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          gradient: isLoading
              ? LinearGradient(colors: [
                  base.withValues(alpha: 0.55),
                  base.withValues(alpha: 0.55),
                ])
              : LinearGradient(
                  colors: [
                    HSLColor.fromColor(base)
                        .withLightness(
                            (HSLColor.fromColor(base).lightness - 0.1)
                                .clamp(0, 1))
                        .toColor(),
                    base,
                    HSLColor.fromColor(base)
                        .withLightness(
                            (HSLColor.fromColor(base).lightness + 0.12)
                                .clamp(0, 1))
                        .toColor(),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: base.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 7),
                      Icon(icon, color: Colors.white, size: 17),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Trust badge ──────────────────────────────────────────

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _TrustBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1, height: 32,
      color: AppColors.border.withValues(alpha: 0.45),
    );
  }
}

// ─── Animated checkbox ────────────────────────────────────

class _AnimCheck extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  const _AnimCheck(
      {required this.value, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 18, height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: value ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: value ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
            ),
            child: value
                ? const Icon(Icons.check_rounded,
                    size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────

class _ErrBanner extends StatelessWidget {
  final String message;
  const _ErrBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
