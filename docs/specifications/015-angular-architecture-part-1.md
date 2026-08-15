# ScanServe Angular Architecture

**Version:** 1.0
**Status:** Draft
**Last Updated:** July 2026

---

# 1. Purpose

This document defines the architecture of the ScanServe Angular Administration Dashboard.

It establishes the implementation standards, project structure, and architectural patterns used throughout the Angular application.

The objectives are to:

* Maintain a scalable Angular codebase.
* Enforce Clean Architecture.
* Organize code by business features.
* Improve maintainability and testability.
* Keep business logic independent from Angular.

This document serves as the implementation blueprint for the Administration Dashboard.

---

# 2. Scope

This document defines:

* Project structure
* Feature organization
* Clean Architecture
* Signals architecture
* RxJS usage
* Dependency Injection
* Routing
* Repository implementation
* DTO mapping
* State management
* Theme architecture
* Testing strategy

This document intentionally excludes:

* Firestore schema
* Security Rules
* Cloud Functions
* Flutter architecture

---

# 3. Technology Stack

| Technology | Purpose |
|------------|---------|
| Angular | Frontend Framework |
| TypeScript | Programming Language |
| Angular Signals | State Management |
| RxJS | Reactive Streams |
| Angular Router | Routing |
| Angular Dependency Injection | Dependency Management |
| Cloud Firestore | Database |
| Firebase Authentication | Staff Authentication |

---

# 4. Architectural Principles

The Angular application follows the architectural principles defined in:

* 001 System Overview
* 002 Domain Model
* 009 Client Architecture

Angular should remain an implementation technology.

Business logic belongs to the Domain layer.

---

## 4.1 Feature First

Applications are organized by business capability.

Examples:

* Kitchen
* Orders
* Menu
* Tables
* Staff
* Settings

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

Angular Components should never communicate directly with Firestore.

---

## 4.3 Predictable State

Business state should remain independent from UI state.

Signals represent application state.

RxJS represents asynchronous data streams.

---

## 4.4 Testability

Business logic should be testable without Angular.

Presentation should remain thin.

---

# 5. Project Structure

Recommended project structure:

```text
src/
│
├── app/
│
├── core/
│
├── features/
│
├── shared/
│
├── assets/
│
└── environments/
```

Each directory has a clearly defined responsibility.

---

# 6. Core Layer

The Core layer contains shared infrastructure.

Examples:

* Routing
* Dependency Injection
* Guards
* Interceptors
* Theme
* Utilities
* Error Handling

Business logic should not exist in the Core layer.

---

# 7. Shared Layer

The Shared layer contains reusable UI components.

Examples:

* Buttons
* Dialogs
* Tables
* Form Controls
* Loading Indicators
* Layout Components

Shared components should remain business-independent.

---

# 8. Feature Organization

Every business capability becomes a Feature.

Examples:

```text
features/
│
├── dashboard/
├── kitchen/
├── orders/
├── menu/
├── tables/
├── staff/
└── settings/
```

Each Feature should remain independently maintainable.

---

# 9. Feature Structure

Every Feature follows the same internal organization.

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
* Components
* Signals
* Route Configuration

Presentation is responsible for:

* Rendering UI
* User interaction
* Navigation
* Local UI state

Business rules belong to the Domain layer.