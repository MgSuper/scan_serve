![CI](https://github.com/MgSuper/startup_launch/actions/workflows/flutter_elite_ci.yml/badge.svg)

# Startup Launch

Launch production-ready Flutter startups in minutes.

A powerful Flutter starter template built for speed, scalability, automation, and real product launches.

Use this repository as a GitHub Template to create new startup apps instantly.

---

# Why Startup Launch?

Most Flutter projects waste days rebuilding the same things:

- routing
- themes
- localization
- startup structure
- flavors
- CI/CD
- onboarding
- splash screen
- testing

Startup Launch solves it once — so you can focus on shipping products.

---

# ⚡ Core Features

## Architecture

- Clean scalable structure
- Feature-first architecture
- Dependency Injection (`get_it`)
- State Management (`flutter_bloc`)
- Navigation (`go_router`)
- Reusable core modules

## UI System

- Material 3
- Light / Dark / System theme
- Runtime theme switching
- Responsive-ready foundation

## Localization

- English 🇺🇸
- Vietnamese 🇻🇳
- Japanese 🇯🇵
- Thai 🇹🇭
- Runtime language switching
- Persistent selected language
- Onboarding language selector

## Launch Experience

- Native Splash Screen
- Dark mode splash support
- First-launch onboarding flow
- Skip onboarding after first run

## Networking

- `dio` API client
- Auth interceptor ready
- Connectivity guard ready
- Refresh token ready
- Error handling foundation

## Productivity

- Android flavors (`dev`, `staging`, `prod`)
- iOS schemes (`dev`, `staging`, `prod`)
- Environment banners
- Different app icons per flavor
- GitHub Template mode
- One-command startup generator

## Quality

- GitHub Actions CI/CD
- APK / AAB build artifacts
- Release automation
- Telegram notifications
- Static analysis
- Unit tests
- Widget tests
- Router tests
- Coverage-ready CI
- Strict lints

---

# Tech Stack

Flutter • Dart • flutter_bloc • get_it • go_router • dio • shared_preferences

---

# Quick Start

## Use as Template

Click **Use this template** on GitHub.

## One-command Startup Setup

```bash
sh scripts/create_startup.sh "My Startup" com.company.mystartup
flutter run --flavor dev -t lib/main_dev.dart
```

---

# Run Flavors

```bash
flutter run --flavor dev -t lib/main_dev.dart
flutter run --flavor staging -t lib/main_staging.dart
flutter run --flavor prod -t lib/main_prod.dart
```

---

# Generate Flavor Icons

```bash
dart run flutter_launcher_icons -f flutter_launcher_icons-dev.yaml
dart run flutter_launcher_icons -f flutter_launcher_icons-staging.yaml
dart run flutter_launcher_icons -f flutter_launcher_icons-prod.yaml
```

---

# Run Tests

```bash
flutter test
```

---

# Project Structure

```text
lib/
├── app/
├── core/
├── features/
│   ├── onboarding/
│   ├── home/
│   └── settings/
├── main_common.dart
├── main_dev.dart
├── main_staging.dart
└── main_prod.dart
```

---

# Built For

- startup MVPs
- SaaS mobile apps
- client projects
- rapid idea validation
- serious Flutter side projects

---

# Roadmap

- [ ] Firebase flavor setup
- [ ] Supabase starter option
- [ ] Fastlane deploy
- [ ] Crashlytics integration
- [ ] Analytics module

---

# License

MIT

---

# Support

If Startup Launch helps you, give it a star.
