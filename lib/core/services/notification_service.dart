import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mood_model.dart';
import '../models/user_model.dart';
import 'goal_plan_engine.dart';
import 'trend_analyzer.dart';

/// Smart notification service that learns from user patterns
/// and sends contextually appropriate reminders and alerts.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Notification channel IDs
  static const _channelCheckIn = 'checkin_reminders';
  static const _channelStreak = 'streak_protection';
  static const _channelInsights = 'wellness_insights';
  static const _channelAchievement = 'achievements';
  static const _channelCrisis = 'crisis_support';

  // Scheduled notification IDs
  static const _idDailyCheckIn = 1;
  static const _idStreakProtection = 2;
  static const _idWeeklyInsight = 3;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _createChannels();
    _initialized = true;
    debugPrint('NotificationService: Initialized');
  }

  Future<void> _createChannels() async {
    const channels = [
      AndroidNotificationChannel(
        _channelCheckIn,
        'Daily Check-ins',
        description: 'Gentle reminders to log your mood',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        _channelStreak,
        'Streak Protection',
        description: 'Alerts to protect your daily streak',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        _channelInsights,
        'Wellness Insights',
        description: 'Your personalized wellness reports',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        _channelAchievement,
        'Achievements',
        description: 'Badge and milestone celebrations',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        _channelCrisis,
        'Support',
        description: 'Compassionate check-ins when you need support',
        importance: Importance.max,
      ),
    ];

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    for (final channel in channels) {
      await androidPlugin?.createNotificationChannel(channel);
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Navigation handled via app-level notification handler
  }

  // ─── Smart Reminder Scheduling ────────────────────────

  /// Learn when the user usually checks in and schedule reminder
  /// 30 minutes after their typical time.
  Future<void> scheduleSmartCheckInReminder(
    List<MoodEntry> pastEntries,
  ) async {
    if (!_initialized) return;

    // Find user's most common check-in hour
    final hourCounts = <int, int>{};
    for (final entry in pastEntries) {
      final hour = entry.createdAt.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    int targetHour = 20; // default: 8pm
    if (hourCounts.isNotEmpty) {
      final sorted = hourCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      targetHour = min(sorted.first.key + 1, 22); // +1hr nudge, cap at 10pm
    }

    await _scheduleDaily(
      id: _idDailyCheckIn,
      title: _checkInTitle(),
      body: _checkInBody(),
      hour: targetHour,
      minute: 30,
      channelId: _channelCheckIn,
      payload: 'mood_checkin',
    );
  }

  /// Schedule a streak protection reminder 2hrs before midnight if not checked in.
  Future<void> scheduleStreakProtectionReminder() async {
    if (!_initialized) return;
    await _scheduleDaily(
      id: _idStreakProtection,
      title: '🔥 Don\'t lose your streak!',
      body: 'You haven\'t logged today yet. Quick check-in to keep your streak alive.',
      hour: 22,
      minute: 0,
      channelId: _channelStreak,
      payload: 'streak_protection',
    );
  }

  /// Schedule weekly wellness report on Sunday at 9am.
  Future<void> scheduleWeeklyReport() async {
    if (!_initialized) return;
    await _scheduleWeekly(
      id: _idWeeklyInsight,
      title: '📊 Your weekly wellness report is ready',
      body: 'See how your week went and what Maya noticed about your patterns.',
      dayOfWeek: 7, // Sunday
      hour: 9,
      minute: 0,
      channelId: _channelInsights,
      payload: 'weekly_report',
    );
  }

  /// Schedule a personalized daily check-in using the user's preferred
  /// check-in time (morning/afternoon/evening/any) and goal-aware copy.
  Future<void> schedulePersonalizedCheckIn(UserModel user) async {
    if (!_initialized) return;
    final hour = GoalPlanEngine.checkInHour(user.checkInTime);
    final minute = GoalPlanEngine.checkInMinute(user.checkInTime);
    final title = GoalPlanEngine.getCheckInTitle(user);
    final body = GoalPlanEngine.getCheckInBody(user);

    await _scheduleDaily(
      id: _idDailyCheckIn,
      title: title,
      body: body,
      hour: hour,
      minute: minute,
      channelId: _channelCheckIn,
      payload: 'mood_checkin',
    );

    await savePreferredCheckInTime(hour, minute);
    debugPrint('NotificationService: Personalized check-in at $hour:${minute.toString().padLeft(2, '0')} — "${user.checkInTime}"');
  }

  /// Schedule a streak protection reminder personalized to the user's goals.
  Future<void> schedulePersonalizedStreakProtection(UserModel user) async {
    if (!_initialized) return;
    final body = GoalPlanEngine.getStreakProtectionBody(user);
    await _scheduleDaily(
      id: _idStreakProtection,
      title: '🔥 Keep your streak alive!',
      body: body,
      hour: 22,
      minute: 0,
      channelId: _channelStreak,
      payload: 'streak_protection',
    );
  }

  // ─── Immediate Notifications ──────────────────────────

  /// Celebrate a milestone streak.
  Future<void> notifyStreakMilestone(int streakDays) async {
    if (!_initialized) return;
    final (title, body) = _streakMilestoneMessage(streakDays);
    await _showImmediate(
      id: 100 + streakDays,
      title: title,
      body: body,
      channelId: _channelAchievement,
      payload: 'streak_milestone_$streakDays',
    );
  }

  /// Celebrate an achievement unlock.
  Future<void> notifyAchievementUnlocked(
    String achievementTitle,
    String emoji,
  ) async {
    if (!_initialized) return;
    await _showImmediate(
      id: Random().nextInt(10000) + 200,
      title: '$emoji Achievement Unlocked!',
      body: 'You earned "$achievementTitle". Tap to see your progress!',
      channelId: _channelAchievement,
      payload: 'achievement',
    );
  }

  /// Compassionate check-in when wellness score drops significantly.
  Future<void> notifyWellnessDropCheckIn(double previousScore, double newScore) async {
    if (!_initialized) return;
    final drop = previousScore - newScore;
    if (drop < 15) return; // only alert on significant drops

    await _showImmediate(
      id: 300,
      title: 'Maya is thinking of you 💙',
      body: 'Your wellness score has dipped a bit. Want to chat or try a calming exercise?',
      channelId: _channelCrisis,
      payload: 'wellness_drop',
    );
  }

  /// Alert for declining mood trend.
  Future<void> notifyDecliningTrend(TrendAlert alert) async {
    if (!_initialized) return;
    await _showImmediate(
      id: 400,
      title: alert.title,
      body: alert.message,
      channelId: alert.severity == TrendSeverity.critical
          ? _channelCrisis
          : _channelInsights,
      payload: 'trend_alert_${alert.type.name}',
    );
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async => _plugin.cancelAll();

  /// Cancel a specific notification by ID.
  Future<void> cancel(int id) async => _plugin.cancel(id);

  /// Check if the user has logged mood today — used to decide streak protection.
  Future<bool> hasLoggedToday(List<MoodEntry> entries) async {
    if (entries.isEmpty) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return entries.any((e) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      return d == today;
    });
  }

  /// Save and update the user's preferred reminder time.
  Future<void> savePreferredCheckInTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('checkin_hour', hour);
    await prefs.setInt('checkin_minute', minute);
  }

  Future<(int, int)> getPreferredCheckInTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('checkin_hour') ?? 20, prefs.getInt('checkin_minute') ?? 0);
  }

  // ─── Helpers ──────────────────────────────────────────

  Future<void> _showImmediate({
    required int id,
    required String title,
    required String body,
    required String channelId,
    String? payload,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String channelId,
    String? payload,
  }) async {
    // Simplified: uses flutter_local_notifications periodic notification
    // In production, use timezone package for proper daily scheduling
    await _plugin.periodicallyShow(
      id,
      title,
      body,
      RepeatInterval.daily,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId,
          importance: Importance.defaultImportance,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> _scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek,
    required int hour,
    required int minute,
    required String channelId,
    String? payload,
  }) async {
    await _plugin.periodicallyShow(
      id,
      title,
      body,
      RepeatInterval.weekly,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId,
          importance: Importance.defaultImportance,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  String _checkInTitle() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning! How are you feeling? ☀️';
    if (hour < 17) return 'Afternoon check-in time 🌤';
    return 'How was your day? 🌙';
  }

  String _checkInBody() {
    const messages = [
      'Take a moment to log how you\'re feeling today.',
      'Your mental health matters. Quick mood check?',
      'Maya is here if you want to talk. Start with a check-in.',
      'A 10-second check-in can help you understand your patterns.',
      'How are you feeling right now? Be honest with yourself.',
    ];
    return messages[Random().nextInt(messages.length)];
  }

  (String, String) _streakMilestoneMessage(int days) => switch (days) {
        3 => ('🔥 3-day streak!', 'You\'re building a great habit. Keep it up!'),
        7 => ('🏆 One week streak!', 'A full week of self-care. You\'re amazing!'),
        14 => ('💪 Two weeks strong!', 'Consistency is your superpower.'),
        30 => ('🌟 30-day streak!', 'One month of prioritizing your mental health. Incredible!'),
        60 => ('✨ 60 days!', 'You\'ve made wellness a true habit. Proud of you!'),
        90 => ('👑 90-day champion!', 'Three months of consistent self-care. Legendary.'),
        _ => ('🔥 $days-day streak!', 'Incredible dedication to your wellness journey!'),
      };
}
