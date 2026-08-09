---
name: flutter-scaffold
description: Analyze Flutter project structure and scaffold essential base files (app_colors, app_strings, app_style, app_images, routing, etc.) following Clean Architecture with BLoC/Cubit. Use when creating a new Flutter feature, setting up a Flutter project, or bootstrapping base files.
---

# Flutter Project Scaffold Skill

> **Trigger keywords:** `flutter scaffold`, `flutter setup`, `flutter structure`, `new flutter feature`, `flutter base files`, `flutter clean architecture`, `flutter project init`

## Overview

This skill analyzes and scaffolds production-grade Flutter projects using **Clean Architecture** with the **BLoC/Cubit** state management pattern. It generates all essential base files, enforces consistent folder naming, and ensures separation of concerns across every layer.

---

## Architecture Pattern: Feature-First Clean Architecture

```
lib/
├── core/                          # Shared utilities across all features
│   ├── constants/                 # App-wide constant values
│   │   ├── app_colors.dart        # All color definitions (static const Color)
│   │   ├── app_strings.dart       # All hardcoded strings grouped by feature
│   │   ├── app_style.dart         # Reusable TextStyle definitions
│   │   ├── app_images.dart        # Asset image path constants
│   │   ├── api_constants.dart     # API URLs, table names, keys
│   │   └── app_consts.dart        # General constants (paddings, durations, etc.)
│   ├── networking/                # API client setup (Dio, Supabase, etc.)
│   │   └── supabase_service.dart  # Service initialization & singleton
│   ├── routing/                   # Navigation management
│   │   ├── routes.dart            # Route name constants
│   │   └── app_router.dart        # Route generator (onGenerateRoute)
│   ├── shared_pref/               # Local storage helpers
│   │   └── shared_pref_helper.dart
│   ├── theme/                     # ThemeData & dark/light mode
│   │   └── app_theme.dart
│   └── widgets/                   # Reusable widgets used across features
│       ├── custom_course_card.dart
│       └── simple_observer.dart   # BLoC observer for debugging
├── features/                      # Feature modules (each self-contained)
│   └── <feature_name>/
│       ├── data/                  # Data layer
│       │   ├── models/            # Data models / DTOs
│       │   │   └── <name>_model.dart
│       │   └── repo/              # Repository implementations
│       │       └── <name>_repo.dart
│       └── presentation/          # UI layer
│           ├── cubit/             # State management
│           │   ├── <name>_cubit.dart
│           │   └── <name>_states.dart
│           └── screens/           # Screen widgets
│               ├── <name>_screen.dart
│               └── widgets/       # Screen-specific widgets
│                   └── <widget_name>.dart
└── main.dart                      # App entry point
```

---

## Essential Base Files — What to Generate

When scaffolding a new Flutter project or feature, **ALWAYS** create these files. Below is the purpose, rules, and template for each.

> [!IMPORTANT]
> **NEVER pre-fill values from your imagination.** All templates below are **empty scaffolds with section comments only**. When generating these files:
> - Analyze the actual project codebase to extract real colors, strings, styles, and assets
> - If it's a brand-new project with no existing code, create only the class structure with empty section comments
> - The developer will fill in the actual values based on their design system

### 1. `lib/core/constants/app_colors.dart`

**Purpose:** Centralize ALL color values. Never use raw `Color(0xff...)` inline.

**Rules:**
- Use `static const Color` for every color
- Name semantically: `primaryColor`, `scaffoldBackground`, `textDark`, `textMuted`
- Group by purpose with comments: primary, text, status, UI elements

```dart
import 'package:flutter/material.dart';

class AppColors {
  // ── Primary ──

  // ── Text ──

  // ── Buttons ──

  // ── Status ──

  // ── UI Elements ──

}
```

---

### 2. `lib/core/constants/app_strings.dart`

**Purpose:** Centralize ALL user-facing strings. Never hardcode text in widgets.

**Rules:**
- Use `static const String` or `static const`
- Group by feature/screen with section comments
- If the app supports Arabic (RTL), consider a localization approach or keep strings here as defaults

```dart
class AppStrings {
  // ── Auth ──

  // ── Home ──

  // ── Profile ──

  // ── General ──

}
```

---

### 3. `lib/core/constants/app_style.dart`

**Purpose:** Centralize ALL `TextStyle` definitions with consistent naming.

