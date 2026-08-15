# 20. Theme Architecture

The Flutter application should use a centralized theme system.

All visual styling should be defined in one location.

Avoid defining colors, typography, spacing, or shapes directly inside widgets.

---

## Theme Responsibilities

The theme layer manages:

* Color palette
* Typography
* Component styles
* Elevation
* Border radius
* Spacing
* Light and Dark themes *(future)*

Widgets should consume the theme rather than defining their own appearance.

---

## Theme Structure

```text
core/
│
└── theme/
    ├── app_theme.dart
    ├── app_colors.dart
    ├── app_text_styles.dart
    ├── app_spacing.dart
    └── app_radius.dart
```

Theme configuration should remain independent from business features.

---

# 21. Localization

The Flutter Customer PWA should support localization from the beginning.

Flutter's official localization framework should be used.

---

## Responsibilities

Localization should support:

* Multiple languages
* Locale switching *(future)*
* Date formatting
* Number formatting
* Currency formatting

Business logic should never depend on localized strings.

---

## Localization Structure

```text
l10n/
│
├── app_en.arb
├── app_vi.arb
└── generated/
```

Displayed text should always originate from localization resources.

Hardcoded UI strings should be avoided.

---

# 22. Application Lifecycle

The Flutter application follows a predictable lifecycle.

```text
Application Start
        │
        ▼
Initialize Firebase
        │
        ▼
Register Dependencies
        │
        ▼
Initialize Routing
        │
        ▼
Launch Application
        │
        ▼
Customer Interaction
```

Application initialization should remain lightweight.

Long-running operations should occur after startup.

---

# 23. Performance Guidelines

The Flutter application should prioritize responsiveness and efficient resource usage.

---

## Widget Construction

Widgets should:

* Prefer const constructors where applicable.
* Remain small and composable.
* Avoid deeply nested widget trees.
* Separate layout from business logic.

---

## State Management

Keep BLoC state focused.

Avoid placing unrelated business data inside a single BLoC.

Each BLoC should manage one business capability.

---

## Firestore

Applications should:

* Listen only to required documents.
* Dispose listeners promptly.
* Avoid duplicate queries.
* Cache stable data when appropriate.

---

## Images

Images should:

* Be optimized for the web.
* Load lazily where possible.
* Use appropriate resolutions.
* Display placeholders while loading.

---

# 24. Testing Strategy

Testing should exist at every architectural layer.

---

## Unit Tests

Verify:

* Use Cases
* Domain Entities
* Repository Contracts
* Business Rules

Unit tests should not depend on Flutter widgets.

---

## Repository Tests

Verify:

* Firestore integration
* DTO mapping
* Serialization
* Error translation

Firebase Emulator should be preferred for integration testing.

---

## BLoC Tests

Verify:

* Event handling
* State transitions
* Business workflows

Every public BLoC should have corresponding tests.

---

## Widget Tests

Verify:

* Rendering
* User interactions
* Navigation
* Error presentation

Widget tests should focus on behavior rather than implementation details.

---

# 25. Flutter Checklist

Every new Feature should satisfy the following checklist.

| Requirement | Required |
|------------|----------|
| Feature-first organization | ✓ |
| Clean Architecture | ✓ |
| BLoC implementation | ✓ |
| Dependency injection | ✓ |
| Repository pattern | ✓ |
| DTO mapping | ✓ |
| Localization | ✓ |
| Theme integration | ✓ |
| Unit tests | ✓ |
| Widget tests | ✓ |

Features should satisfy this checklist before being merged into the main branch.

---

# 26. Guiding Principle

The Flutter Customer PWA exists to provide a fast, intuitive, and reliable ordering experience.

The application should remain:

* Modular
* Testable
* Predictable
* Maintainable
* Business-driven

Flutter is an implementation technology.

The business domain remains the foundation of every feature.
