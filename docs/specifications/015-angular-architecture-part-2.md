# 11. Signals Architecture

The Angular Administration Dashboard uses **Angular Signals** as its primary state management solution.

Each Feature owns its own Signals.

Signals represent application state and expose immutable data to the Presentation layer.

---

## Responsibilities

Signals are responsible for:

* Holding application state.
* Coordinating UI updates.
* Exposing computed state.
* Managing loading state.
* Managing presentation-specific errors.

Signals should never communicate directly with Firestore.

---

## Signal Store Structure

```text
presentation/
│
├── state/
│   ├── menu.store.ts
│   ├── menu.state.ts
│   └── menu.actions.ts
│
├── pages/
│
└── components/
```

Each Feature should own its own state.

Global application state should remain minimal.

---

## State Guidelines

Signals should expose immutable state.

Typical state includes:

* Loading
* Loaded
* Empty
* Error

Computed values should derive from existing state rather than duplicating data.

---

# 12. RxJS Usage

RxJS remains responsible for asynchronous workflows.

Typical use cases include:

* Firestore listeners
* HTTP requests *(future)*
* Authentication streams
* Route parameter changes

Signals should consume the results produced by RxJS.

---

## Responsibilities

RxJS should handle:

* Observables
* Stream transformations
* Retry logic
* Debouncing
* Firestore subscriptions

Signals should represent the final application state.

---

# 13. Dependency Injection

Angular uses the built-in Dependency Injection framework.

Dependencies should be provided through constructors.

---

## Registration Order

Dependencies should be registered in the following order:

```text
Firebase
        ↓
Repositories
        ↓
Use Cases
        ↓
Signal Stores
```

Higher-level components should never instantiate lower-level services directly.

---

## Dependency Rules

Avoid:

* Static service access.
* Manual dependency creation.
* Global mutable services.

Every dependency should be injected.

---

# 14. Routing

Navigation is implemented using Angular Router.

The routing layer is responsible for:

* Feature navigation
* Lazy loading
* Route guards
* Deep linking

Routing should remain independent from business logic.

---

## Primary Routes

Examples include:

```text
/

dashboard

/orders

/kitchen

/menu

/tables

/staff

/settings
```

Each route should represent a business capability.

---

## Navigation Principles

Navigation should:

* Be declarative.
* Support lazy loading.
* Support browser history.
* Avoid duplicated routes.

Business state should not depend on routing.

---

# 15. Repository Implementation

Repositories isolate Firestore from the Domain layer.

Repository implementations belong exclusively to the Data layer.

Example:

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

* getKitchenQueue()
* getOrders()
* updateOrderStatus()
* publishMenu()

---

# 16. Firestore Integration

Only the Data layer communicates with Firestore.

Responsibilities include:

* Reading documents.
* Writing documents.
* Listening to real-time updates.
* DTO mapping.
* Error translation.

Presentation and Domain layers should remain Firebase-independent.

---

# 17. DTO Mapping

Firestore documents are represented using DTOs.

DTOs are converted into Domain Entities through dedicated Mappers.

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

Business logic should work exclusively with Domain Entities.

---

# 18. Feature Communication

Features should remain independent.

Communication should occur through:

* Use Cases.
* Repository interfaces.
* Shared Domain Entities.

Avoid direct communication between Signal Stores belonging to different Features.

Example:

```text
Kitchen Feature
        │
        ▼
Update Order Status Use Case
        │
        ▼
Orders Feature
```

Business workflows should coordinate features rather than creating feature dependencies.

---

# 19. Real-Time Synchronization

The Administration Dashboard relies heavily on Firestore real-time updates.

Real-time listeners should be limited to operational workflows.

Examples:

* Kitchen Queue
* Active Orders
* Table Sessions
* Waiter Requests

Configuration data should be loaded on demand.

Examples:

* Restaurant Settings
* Staff Roles
* Historical Reports

Listeners should be disposed immediately when no longer needed.

---

# 20. Error Handling

Errors should be translated into meaningful application failures.

Layer responsibilities:

Presentation

* Display notifications.
* Provide retry actions.

Domain

* Represent business failures.

Data

* Handle Firestore exceptions.
* Translate infrastructure errors.

Infrastructure-specific exceptions should never propagate directly to Components.