**Rules:**
- Naming convention: `{weight}{size}` → `bold32`, `medium16`, `regular14`
- Reference `AppColors` for text colors
- Weights: `regular` (w400), `medium` (w500), `semiBold` (w600), `bold` (w700)

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppStyle {
  // ── Bold ── (w700)

  // ── SemiBold ── (w600)

  // ── Medium ── (w500)

  // ── Regular ── (w400)

}
```

---

### 4. `lib/core/constants/app_images.dart`

**Purpose:** Centralize ALL asset image paths.

**Rules:**
- All paths must match entries in `pubspec.yaml` under `flutter > assets`
- Use descriptive names: `welcomeImage`, `googleLogo`, not `img1`

```dart
class AppImages {
  static const String basePath = "assets/images/";

  // ── Images ──

  // ── Icons ──

  // ── Logos ──

}
```

---

### 5. `lib/core/constants/api_constants.dart`

**Purpose:** Store API base URLs, table names, and public keys.

**Rules:**
- **NEVER** store secret keys here — use `.env` or `--dart-define`
- Group by service/resource

```dart
class ApiConstants {
  // ── Base URL ──

  // ── Table Names ──

  // ── OAuth / Keys ──

}
```

---

### 6. `lib/core/constants/app_consts.dart`

**Purpose:** General non-color, non-string constants (paddings, durations, sizes).

```dart
class AppConsts {
  // ── Spacing ──

  // ── Border Radius ──

  // ── Animation Durations ──

  // ── Limits ──

}
```

---

### 7. `lib/core/routing/routes.dart`

**Purpose:** Define route name constants referenced in both `AppRouter` and navigation calls.

```dart
class Routes {
  // Add route name constants as features grow
  // Example: static const String login = "LoginScreen";
}
```

---

### 8. `lib/core/routing/app_router.dart`

**Purpose:** Centralized route generation using `onGenerateRoute`.

**Rules:**
- Each route case returns `MaterialPageRoute`
- Extract arguments with `settings.arguments as YourArgsClass`
- Always have a `default` fallback

```dart
import 'package:flutter/material.dart';
import 'routes.dart';
// import screens as you add features...

class AppRouter {
  Route generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Add cases here as features grow
      // case Routes.login:
      //   return MaterialPageRoute(builder: (_) => const LoginScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text("No Route Found")),
          ),
        );
    }
  }
}
```

---

### 9. `lib/core/widgets/simple_observer.dart`

**Purpose:** BLoC observer for debugging state transitions in development.

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

class SimpleObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    debugPrint('${bloc.runtimeType} $change');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    debugPrint('${bloc.runtimeType} $error $stackTrace');
  }
}
```

---

### 10. `lib/main.dart`

**Purpose:** App entry point — initialize services, set BLoC observer, run app.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/networking/supabase_service.dart';
import 'core/routing/app_router.dart';
import 'core/routing/routes.dart';
import 'core/widgets/simple_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  Bloc.observer = SimpleObserver();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRouter().generateRoute,
      initialRoute: Routes.login,
    );
  }
}
```

---

## Scaffolding a New Feature

When the user asks to **add a new feature**, create this exact structure:

```
lib/features/<feature_name>/
├── data/
│   ├── models/
│   │   └── <feature>_model.dart     # Data model with fromJson/toJson
│   └── repo/
│       └── <feature>_repo.dart      # Repository (API calls)
└── presentation/
    ├── cubit/
    │   ├── <feature>_cubit.dart      # Cubit with emit() logic
    │   └── <feature>_states.dart     # Sealed/abstract state classes
    └── screens/
        ├── <feature>_screen.dart     # Main screen widget
        └── widgets/
            └── <widget>.dart         # Extracted child widgets
```

### Feature Checklist

When scaffolding a new feature, **always** do the following:

1. **Create the folder structure** above under `lib/features/<name>/`
2. **Add the model** with `fromJson()` and `toJson()` methods
3. **Add the repository** that fetches data from the API
4. **Create states file** with `Initial`, `Loading`, `Success<T>`, `Error` states
5. **Create cubit** that calls the repository and emits states
6. **Create the screen** using `BlocProvider` + `BlocBuilder`
7. **Extract sub-widgets** into `screens/widgets/` to keep screens under ~150 lines
8. **Add route** to `routes.dart` and `app_router.dart`
9. **Add strings** to `app_strings.dart` under a new section comment
10. **Add any new colors** to `app_colors.dart`
11. **Add any new styles** to `app_style.dart`
12. **Update `pubspec.yaml`** if new assets are referenced

---

## Cubit States Pattern

Always follow this pattern for states:

```dart
abstract class FeatureStates {}

