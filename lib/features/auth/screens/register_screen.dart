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
    title: 'Your Academic Life',
    subtitle: 'Helps Maya understand your world',
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
  _StepMeta(
    icon: Icons.bolt_rounded,
    title: 'Current Stressors',
    subtitle: "What's weighing on you right now?",
    colors: [Color(0xFF7C2D12), Color(0xFFEA580C), Color(0xFFF59E0B)],
    accent: AppColors.secondary,
  ),
  _StepMeta(
    icon: Icons.psychology_rounded,
    title: "Personalise Maya",
    subtitle: 'Make her feel like yours',
    colors: [Color(0xFF1A0533), Color(0xFF6C3FC7), Color(0xFF00BEB4)],
    accent: AppColors.primary,
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

// ─── Option data ──────────────────────────────────────────

const _kGoals = [
  {'id': 'anxiety', 'label': 'Manage Anxiety', 'emoji': '😌'},
  {'id': 'depression', 'label': 'Cope with Low Mood', 'emoji': '💙'},
  {'id': 'stress', 'label': 'Academic Stress', 'emoji': '📚'},
  {'id': 'sleep', 'label': 'Better Sleep', 'emoji': '😴'},
  {'id': 'social', 'label': 'Social Confidence', 'emoji': '🤝'},
  {'id': 'motivation', 'label': 'Boost Motivation', 'emoji': '🚀'},
  {'id': 'mindfulness', 'label': 'Mindfulness', 'emoji': '🧘'},
  {'id': 'selfesteem', 'label': 'Self-Esteem', 'emoji': '💪'},
  {'id': 'grief', 'label': 'Process Grief', 'emoji': '🌹'},
  {'id': 'relationships', 'label': 'Relationships', 'emoji': '❤️'},
];

const _kStressors = [
  {'id': 'exams', 'label': 'Exams & Deadlines', 'emoji': '📝'},
  {'id': 'finances', 'label': 'Financial Pressure', 'emoji': '💰'},
  {'id': 'loneliness', 'label': 'Loneliness', 'emoji': '🌧️'},
  {'id': 'family', 'label': 'Family Issues', 'emoji': '🏠'},
  {'id': 'relationships_stress', 'label': 'Relationship Stress', 'emoji': '💔'},
  {'id': 'career', 'label': 'Career / Future', 'emoji': '🎯'},
  {'id': 'identity', 'label': 'Identity & Purpose', 'emoji': '🔍'},
  {'id': 'health', 'label': 'Physical Health', 'emoji': '🏥'},
  {'id': 'performance', 'label': 'Performance Anxiety', 'emoji': '😰'},
  {'id': 'time', 'label': 'Time Management', 'emoji': '⏰'},
];

const _kYears = [
  {'label': 'Freshman', 'sub': '1st year', 'icon': Icons.looks_one_rounded, 'value': 1},
  {'label': 'Sophomore', 'sub': '2nd year', 'icon': Icons.looks_two_rounded, 'value': 2},
  {'label': 'Junior', 'sub': '3rd year', 'icon': Icons.looks_3_rounded, 'value': 3},
  {'label': 'Senior', 'sub': '4th year', 'icon': Icons.looks_4_rounded, 'value': 4},
  {'label': '5th Year', 'sub': 'Extended', 'icon': Icons.looks_5_rounded, 'value': 5},
  {'label': 'Graduate', 'sub': 'Masters/PhD', 'icon': Icons.school_rounded, 'value': 6},
];

const _kFaculties = [
  'Engineering & Technology',
  'Medicine & Health Sciences',
  'Business & Economics',
  'Arts & Humanities',
  'Natural Sciences',
  'Law',
  'Education',
  'Architecture & Design',
  'Social Sciences',
  'Computer Science',
  'Mathematics & Statistics',
  'Other',
];

const _kCheckInTimes = [
  {'id': 'morning', 'label': 'Morning', 'sub': 'Start the day grounded', 'emoji': '🌅'},
  {'id': 'afternoon', 'label': 'Afternoon', 'sub': 'Midday check-in', 'emoji': '☀️'},
  {'id': 'evening', 'label': 'Evening', 'sub': 'Reflect on the day', 'emoji': '🌙'},
  {'id': 'any', 'label': 'Any Time', 'sub': "I'll decide each day", 'emoji': '🔄'},
];

const _kTherapyExp = [
  {'id': 'never', 'label': 'First time', 'sub': "I've never used mental health tools", 'emoji': '🌱'},
  {'id': 'apps', 'label': 'Used apps before', 'sub': "I've tried wellness apps", 'emoji': '📱'},
  {'id': 'therapy', 'label': 'In / had therapy', 'sub': 'Professional support experience', 'emoji': '🛋️'},
];

// ─── Responsive helpers ───────────────────────────────────

extension _Resp on BuildContext {
  double get sw => MediaQuery.of(this).size.width;
  bool get isMobile => sw < 600;
  double get cardMaxWidth => isMobile ? double.infinity : 480.0;
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
  static const _kTotalSteps = 5;

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
  String? _selectedFaculty;

  // Step 3 fields
  final Set<String> _selectedGoals = {};

  // Step 4 fields
  final Set<String> _selectedStressors = {};

  // Step 5 fields
  String _mayaPersonality = 'warm';
  String _checkInTime = 'any';
  String _therapyExperience = 'never';

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
    if (_step == 2 && _selectedGoals.isEmpty) {
      setState(() => _errorMsg = 'Pick at least one goal');
      return;
    }
    setState(() => _errorMsg = null);

    if (_step < _kTotalSteps - 1) {
      setState(() => _step++);
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
    setState(() => _errorMsg = null);
    final ok = await ref.read(authProvider.notifier).register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          university: _uniCtrl.text.trim().isEmpty ? null : _uniCtrl.text.trim(),
          yearOfStudy: _selectedYear,
          faculty: _selectedFaculty,
          goals: _selectedGoals.toList(),
          stressors: _selectedStressors.toList(),
          mayaPersonality: _mayaPersonality,
          checkInTime: _checkInTime,
          therapyExperience: _therapyExperience,
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

  // Heights per step to avoid overflow
  double get _stepHeight {
    switch (_step) {
      case 0: return 420;
      case 1: return 480;
      case 2: return 380;
      case 3: return 360;
      case 4: return 460;
      default: return 400;
    }
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
                    constraints: BoxConstraints(maxWidth: context.cardMaxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(meta),
                        _buildWhiteCard(meta, auth, err),
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

  Widget _buildHeader(_StepMeta meta) {
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
                    _step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
                    color: Colors.white, size: 18,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'Step ${_step + 1} of $_kTotalSteps',
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
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
                Text(meta.title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    textAlign: TextAlign.center),
                const SizedBox(height: 3),
                Text(meta.subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.80), fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_kTotalSteps, (i) {
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

  // ─── White card ───────────────────────────────────────────

  Widget _buildWhiteCard(_StepMeta meta, AuthState auth, String? err) {
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
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
                        onTogglePass: () => setState(() => _obscurePass = !_obscurePass),
                        onToggleConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      _Step2(
                        uniCtrl: _uniCtrl,
                        selectedYear: _selectedYear,
                        selectedFaculty: _selectedFaculty,
                        accent: meta.accent,
                        onYearSelected: (v) => setState(() => _selectedYear = v),
                        onFacultySelected: (v) => setState(() => _selectedFaculty = v),
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
                      _Step4(
                        selected: _selectedStressors,
                        accent: meta.accent,
                        onToggle: (id) => setState(() {
                          if (_selectedStressors.contains(id)) {
                            _selectedStressors.remove(id);
                          } else {
                            _selectedStressors.add(id);
                          }
                        }),
                      ),
                      _Step5(
                        personality: _mayaPersonality,
                        checkInTime: _checkInTime,
                        therapyExperience: _therapyExperience,
                        accent: meta.accent,
                        onPersonalityChanged: (v) => setState(() => _mayaPersonality = v),
                        onCheckInTimeChanged: (v) => setState(() => _checkInTime = v),
                        onTherapyExpChanged: (v) => setState(() => _therapyExperience = v),
                      ),
                    ],
                  ),
                ),

                if (err != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(err,
                              style: TextStyle(
                                  color: AppColors.error, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: meta.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            _step < _kTotalSteps - 1 ? 'Continue' : 'Create My Account',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                  ),
                ),

                if (_step == 0) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account? ',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.login),
                        child: Text('Sign in',
                            style: TextStyle(
                                color: meta.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],

                if (_step >= 1 && _step < _kTotalSteps - 1) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _nextStep,
                    child: Text('Skip for now',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
        children: [
          Center(
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(avatarInitials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Field(label: 'Full Name', ctrl: nameCtrl, hint: 'Your name', accent: accent),
          const SizedBox(height: 12),
          _Field(label: 'Email', ctrl: emailCtrl, hint: 'uni@example.com',
              keyboardType: TextInputType.emailAddress, accent: accent),
          const SizedBox(height: 12),
          _Field(
            label: 'Password', ctrl: passCtrl, hint: '••••••••',
            obscure: obscurePass, accent: accent,
            suffix: IconButton(
              icon: Icon(obscurePass ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  size: 18, color: AppColors.textMuted),
              onPressed: onTogglePass,
            ),
          ),
          if (passCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: passStrength,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(strengthColor),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(strengthLabel,
                    style: TextStyle(
                        fontSize: 11, color: strengthColor,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _Field(
            label: 'Confirm Password', ctrl: confirmCtrl, hint: '••••••••',
            obscure: obscureConfirm, accent: accent,
            suffix: IconButton(
              icon: Icon(obscureConfirm ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  size: 18, color: AppColors.textMuted),
              onPressed: onToggleConfirm,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 2: Academic Info ────────────────────────────────

class _Step2 extends StatelessWidget {
  final TextEditingController uniCtrl;
  final int? selectedYear;
  final String? selectedFaculty;
  final Color accent;
  final ValueChanged<int> onYearSelected;
  final ValueChanged<String?> onFacultySelected;

  const _Step2({
    required this.uniCtrl,
    required this.selectedYear,
    required this.selectedFaculty,
    required this.accent,
    required this.onYearSelected,
    required this.onFacultySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Field(
            label: 'University / College',
            ctrl: uniCtrl,
            hint: 'e.g. University of Cape Town',
            accent: accent,
          ),
          const SizedBox(height: 16),

          // Faculty dropdown
          Text('Field of Study',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedFaculty,
                hint: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('Select your faculty',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                ),
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                items: _kFaculties
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f, style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: onFacultySelected,
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text('Year of Study',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: _kYears.map((y) {
              final val = y['value'] as int;
              final active = selectedYear == val;
              return GestureDetector(
                onTap: () => onYearSelected(val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: active ? accent.withValues(alpha: 0.12) : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? accent : AppColors.border,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(y['label'] as String,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: active ? accent : AppColors.textPrimary)),
                      Text(y['sub'] as String,
                          style: TextStyle(
                              fontSize: 9, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
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
        Text('Select all that apply',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: false,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3.0,
            children: _kGoals.map((g) {
              final id = g['id'] as String;
              final active = selected.contains(id);
              return GestureDetector(
                onTap: () => onToggle(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: active ? accent.withValues(alpha: 0.12) : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? accent : AppColors.border,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Text(g['emoji'] as String, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(g['label'] as String,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: active ? accent : AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Step 4: Stressors ────────────────────────────────────

class _Step4 extends StatelessWidget {
  final Set<String> selected;
  final Color accent;
  final ValueChanged<String> onToggle;

  const _Step4({
    required this.selected,
    required this.accent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Maya will remember this to support you better",
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: false,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3.0,
            children: _kStressors.map((s) {
              final id = s['id'] as String;
              final active = selected.contains(id);
              return GestureDetector(
                onTap: () => onToggle(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: active
                        ? accent.withValues(alpha: 0.12)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? accent : AppColors.border,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Text(s['emoji'] as String, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(s['label'] as String,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: active ? accent : AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Step 5: Personalise Maya ─────────────────────────────

class _Step5 extends StatelessWidget {
  final String personality;
  final String checkInTime;
  final String therapyExperience;
  final Color accent;
  final ValueChanged<String> onPersonalityChanged;
  final ValueChanged<String> onCheckInTimeChanged;
  final ValueChanged<String> onTherapyExpChanged;

  const _Step5({
    required this.personality,
    required this.checkInTime,
    required this.therapyExperience,
    required this.accent,
    required this.onPersonalityChanged,
    required this.onCheckInTimeChanged,
    required this.onTherapyExpChanged,
  });

  static const _personalities = [
    {'id': 'warm', 'label': 'Warm & Supportive', 'sub': 'Gentle, empathetic, nurturing', 'emoji': '🤗'},
    {'id': 'direct', 'label': 'Direct & Practical', 'sub': 'Straight talk, clear advice', 'emoji': '🎯'},
    {'id': 'playful', 'label': 'Light & Playful', 'sub': 'Uplifting, light-hearted', 'emoji': '✨'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Maya personality
          _SectionLabel("Maya's Communication Style"),
          const SizedBox(height: 8),
          ..._personalities.map((p) {
            final id = p['id'] as String;
            final active = personality == id;
            return GestureDetector(
              onTap: () => onPersonalityChanged(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: active ? accent.withValues(alpha: 0.10) : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? accent : AppColors.border,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(p['emoji'] as String, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['label'] as String,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: active ? accent : AppColors.textPrimary)),
                          Text(p['sub'] as String,
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    if (active)
                      Icon(Icons.check_circle_rounded, color: accent, size: 18),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 14),

          // Check-in time
          _SectionLabel('Preferred Check-in Time'),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.8,
            children: _kCheckInTimes.map((t) {
              final id = t['id'] as String;
              final active = checkInTime == id;
              return GestureDetector(
                onTap: () => onCheckInTimeChanged(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: active ? accent.withValues(alpha: 0.10) : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? accent : AppColors.border,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Text(t['emoji'] as String, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['label'] as String,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: active ? accent : AppColors.textPrimary)),
                            Text(t['sub'] as String,
                                style: TextStyle(
                                    fontSize: 9, color: AppColors.textMuted),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Therapy experience
          _SectionLabel('Experience with Mental Health Support'),
          const SizedBox(height: 8),
          ..._kTherapyExp.map((e) {
            final id = e['id'] as String;
            final active = therapyExperience == id;
            return GestureDetector(
              onTap: () => onTherapyExpChanged(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? accent.withValues(alpha: 0.10) : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? accent : AppColors.border,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(e['emoji'] as String, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['label'] as String,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: active ? accent : AppColors.textPrimary)),
                          Text(e['sub'] as String,
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    if (active)
                      Icon(Icons.check_circle_rounded, color: accent, size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Section label helper ─────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );
}

// ─── Reusable field ───────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? suffix;
  final Color accent;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    required this.accent,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent, width: 1.5),
            ),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

// ─── Mesh background ──────────────────────────────────────

class _MeshBg extends StatelessWidget {
  final Color accent;
  const _MeshBg({required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.15),
              Colors.white,
              accent.withValues(alpha: 0.05),
            ],
          ),
        ),
      ),
    );
  }
}
