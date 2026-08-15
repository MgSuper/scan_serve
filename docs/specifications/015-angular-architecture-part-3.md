# 21. Theme Architecture

The Administration Dashboard should use a centralized theme system.

All visual styling should be defined in one location.

Avoid defining colors, typography, spacing, or component styles directly inside individual components.

---

## Theme Responsibilities

The theme layer manages:

* Color palette
* Typography
* Component styles
* Icons
* Elevation
* Spacing
* Light and Dark themes *(future)*

Components should consume the theme rather than defining their own styles.

---

## Theme Structure

```text
core/
│
└── theme/
    ├── theme.ts
    ├── colors.ts
    ├── typography.ts
    ├── spacing.ts
    └── layout.ts
```

Theme configuration should remain independent from business features.

---

# 22. Application Layout

The Administration Dashboard should provide a consistent layout across all Features.

---

## Layout Responsibilities

The application layout manages:

* Navigation
* Header
* Sidebar
* Content Area
* Notifications
* Global Dialogs

Business Features should render inside the shared layout rather than creating independent page structures.

---

## Layout Structure

```text
App Shell
    │
    ├── Header
    ├── Sidebar
    ├── Content
    └── Global Overlay
```

A consistent layout improves usability and simplifies navigation.

---

# 23. Performance Guidelines

The Angular application should prioritize responsiveness and efficient resource usage.

---

## Components

Components should:

* Remain small and focused.
* Prefer standalone Components.
* Avoid unnecessary nesting.
* Delegate business logic to Use Cases.

---

## Signals

Signals should:

* Represent one business capability.
* Avoid duplicated state.
* Use computed values where appropriate.
* Minimize unnecessary updates.

---

## Firestore

Applications should:

* Subscribe only to required documents.
* Dispose subscriptions promptly.
* Avoid duplicate queries.
* Load configuration data on demand.

---

## Lazy Loading

Every major Feature should be lazy-loaded.

Examples:

* Kitchen
* Orders
* Menu
* Staff
* Settings

This reduces initial bundle size and improves application startup.

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

Unit tests should not depend on Angular Components.

---

## Repository Tests

Verify:

* Firestore integration.
* DTO mapping.
* Serialization.
* Error translation.

Firebase Emulator should be preferred for integration testing.

---

## Signal Store Tests

Verify:

* State updates.
* Computed values.
* Business workflows.
* Error handling.

Each Feature Store should have corresponding tests.

---

## Component Tests

Verify:

* Rendering.
* User interactions.
* Navigation.
* Error presentation.

Component tests should focus on user behavior rather than implementation details.

---

# 25. Angular Checklist

Every new Feature should satisfy the following checklist.

| Requirement | Required |
|------------|----------|
| Feature-first organization | ✓ |
| Clean Architecture | ✓ |
| Standalone Components | ✓ |
| Signals implementation | ✓ |
| Dependency injection | ✓ |
| Repository pattern | ✓ |
| DTO mapping | ✓ |
| Theme integration | ✓ |
| Unit tests | ✓ |
| Component tests | ✓ |

Features should satisfy this checklist before being merged into the main branch.

---

# 26. Guiding Principle

The Administration Dashboard exists to help restaurant staff operate efficiently.

The application should remain:

* Modular
* Testable
* Predictable
* Maintainable
* Business-driven

Angular is an implementation technology.

The business domain remains the foundation of every Feature.
