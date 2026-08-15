# 11. Flutter Architecture

The Flutter Customer PWA follows Clean Architecture with Feature-First organization.

Flutter is responsible for:

* Customer user interface
* Local state management
* Navigation
* Firestore interaction through repositories

Business rules remain inside the Domain layer.

---

## State Management

Flutter uses **flutter_bloc** as the primary state management solution.

BLoC provides:

* Predictable state transitions
* Testable business logic
* Clear separation between UI and application state
* Event-driven architecture

Each feature owns its own BLoC instances.

Global application state should be minimized.

---

## Routing

Flutter uses **go_router**.

Responsibilities include:

* QR route parsing
* Deep linking
* Nested navigation
* Route guards *(future)*

Routing should remain independent from business logic.

---

## Dependency Injection

Flutter uses **get_it**.

Dependency injection is responsible for:

* Repository registration
* Use Case registration
* Service registration
* BLoC construction

Dependencies should be registered during application startup.

Features should request dependencies through injection rather than creating them directly.

---

## Feature Example

```text
menu/
│
├── presentation/
│   ├── bloc/
│   ├── pages/
│   └── widgets/
│
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
│
├── data/
│   ├── datasources/
│   ├── dto/
│   ├── mappers/
│   └── repositories/
│
└── shared/
```

---

# 12. Angular Architecture

The Angular Administration Dashboard follows the same architectural principles as Flutter.

Technology differences should not introduce architectural differences.

---

## Component Architecture

Angular uses:

* Standalone Components
* Standalone Routing
* Lazy-loaded Features

Features should remain isolated whenever possible.

---

## State Management

Angular uses **Signals** for local application state.

Signals provide:

* Fine-grained reactivity
* Predictable updates
* Reduced boilerplate
* Excellent Angular integration

Signals should represent application state.

Business rules should remain in the Domain layer.

---

## RxJS Usage

RxJS remains responsible for:

* Firestore streams
* Asynchronous workflows
* External event handling

Signals and RxJS should complement each other.

Signals represent state.

RxJS represents asynchronous data streams.

---

## Dependency Injection

Angular uses the built-in Dependency Injection framework.

Responsibilities include:

* Repository injection
* Service injection
* Use Case injection

Dependency injection should occur through constructors.

---

## Feature Example

```text
menu/
│
├── presentation/
│   ├── pages/
│   ├── components/
│   └── state/
│
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
│
├── data/
│   ├── datasources/
│   ├── dto/
│   ├── mappers/
│   └── repositories/
│
└── shared/
```

---

# 13. Repository Pattern

Repositories isolate business logic from infrastructure.

The Domain layer depends only on repository contracts.

The Data layer provides concrete implementations.

```text
Presentation
        │
        ▼
Use Case
        │
        ▼
Repository Interface
        │
        ▼
Firestore Repository
        │
        ▼
Cloud Firestore
```

Repositories should expose business-oriented operations.

Examples:

* getActiveMenu()
* getCustomerOrders()
* submitOrder()
* updateCart()

Repositories should never expose raw Firestore implementation details.

---

# 14. Data Mapping

Data Transfer Objects (DTOs) represent Firestore documents.

Entities represent business concepts.

Mappers convert between them.

```text
Firestore
      │
      ▼
DTO
      │
      ▼
Mapper
      │
      ▼
Domain Entity
```

This separation prevents infrastructure concerns from leaking into business logic.

---

# 15. State Management Principles

State should remain:

* Predictable
* Observable
* Feature-scoped
* Easy to test

Business state should originate from Firestore.

UI state should remain local to the Presentation layer.

Examples of UI state include:

* Selected tab
* Dialog visibility
* Loading indicators
* Search filters

Business entities should not be duplicated across multiple state containers.

---

# 16. Navigation Principles

Navigation should follow business workflows.

Examples include:

Customer:

```text
QR Scan
    ↓
Menu
    ↓
Cart
    ↓
Order Tracking
```

Restaurant Staff:

```text
Dashboard
    ↓
Kitchen
    ↓
Orders
    ↓
Tables
```

Navigation should never replace business state.

Business state belongs in the Domain layer.