import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';

// ─── Step metadata ────────────────────────────────────────

final _steps = [
  _StepMeta(
    icon: Icons.person_rounded,
    title: 'Create Account',
    subtitle: 'Set up your secure wellness space',
    colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF0EA5E9)],
    accent: AppColors.primary,
  ),
  _StepMeta(
    icon: Icons.school_rounded,
    title: 'Your University',
    subtitle: 'Helps us personalize your experience',
    colors: [Color(0xFF006B64), AppColors.primary, Color(0xFF0EA5E9)],
    accent: AppColors.primary,
  ),
  _StepMeta(
    icon: Icons.auto_awesome_rounded,
    title: 'Wellness Goals',
    subtitle: "Tell Maya what you're working on",
    colors: [AppColors.primaryDark, AppColors.primary, Color(0xFF10B981)],
    accent: AppColors.tertiary,
  ),
];

class _StepMeta {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final Color accent;
  const _StepMeta({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.accent,
  });
}

// ─── Goal options ─────────────────────────────────────────

const _kGoals = [
  {'id': 'anxiety', 'label': 'Manage Anxiety', 'emoji': '😌'},
  {'id': 'depression', 'label': 'Cope with Depression', 'emoji': '💙'},
  {'id': 'stress', 'label': 'Academic Stress', 'emoji': '📚'},
  {'id': 'sleep', 'label': 'Better Sleep', 'emoji': '😴'},
  {'id': 'social', 'label': 'Social Confidence', 'emoji': '🤝'},
  {'id': 'motivation', 'label': 'Boost Motivation', 'emoji': '🚀'},
  {'id': 'mindfulness', 'label': 'Mindfulness', 'emoji': '🧘'},
  {'id': 'selfesteem', 'label': 'Self-Esteem', 'emoji': '💪'},
  {'id': 'grief', 'label': 'Process Grief', 'emoji': '🌹'},
  {'id': 'relationships', 'label': 'Relationships', 'emoji': '❤️'},
];

// ─── Year options ─────────────────────────────────────────

const _kYears = [
  {'label': 'Freshman', 'sub': '1st year', 'icon': Icons.looks_one_rounded, 'value': 1},
  {'label': 'Sophomore', 'sub': '2nd year', 'icon': Icons.looks_two_rounded, 'value': 2},
  {'label': 'Junior', 'sub': '3rd year', 'icon': Icons.looks_3_rounded, 'value': 3},
  {'label': 'Senior', 'sub': '4th year', 'icon': Icons.looks_4_rounded, 'value': 4},
  {'label': '5th Year', 'sub': 'Extended', 'icon': Icons.looks_5_rounded, 'value': 5},
  {'label': 'Graduate', 'sub': 'Masters/PhD', 'icon': Icons.school_rounded, 'value': 6},
];

// ─── Breakpoints helper ───────────────────────────────────

extension _Resp on BuildContext {
  double get sw => MediaQuery.of(this).size.width;
  bool get isMobile => sw < 600;
  double get cardMaxWidth => isMobile ? double.infinity : 460.0;
}

