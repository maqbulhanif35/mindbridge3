import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/custom_button.dart';

class CrisisScreen extends StatelessWidget {
  const CrisisScreen({super.key});

  bool _isDesktop() {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _copyToClipboard(String number, BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$number copied to clipboard',
            style: const TextStyle(fontFamily: 'Nunito', color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E2D2B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _call(String number, BuildContext context) async {
    if (_isDesktop()) {
      await _copyToClipboard(number, context);
      return;
    }
    final cleanNumber = number.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
    print("REDIRECT-TO-PHONE-APP: $cleanNumber");
    final uri = Uri(scheme: "tel",path:cleanNumber);
    print("CAN-LAUNCH: ${await canLaunchUrl(uri)}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _text(String number, BuildContext context) async {
    if (_isDesktop()) {
      await _copyToClipboard(number, context);
      return;
    }
    final cleanNumber = number.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
    print("REDIRECT-TO-MESSAGING-APP: $cleanNumber");
    final uri = Uri(scheme:"smsto",path:cleanNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1A19),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crisis Support',
          style: TextStyle(
            fontFamily: 'Nunito',
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          children: [
            // ─── Hero Message ──────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.error.withOpacity(0.25),
                    const Color(0xFF0D1A19),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: AppColors.error.withOpacity(0.4), width: 1),
              ),
              child: Column(
                children: [
                  const Text(
                    '❤️',
                    style: TextStyle(fontSize: 48),
                  ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

                  const SizedBox(height: 12),

                  const Text(
                    'You Are Not Alone',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 12),

                  Text(
                    "Whatever you're going through right now, your life has value and people care about you. Reaching out takes courage — and you're already showing that courage.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.6,
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                ],
              ),
            ).animate().slideY(begin: -0.2, end: 0),

            const SizedBox(height: 24),

            // ─── SOS Button (Big) ──────────────────────
            Center(
              child: SosButton(
                onTap: () => _call('988', context),
              ),
            ).animate().scale(delay: 300.ms, curve: Curves.elasticOut),

            const SizedBox(height: 8),

            Text(
              _isDesktop()
                  ? 'Tap SOS to copy 988 to clipboard'
                  : 'Tap SOS to call 988 Suicide & Crisis Lifeline',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: Colors.white.withOpacity(0.5),
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 32),

            // ─── Crisis Contacts ───────────────────────
            const Text(
              'IMMEDIATE HELP',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
                letterSpacing: 1.5,
              ),
            ).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: 12),

            ...AppStrings.crisisContacts.asMap().entries.map((e) {
              final contact = e.value;
              return _CrisisContactCard(
                name: contact['name']!,
                number: contact['number']!,
                description: contact['description']!,
                type: contact['type']!,
                onCall: () => _call(contact['number']!, context),
                onText: contact['type'] == 'text'
                    ? () => _text(contact['number']!, context)
                    : null,
              )
                  .animate()
                  .fadeIn(delay: (500 + e.key * 80).ms)
                  .slideX(begin: 0.15);
            }),

            const SizedBox(height: 24),

            // ─── Safety Planning ───────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('📋', style: TextStyle(fontSize: 22)),
                      SizedBox(width: 10),
                      Text(
                        'Safety Planning',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...[
                    'Identify your warning signs early',
                    'Use healthy coping strategies first',
                    'Reach out to trusted friends or family',
                    'Contact a crisis line or counselor',
                    'Remove access to harmful means',
                    'Go to your nearest emergency room',
                  ].asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${e.key + 1}',
                                    style: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ).animate().fadeIn(delay: 700.ms),

            const SizedBox(height: 24),

            // ─── Grounding Technique ───────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ground yourself right now: 5-4-3-2-1',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    '5 things you can SEE right now',
                    '4 things you can TOUCH right now',
                    '3 things you can HEAR right now',
                    '2 things you can SMELL right now',
                    '1 thing you can TASTE right now',
                  ].map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.circle,
                              size: 8, color: AppColors.secondary),
                          const SizedBox(width: 10),
                          Text(
                            step,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 800.ms),

            const SizedBox(height: 24),

            // ─── I Am Safe Button ──────────────────────
            PrimaryButton(
              label: "I'm Safe Now ✓",
              onTap: () => Navigator.pop(context),
              // gradient: const LinearGradient(
              //   colors: [AppColors.success, AppColors.secondary],
              // ),
            ).animate().fadeIn(delay: 900.ms),
          ],
        ),
      ),
    );
  }
}

// ─── Crisis Contact Card ──────────────────────────────────

class _CrisisContactCard extends StatelessWidget {
  final String name;
  final String number;
  final String description;
  final String type;
  final VoidCallback onCall;
  final VoidCallback? onText;

  const _CrisisContactCard({
    required this.name,
    required this.number,
    required this.description,
    required this.type,
    required this.onCall,
    this.onText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              type == 'emergency'
                  ? LucideIcons.shieldAlert
                  : type == 'text'
                      ? LucideIcons.messageSquare
                      : LucideIcons.phone,
              color: AppColors.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: onCall,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    type == 'text' ? 'TEXT' : 'CALL',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (type == 'text') ...[
                const SizedBox(height: 4),
                Text(
                  number,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
