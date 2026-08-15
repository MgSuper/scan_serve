# ScanServe Flutter Architecture

**Version:** 1.0
**Status:** Draft
**Last Updated:** July 2026

---

# 1. Purpose

This document defines the architecture of the ScanServe Flutter Customer PWA.

It establishes the implementation standards, project structure, and architectural patterns used throughout the Flutter application.

The objectives are to:

* Maintain a scalable Flutter codebase.
* Enforce Clean Architecture.
* Organize code by business features.
* Improve maintainability and testability.
* Keep business logic independent from Flutter.

This document serves as the implementation blueprint for the Flutter Customer PWA.

---

# 2. Scope

This document defines:

* Project structure
* Feature organization
* Clean Architecture
* BLoC architecture
* Dependency Injection
* Routing
* Repository implementation
* DTO mapping
* State management
* Theme architecture
* Localization
* Testing strategy

This document intentionally excludes:

* Firestore schema
* Security Rules
* Cloud Functions
* Angular architecture

---

# 3. Technology Stack

| Technology | Purpose |
|------------|---------|
| Flutter | UI Framework |
| Dart | Programming Language |
| flutter_bloc | State Management |
| go_router | Routing |
| get_it | Dependency Injection |
| Firebase Auth | Authentication *(future)* |
| Cloud Firestore | Database |
| Firebase Hosting | Web Hosting |

---

# 4. Architectural Principles

The Flutter application follows the architectural principles defined in:

* 001 System Overview
* 002 Domain Model
* 009 Client Architecture

Flutter should remain an implementation technology.

Business logic belongs to the Domain layer.

---

## 4.1 Feature First

Features own their entire implementation.

Avoid organizing the application by technical layers.

---

## 4.2 Clean Architecture

Dependencies always point inward.

```text
Presentation
      │
      ▼
Domain
      │
      ▼
Data
```

Flutter widgets must never communicate directly with Firestore.

---

## 4.3 Predictable State

Every feature owns its own state.

Business state should remain independent from UI state.

---

## 4.4 Testability

Business logic should be testable without Flutter.

Presentation should remain thin.

---

# 5. Project Structure

Recommended project structure:

```text
lib/
│
├── app/
│
├── core/
│
├── features/
│
├── shared/
│
├── l10n/
│
└── main.dart
```

Each directory has a clearly defined responsibility.

---

# 6. Core Layer

The Core layer contains shared infrastructure.

Examples:

* Routing
* Dependency Injection
* Theme
* Constants
* Utilities
* Error Handling
* Extensions

Business logic should not exist in the Core layer.

---

# 7. Shared Layer

The Shared layer contains reusable presentation components.

Examples:

* Buttons
* Dialogs
* Form widgets
* Loading indicators
* Empty states

Shared widgets should remain business-independent.

---

# 8. Feature Organization

Every business capability becomes a Feature.

Examples:

```text
features/
│
├── menu/
├── ordering/
├── cart/
├── session/
├── tracking/
└── waiter/
```

Each Feature should remain independently maintainable.

---

# 9. Feature Structure

Every Feature follows the same internal structure.

```text
feature/
│
├── presentation/
│
├── domain/
│
├── data/
│
└── shared/
```

Feature consistency is more important than personal preference.

---

# 10. Presentation Layer

The Presentation layer contains:

* Pages
* Widgets
* BLoCs
* Events
* States

Presentation is responsible for:

* Rendering UI
* User interaction
* Navigation
* Local UI state

Business rules belong to the Domain layer.