// ─── Main screen ──────────────────────────────────────────

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _step = 0;

  // Step 1 fields
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  double _passStrength = 0;
  String _avatarInitials = '?';

  // Step 2 fields
  final _uniCtrl = TextEditingController();
  int? _selectedYear;

  // Step 3 fields
  final Set<String> _selectedGoals = {};

  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
    _passCtrl.addListener(_onPassChanged);
  }

  void _onNameChanged() {
    final parts = _nameCtrl.text.trim().split(' ');
    String initials = '';
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      initials = parts[0][0].toUpperCase();
      if (parts.length > 1 && parts[1].isNotEmpty) {
        initials += parts[1][0].toUpperCase();
      }
    }
    setState(() => _avatarInitials = initials.isEmpty ? '?' : initials);
  }

  void _onPassChanged() {
    final p = _passCtrl.text;
    double s = 0;
    if (p.length >= 6) s += 0.25;
    if (p.length >= 10) s += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(p)) s += 0.25;
    if (RegExp(r'[0-9!@#\$%^&*]').hasMatch(p)) s += 0.25;
    setState(() => _passStrength = s);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _uniCtrl.dispose();
    super.dispose();
  }

  bool _validateStep1() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Please enter your name');
      return false;
    }
    if (!_emailCtrl.text.contains('@')) {
      setState(() => _errorMsg = 'Enter a valid email');
      return false;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _errorMsg = 'Password must be at least 6 characters');
      return false;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _errorMsg = 'Passwords do not match');
      return false;
    }
    setState(() => _errorMsg = null);
    return true;
  }

  void _nextStep() {
    if (_step == 0 && !_validateStep1()) return;
    if (_step < 2) {
      setState(() {
        _step++;
        _errorMsg = null;
      });
      _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() {
        _step--;
        _errorMsg = null;
      });
      _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go(AppRoutes.login);
    }
  }

  Future<void> _submit() async {
    if (_selectedGoals.isEmpty) {
      setState(() => _errorMsg = 'Please select at least one goal');
      return;
    }
    setState(() => _errorMsg = null);
    final ok = await ref.read(authProvider.notifier).register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          university: _uniCtrl.text.trim().isEmpty
              ? null
              : _uniCtrl.text.trim(),
          yearOfStudy: _selectedYear,
          goals: _selectedGoals.toList(),
        );
    if (!ok || !mounted) return;
    final auth = ref.read(authProvider);
    if (auth.isPendingVerification) {
      context.go(AppRoutes.verifyEmail);
    } else if (auth.isAuthenticated) {
      context.go(AppRoutes.home);
    }
  }

  Color get _strengthColor {
    if (_passStrength <= 0.25) return AppColors.error;
    if (_passStrength <= 0.5) return const Color(0xFFFF9800);
    if (_passStrength <= 0.75) return const Color(0xFF42A5F5);
    return AppColors.success;
  }

  String get _strengthLabel {
    if (_passStrength <= 0.25) return 'Weak';
    if (_passStrength <= 0.5) return 'Fair';
    if (_passStrength <= 0.75) return 'Good';
    return 'Strong 💪';
  }

  @override
  Widget build(BuildContext context) {
    final meta = _steps[_step];
    final auth = ref.watch(authProvider);
    final err = _errorMsg ?? auth.errorMessage;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            _MeshBg(accent: meta.accent),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.isMobile ? 0 : 24,
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: context.cardMaxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(meta, context),
                        _buildWhiteCard(meta, auth, err, context),
                        const SizedBox(height: 16),
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

  // ─── Header ──────────────────────────────────────────────

  Widget _buildHeader(_StepMeta meta, BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        borderRadius: context.isMobile
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(24)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: meta.colors,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _prevStep,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _step == 0
                        ? Icons.close_rounded
                        : Icons.arrow_back_rounded,
                    color: Colors.white, size: 18,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'Step ${_step + 1} of 3',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(_step),
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35), width: 1.5),
              ),
              child: Icon(meta.icon, color: Colors.white, size: 24),
            ),
          ),

          const SizedBox(height: 10),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Column(
              key: ValueKey('t$_step'),
              children: [
                Text(
                  meta.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Text(
                  meta.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final active = i == _step;
              final done = i < _step;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: done || active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.30),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── White card ──────────────────────────────────────────

  Widget _buildWhiteCard(
      _StepMeta meta, AuthState auth, String? err, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: context.isMobile
            ? BorderRadius.zero
            : const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              children: [
                SizedBox(
                  height: _stepHeight,
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _Step1(
                        nameCtrl: _nameCtrl,
                        emailCtrl: _emailCtrl,
                        passCtrl: _passCtrl,
                        confirmCtrl: _confirmCtrl,
                        obscurePass: _obscurePass,
                        obscureConfirm: _obscureConfirm,
                        passStrength: _passStrength,
                        strengthColor: _strengthColor,
                        strengthLabel: _strengthLabel,
                        avatarInitials: _avatarInitials,
                        accent: meta.accent,
                        onTogglePass: () =>
                            setState(() => _obscurePass = !_obscurePass),
                        onToggleConfirm: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                      ),
                      _Step2(
                        uniCtrl: _uniCtrl,
                        selectedYear: _selectedYear,
                        accent: meta.accent,
                        onYearSelected: (v) =>
                            setState(() => _selectedYear = v),
                      ),
                      _Step3(
                        selected: _selectedGoals,
                        accent: meta.accent,
                        onToggle: (id) => setState(() {
                          if (_selectedGoals.contains(id)) {
                            _selectedGoals.remove(id);
                          } else {
                            _selectedGoals.add(id);
                          }
                        }),
                      ),
                    ],
                  ),
                ),

                if (err != null) ...[
                  const SizedBox(height: 10),
                  _ErrBanner(message: err),
                ],

                const SizedBox(height: 14),

                _GlowButton(
                  label: _step == 2 ? 'Create My Account' : 'Continue',
                  icon: _step == 2
                      ? Icons.check_circle_outline_rounded
                      : Icons.arrow_forward_rounded,
                  onTap: _nextStep,
                  isLoading: auth.isLoading,
                  accent: meta.accent,
                ),

                const SizedBox(height: 12),

                GestureDetector(
                  onTap: () => context.go(AppRoutes.login),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                      children: [
                        TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Sign in →',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double get _stepHeight {
    switch (_step) {
      case 0:
        return 490;
      case 1:
        return 370;
      case 2:
        return 370;
      default:
        return 400;
    }
  }
}

// ─── Mesh background ──────────────────────────────────────

class _MeshBg extends StatelessWidget {
  final Color accent;
  const _MeshBg({required this.accent});

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
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.2,
              colors: [
                accent.withValues(alpha: 0.38),
                accent.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Step 1: Account ─────────────────────────────────────

class _Step1 extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final bool obscurePass;
  final bool obscureConfirm;
  final double passStrength;
  final Color strengthColor;
  final String strengthLabel;
  final String avatarInitials;
  final Color accent;
  final VoidCallback onTogglePass;
  final VoidCallback onToggleConfirm;

  const _Step1({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.obscurePass,
    required this.obscureConfirm,
    required this.passStrength,
    required this.strengthColor,
    required this.strengthLabel,
    required this.avatarInitials,
    required this.accent,
    required this.onTogglePass,
    required this.onToggleConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  avatarInitials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ).animate().scale(
              begin: const Offset(0.5, 0.5),
              duration: 400.ms,
              curve: Curves.easeOutBack),

          const SizedBox(height: 14),

          _RegField(
            controller: nameCtrl,
            label: 'Full Name',
            icon: Icons.badge_outlined,
            accent: accent,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.12),

          const SizedBox(height: 9),

          _RegField(
            controller: emailCtrl,
            label: 'Email address',
            icon: Icons.alternate_email_rounded,
            accent: accent,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.12),

          const SizedBox(height: 9),

          _RegField(
            controller: passCtrl,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            accent: accent,
            isPassword: true,
            obscure: obscurePass,
            onToggle: onTogglePass,
            textInputAction: TextInputAction.next,
          ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.12),

          if (passCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: passStrength,
                      minHeight: 4,
                      backgroundColor: AppColors.border,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(strengthColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  strengthLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: strengthColor,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 9),

          _RegField(
            controller: confirmCtrl,
            label: 'Confirm Password',
            icon: Icons.lock_outline_rounded,
            accent: accent,
            isPassword: true,
            obscure: obscureConfirm,
            onToggle: onToggleConfirm,
            textInputAction: TextInputAction.done,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.12),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 13, color: accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Your data is encrypted end-to-end. We never share your information.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 240.ms),
        ],
      ),
    );
  }
}

// ─── Step 2: University ───────────────────────────────────

class _Step2 extends StatelessWidget {
  final TextEditingController uniCtrl;
  final int? selectedYear;
  final Color accent;
  final ValueChanged<int> onYearSelected;

  const _Step2({
    required this.uniCtrl,
    required this.selectedYear,
    required this.accent,
    required this.onYearSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RegField(
          controller: uniCtrl,
          label: 'University / College',
          icon: Icons.account_balance_outlined,
          accent: accent,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
        ).animate().fadeIn(delay: 50.ms),

        const SizedBox(height: 14),

        Text(
          'Year of Study',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 7,
            mainAxisSpacing: 7,
            childAspectRatio: 1.55,
            children: List.generate(_kYears.length, (i) {
              final y = _kYears[i];
              final val = y['value'] as int;
              final isSel = selectedYear == val;
              return GestureDetector(
                onTap: () => onYearSelected(val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSel
                        ? accent.withValues(alpha: 0.10)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: isSel ? accent : AppColors.border,
                      width: isSel ? 2 : 1.5,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        y['icon'] as IconData,
                        size: 16,
                        color: isSel ? accent : AppColors.textMuted,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        y['label'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSel
                              ? accent
                              : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        y['sub'] as String,
                        style: TextStyle(
                          fontSize: 8,
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 12, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Text(
              'Optional — you can always update this later.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Step 3: Goals ────────────────────────────────────────

class _Step3 extends StatelessWidget {
  final Set<String> selected;
  final Color accent;
  final ValueChanged<String> onToggle;

  const _Step3({
    required this.selected,
    required this.accent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'What brings you here?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            if (selected.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    accent,
                    accent.withValues(alpha: 0.7)
                  ]),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  '${selected.length} selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 7,
            mainAxisSpacing: 7,
            childAspectRatio: 2.5,
            children: List.generate(_kGoals.length, (i) {
              final g = _kGoals[i];
              final id = g['id'] as String;
              final isSel = selected.contains(id);
              return GestureDetector(
                onTap: () => onToggle(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    gradient: isSel
                        ? LinearGradient(
                            colors: [
                              accent,
                              accent.withValues(alpha: 0.75)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSel ? null : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color:
                          isSel ? accent : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  child: Row(
                    children: [
                      Text(g['emoji'] as String,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          g['label'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSel
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (isSel)
                        const Icon(Icons.check_circle_rounded,
                            size: 13, color: Colors.white),
                    ],
                  ),
                ).animate(delay: (i * 35).ms).fadeIn(duration: 280.ms),
              );
            }),
          ),
        ),

        if (selected.isEmpty) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 5),
              Text(
                'Pick at least one to personalize Maya for you.',
                style:
                    TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Shared: Register text field ─────────────────────────

class _RegField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color accent;
  final bool isPassword;
  final bool? obscure;
  final VoidCallback? onToggle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

  const _RegField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.accent,
    this.isPassword = false,
    this.obscure,
    this.onToggle,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? (obscure ?? true) : false,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
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
          borderSide: BorderSide(color: accent, width: 2),
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(9),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accent, size: 15),
        ),
        suffixIcon: isPassword
            ? IconButton(
                onPressed: onToggle,
                icon: Icon(
                  (obscure ?? true)
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 17,
                  color: AppColors.textMuted,
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
      ),
    );
  }
}

// ─── Shared: Glow button ─────────────────────────────────

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
        height: 50,
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
                            (HSLColor.fromColor(base).lightness - 0.08)
                                .clamp(0, 1))
                        .toColor(),
                    base,
                    HSLColor.fromColor(base)
                        .withLightness(
                            (HSLColor.fromColor(base).lightness + 0.10)
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
                    color: base.withValues(alpha: 0.38),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 7),
                      Icon(icon, color: Colors.white, size: 16),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Shared: Error banner ────────────────────────────────

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
        border:
            Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 15),
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
    ).animate().shake(duration: 350.ms).fadeIn();
  }
}
