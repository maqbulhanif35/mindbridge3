import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// Centralized icon registry for MindBridge.
/// All icons must be referenced from here — never use icon constants directly in widgets.
/// Switching icon packs only requires updating this file.
abstract class AppIcons {
  // ─── Navigation ───────────────────────────────────────
  static const IconData home = LucideIcons.house;
  static const IconData chat = LucideIcons.messageCircle;
  static const IconData mood = LucideIcons.smile;
  static const IconData journal = LucideIcons.bookOpen;
  static const IconData explore = LucideIcons.compass;
  static const IconData profile = LucideIcons.user;

  // ─── Actions ──────────────────────────────────────────
  static const IconData add = LucideIcons.plus;
  static const IconData addCircle = LucideIcons.circlePlus;
  static const IconData edit = LucideIcons.pencil;
  static const IconData delete = LucideIcons.trash2;
  static const IconData send = LucideIcons.send;
  static const IconData search = LucideIcons.search;
  static const IconData filter = LucideIcons.slidersHorizontal;
  static const IconData share = LucideIcons.share2;
  static const IconData save = LucideIcons.bookmark;
  static const IconData copy = LucideIcons.copy;
  static const IconData close = LucideIcons.x;
  static const IconData back = LucideIcons.arrowLeft;
  static const IconData forward = LucideIcons.arrowRight;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData chevronUp = LucideIcons.chevronUp;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData more = LucideIcons.ellipsisVertical;
  static const IconData refresh = LucideIcons.refreshCcw;
  static const IconData check = LucideIcons.check;
  static const IconData checkCircle = LucideIcons.circleCheck;
  static const IconData settings = LucideIcons.settings;

  // ─── Wellness / Mental Health ──────────────────────────
  static const IconData brain = LucideIcons.brain;
  static const IconData heart = LucideIcons.heart;
  static const IconData heartPulse = LucideIcons.heartPulse;
  static const IconData mindfulness = LucideIcons.sparkles;
  static const IconData breathing = LucideIcons.wind;
  static const IconData wellness = LucideIcons.activity;
  static const IconData calm = LucideIcons.waves;
  static const IconData energy = LucideIcons.zap;
  static const IconData sleep = LucideIcons.moon;
  static const IconData sunlight = LucideIcons.sun;
  static const IconData nature = LucideIcons.leaf;

  // ─── Mood & Emotions ──────────────────────────────────
  static const IconData smileHappy = LucideIcons.smile;
  static const IconData smileSad = LucideIcons.frown;
  static const IconData smileNeutral = LucideIcons.meh;
  static const IconData moodTracker = LucideIcons.gauge;
  static const IconData emotionTag = LucideIcons.tag;

  // ─── Analytics & Stats ────────────────────────────────
  static const IconData chart = LucideIcons.chartBar;
  static const IconData chartLine = LucideIcons.trendingUp;
  static const IconData chartLineDown = LucideIcons.trendingDown;
  static const IconData analytics = LucideIcons.chartPie;
  static const IconData stats = LucideIcons.layoutDashboard;
  static const IconData insights = LucideIcons.lightbulb;
  static const IconData trend = LucideIcons.activity;

  // ─── Gamification ─────────────────────────────────────
  static const IconData streak = LucideIcons.flame;
  static const IconData badge = LucideIcons.award;
  static const IconData trophy = LucideIcons.trophy;
  static const IconData star = LucideIcons.star;
  static const IconData medal = LucideIcons.medal;
  static const IconData challenge = LucideIcons.target;
  static const IconData xp = LucideIcons.zap;
  static const IconData milestone = LucideIcons.flag;
  static const IconData lock = LucideIcons.lock;
  static const IconData unlock = LucideIcons.lockOpen;

  // ─── Notifications & Alerts ───────────────────────────
  static const IconData notification = LucideIcons.bell;
  static const IconData notificationOff = LucideIcons.bellOff;
  static const IconData alert = LucideIcons.circleAlert;
  static const IconData alertTriangle = LucideIcons.triangleAlert;
  static const IconData info = LucideIcons.info;
  static const IconData success = LucideIcons.circleCheck;
  static const IconData crisis = LucideIcons.shieldAlert;
  static const IconData sos = LucideIcons.phoneCall;

  // ─── Community ────────────────────────────────────────
  static const IconData community = LucideIcons.users;
  static const IconData people = LucideIcons.user;
  static const IconData message = LucideIcons.messageSquare;
  static const IconData online = LucideIcons.radio;

  // ─── Journal ──────────────────────────────────────────
  static const IconData write = LucideIcons.penLine;
  static const IconData tag = LucideIcons.tag;
  static const IconData privateIcon = LucideIcons.eyeOff;
  static const IconData visible = LucideIcons.eye;
  static const IconData aiInsight = LucideIcons.sparkles;
  static const IconData quote = LucideIcons.quote;

  // ─── Profile & Account ────────────────────────────────
  static const IconData avatar = LucideIcons.circleUser;
  static const IconData university = LucideIcons.graduationCap;
  static const IconData goal = LucideIcons.target;
  static const IconData password = LucideIcons.keyRound;
  static const IconData logout = LucideIcons.logOut;
  static const IconData darkMode = LucideIcons.moon;
  static const IconData lightMode = LucideIcons.sun;
  static const IconData palette = LucideIcons.palette;
  static const IconData language = LucideIcons.globe;
  static const IconData privacy = LucideIcons.shieldCheck;

  // ─── Resources ────────────────────────────────────────
  static const IconData resource = LucideIcons.bookMarked;
  static const IconData article = LucideIcons.newspaper;
  static const IconData video = LucideIcons.circlePlay;
  static const IconData exercise = LucideIcons.dumbbell;
  static const IconData phone = LucideIcons.phone;
  static const IconData emergency = LucideIcons.phoneCall;
  static const IconData mapPin = LucideIcons.mapPin;
  static const IconData website = LucideIcons.externalLink;

  // ─── Time & Calendar ──────────────────────────────────
  static const IconData calendar = LucideIcons.calendarDays;
  static const IconData clock = LucideIcons.clock;
  static const IconData today = LucideIcons.calendarCheck;
  static const IconData history = LucideIcons.history;

  // ─── Connectivity ─────────────────────────────────────
  static const IconData wifi = LucideIcons.wifi;
  static const IconData wifiOff = LucideIcons.wifiOff;
  static const IconData sync = LucideIcons.refreshCw;
  static const IconData cloud = LucideIcons.cloud;
  static const IconData cloudSync = LucideIcons.cloudUpload;

  // ─── Maya (AI) ────────────────────────────────────────
  static const IconData aiAvatar = LucideIcons.bot;
  static const IconData aiTyping = LucideIcons.ellipsis;
  static const IconData aiSuggestion = LucideIcons.wand;
  static const IconData newChat = LucideIcons.squarePen;
  static const IconData chatHistory = LucideIcons.messageSquareMore;
}

/// Extension to build icon widgets with common presets.
extension AppIconWidget on IconData {
  Widget widget({
    double size = 24,
    Color? color,
    String? semanticLabel,
  }) =>
      Icon(
        this,
        size: size,
        color: color,
        semanticLabel: semanticLabel,
      );
}
