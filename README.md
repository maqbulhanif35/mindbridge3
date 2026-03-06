# MindBridge — Student Mental Wellness Platform

> **"Your Bridge to Better Mental Health"**
> AI-powered mental wellness companion for university students.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile App | Flutter 3.27+ / Dart 3.5+ |
| State Management | Riverpod 2.5+ |
| Navigation | GoRouter 13+ |
| Backend | Dart Frog (Dart) |
| Database | PostgreSQL 16 |
| AI | Anthropic Claude claude-haiku-4-5-20251001 |
| Charts | fl_chart |
| Authentication | JWT + Refresh Tokens |

## Project Structure

```
mindbridge/
├── lib/                          # Flutter app
│   ├── main.dart                 # Entry point
│   ├── app.dart                  # App widget
│   ├── core/
│   │   ├── constants/            # Colors, strings
│   │   ├── theme/                # Material 3 theme
│   │   ├── router/               # GoRouter config
│   │   ├── models/               # Data models
│   │   ├── services/             # API & storage
│   │   └── providers/            # Riverpod state
│   ├── features/
│   │   ├── auth/                 # Splash, onboarding, login, register
│   │   ├── home/                 # Dashboard
│   │   ├── chat/                 # AI Chat (Maya)
│   │   ├── mood/                 # Mood tracker + analytics
│   │   ├── journal/              # Journal + AI insights
│   │   ├── mindfulness/          # Breathing + meditation
│   │   ├── resources/            # Resource library
│   │   ├── community/            # Anonymous peer support
│   │   ├── wellness/             # Challenges + gamification
│   │   ├── crisis/               # Crisis intervention
│   │   └── profile/              # Settings + profile
│   └── shared/
│       └── widgets/              # Reusable UI components
├── backend/                      # Dart Frog API server
│   ├── routes/                   # API endpoints
│   └── lib/                      # Services & middleware
└── database/
    └── schema.sql                # PostgreSQL schema + seed data
```

## Screens (15 Total)

1. **Splash** — Animated logo, auth check
2. **Onboarding** (3 screens) — Problem awareness, Maya intro, features
3. **Login** — Clean auth with gradient header
4. **Register** — 3-step wizard (info, school, goals)
5. **Home Dashboard** — Mood check-in, quick actions, trends
6. **Chat (Maya)** — AI chatbot with crisis detection
7. **Mood Tracker** — 4-step mood logging wizard
8. **Mood Analytics** — Charts, patterns, sleep correlation
9. **Journal** — Entry list with AI prompts
10. **Journal Entry** — Rich editor with AI insights
11. **Mindfulness** — Breathing, meditation, ambient sounds
12. **Breathing Exercise** — Animated circle, real-time countdown
13. **Resource Library** — Categorized mental health content
14. **Community** — Anonymous peer support posts
15. **Wellness Challenges** — Daily tasks + achievements
16. **Crisis Center** — Emergency contacts, safety planning
17. **Profile & Settings** — Full settings, logout

## Quick Start

### 1. Clone and Setup

```bash
# Install Flutter dependencies
flutter pub get

# Copy environment file
cp .env.example .env
# Edit .env with your API keys
```

### 2. Database Setup

```bash
# Create PostgreSQL database
createdb mindbridge

# Run schema
psql mindbridge < database/schema.sql
```

### 3. Backend Setup

```bash
cd backend
dart pub get
dart run main.dart
```

### 4. Run Flutter App

```bash
# Set your Anthropic API key as a build arg
flutter run --dart-define=ANTHROPIC_API_KEY=your-key-here
```

## Key Features

- **AI Chatbot Maya** — Claude-powered, CBT/DBT trained, crisis detection
- **Mood Intelligence** — 10-point scale, emotions, activities, sleep tracking
- **Beautiful Analytics** — Line charts, pie charts, scatter plots
- **Crisis Intervention** — Keyword detection → 988 hotline integration
- **Journal with AI** — Prompts, insights, mood correlation
- **Breathing Exercises** — Box breathing, 4-7-8, animated guide
- **Anonymous Community** — Safe peer support space
- **Gamification** — Streaks, challenges, achievement badges
- **Dark Mode** — Full Material 3 dark theme support

## Design System — "Serenity"

| Color | Hex | Usage |
|-------|-----|-------|
| Primary | #6C63FF | Main brand (violet) |
| Secondary | #4ECDC4 | Healing (teal-mint) |
| Tertiary | #FF6B9D | Warmth (rose) |
| Warning | #FFD166 | Alerts (amber) |
| Success | #06D6A0 | Positive (emerald) |
| Error | #FF6B6B | Crisis (coral) |

Font: **Nunito** (rounded, friendly, accessible)

## Crisis Protocol

```
User message analyzed → keyword detection
  ↓ No crisis keywords → normal response
  ↓ Crisis keywords detected
     → Crisis overlay appears
     → 988 hotline displayed
     → "Get Immediate Help" button
     → Crisis screen with safety planning
     → Crisis event logged (anonymized)
```

---

*Built with ❤️ for students who deserve better mental health support.*