class FeatureInitial extends FeatureStates {}

class FeatureLoading extends FeatureStates {}

class FeatureSuccess<T> extends FeatureStates {
  final T data;
  FeatureSuccess(this.data);
}

class FeatureError extends FeatureStates {
  final String message;
  FeatureError(this.message);
}
```

---

## Naming Conventions

| Item                | Convention                  | Example                        |
|---------------------|-----------------------------|--------------------------------|
| Feature folder      | `snake_case`                | `course_details/`              |
| Dart files          | `snake_case.dart`           | `home_cubit.dart`              |
| Classes             | `PascalCase`                | `HomeScreen`, `HomeCubit`      |
| Constants           | `camelCase`                 | `primaryColor`, `signIn`       |
| State classes       | `Feature` + `State`         | `HomeLoading`, `HomeSuccess`   |
| Cubit classes       | `Feature` + `Cubit`         | `HomeCubit`, `ProfileCubit`    |
| Model classes       | `Feature` + `Model`         | `CourseModel`, `UserModel`     |
| Repo classes        | `Feature` + `Repo`          | `HomeRepo`, `AuthRepo`        |
| Route constants     | Screen name string          | `"HomeScreen"`                 |
| Image constants     | `camelCase` descriptive     | `welcomeImage`, `googleLogo`   |
| Arguments classes   | `Feature` + `Args`          | `PaymentArgs`, `CourseArgs`    |

---

## Anti-Patterns to Avoid

> [!CAUTION]
> **Never do these:**

- ❌ Hardcode colors inline: `Color(0xff137FEC)` → Use `AppColors.primaryColor`
- ❌ Hardcode strings inline: `"Sign In"` → Use `AppStrings.signIn`
- ❌ Hardcode TextStyles inline → Use `AppStyle.bold16`
- ❌ Hardcode asset paths inline → Use `AppImages.welcomeImage`
- ❌ Put business logic in widgets → Move to Cubit
- ❌ Use `setState()` for complex state → Use `BlocBuilder`
- ❌ Put API calls directly in screens → Use Repo layer
- ❌ Create massive screen widgets (>200 lines) → Extract into `widgets/`
- ❌ Store secrets in Dart files → Use `--dart-define` or `.env` files

---

## Common Dependencies (Examples — Not Required)

These are **common packages** you may consider depending on the project needs. Pick only what applies — do NOT add all of them blindly:

| Package | Purpose | When to add |
|---------|---------|-------------|
| `flutter_bloc` | State management (Cubit/BLoC) | If using BLoC pattern |
| `dio` | HTTP client | If making REST API calls (not needed with Supabase) |
| `supabase_flutter` | Backend as a Service | If using Supabase |
| `dartz` | Functional programming (Either type) | If using Either for error handling |
| `shared_preferences` | Local key-value storage | If caching data locally |
| `google_sign_in` | Google OAuth | If adding Google login |
| `cupertino_icons` | iOS-style icons | Usually included by default |

> [!NOTE]
> Always check `pubspec.yaml` in the existing project first. Do NOT assume which packages to install — ask the developer or read the project requirements.

---

## Quick Start Commands (Reference)

```bash
# Create new Flutter project
flutter create --org com.yourname my_app

# Add dependencies as needed (example — pick what you need)
cd my_app
flutter pub add flutter_bloc

# Generate folders (run from project root)
mkdir -p lib/core/constants lib/core/networking lib/core/routing lib/core/shared_pref lib/core/theme lib/core/widgets
mkdir -p lib/features
mkdir -p assets/images assets/icons assets/fonts
```

---

## When to Use This Skill

| Scenario                                     | Action                                    |
|----------------------------------------------|-------------------------------------------|
| User says "create new Flutter project"       | Scaffold entire `lib/` structure + all base files |
| User says "add new feature"                  | Scaffold feature folder + update routing/strings  |
| User says "flutter setup" or "init"          | Generate core files only                  |
| User mentions `app_colors`, `app_strings`    | Generate/update the specific constants file|
| User wants to refactor hardcoded values      | Move inline values → constants files      |
| User asks about Flutter architecture         | Explain this clean arch + BLoC pattern    |
