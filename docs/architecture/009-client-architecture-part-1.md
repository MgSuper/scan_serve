# ScanServe Client Architecture

**Version:** 1.0
**Status:** Draft
**Last Updated:** July 2026

---

# 1. Purpose

This document defines the client-side architecture of the ScanServe platform.

It establishes the architectural principles used by:

* Flutter Customer PWA
* Angular Administration Dashboard

The objectives are to:

* Maintain a consistent architecture across applications.
* Promote modularity and scalability.
* Reduce coupling.
* Improve maintainability.
* Support long-term feature growth.

This document focuses on application architecture rather than backend implementation.

---

# 2. Scope

This document defines:

* Application architecture
* Feature organization
* Clean Architecture
* State management
* Routing
* Dependency injection
* Repository pattern
* Shared application principles

This document intentionally excludes:

* UI design
* Firestore schemas
* Security Rules
* Cloud Functions

Those topics are defined in previous architecture documents.

---

# 3. Architectural Principles

Every client application should follow the same architectural principles.

---

## 3.1 Feature First

Applications are organized around business features rather than technical layers.

Examples:

* Authentication
* Menu
* Ordering
* Kitchen
* Tables

Each feature owns its presentation, domain, and data layers.

---

## 3.2 Clean Architecture

Business logic should remain independent of frameworks.

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

Frameworks should never dictate business logic.

---

## 3.3 Separation of Concerns

Each layer has one clear responsibility.

Presentation:

* UI
* State
* Navigation

Domain:

* Business rules
* Use Cases
* Entities

Data:

* Firestore
* Repositories
* DTOs
* Services

---

## 3.4 Dependency Inversion

Higher-level modules must not depend directly on infrastructure.

Communication occurs through interfaces.

Repositories abstract data sources from business logic.

---

## 3.5 Single Source of Truth

Every business entity should have one authoritative representation within the application.

Avoid duplicated business state across multiple features.

---

# 4. Application Overview

ScanServe consists of two primary client applications.

---

## Flutter Customer PWA

Responsibilities:

* QR code entry
* Menu browsing
* Cart management
* Ordering
* Order tracking

---

## Angular Dashboard

Responsibilities:

* Kitchen workflow
* Restaurant administration
* Table management
* Menu management
* Staff management

Both applications communicate exclusively through Firebase services.

---

# 5. Shared Layer Architecture

Every feature follows the same layered structure.

```text
Presentation
│
├── Pages
├── Widgets / Components
├── State
└── Routing

        │

Domain
│
├── Entities
├── Use Cases
├── Repository Contracts
└── Business Rules

        │

Data
│
├── Repository Implementations
├── Firestore Data Sources
├── DTOs
└── Mappers
```

Each layer has clearly defined responsibilities.

Dependencies should always point toward the Domain layer.

---

# 6. Feature Organization

Applications are organized by feature.

Example:

```text
features/
│
├── menu/
├── ordering/
├── tables/
├── kitchen/
├── staff/
├── settings/
└── authentication/
```

Each feature is independently maintainable.

Cross-feature dependencies should be minimized.

---

# 7. Feature Structure

Every feature follows a consistent internal structure.

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

Additional folders may be introduced only when justified by feature complexity.

---

# 8. Domain Layer

The Domain layer represents business logic.

It should contain:

* Entities
* Value Objects *(future)*
* Use Cases
* Repository Contracts

The Domain layer must not depend on:

* Flutter
* Angular
* Firebase
* Firestore

This ensures long-term maintainability.

---

# 9. Data Layer

The Data layer implements external communication.

Responsibilities include:

* Firestore access
* Repository implementations
* DTO mapping
* Cache management *(future)*

Business rules should remain outside the Data layer.

---

# 10. Presentation Layer

The Presentation layer is responsible for user interaction.

Responsibilities include:

* Rendering UI
* Managing application state
* Navigation
* Input validation
* User feedback

Business logic should be delegated to Use Cases.