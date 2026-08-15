# 11. BLoC Architecture

The Flutter application uses **flutter_bloc** as its primary state management solution.

Every Feature owns its own BLoC instances.

BLoCs coordinate Presentation and Domain layers without containing business rules.

---

## Responsibilities

BLoCs are responsible for:

* Receiving UI events.
* Calling Use Cases.
* Managing application state.
* Handling presentation-specific errors.
* Exposing immutable states to the UI.

BLoCs should never communicate directly with Firestore.

---

## BLoC Structure

```text
presentation/
│
├── bloc/
│   ├── menu_bloc.dart
│   ├── menu_event.dart
│   └── menu_state.dart
│
├── pages/
│
└── widgets/
```

Every BLoC should have:

* Events
* States
* BLoC implementation

---

## Event Guidelines

Events represent user intentions.

Examples:

```
LoadMenu

RefreshMenu

AddItemToCart

RemoveItemFromCart

SubmitOrder
```

Events should describe **what happened**, not **how to perform it**.

---

## State Guidelines

States represent immutable snapshots of the UI.

Typical states include:

```
Initial

Loading

Loaded

Empty

Error
```

States should never expose mutable collections.

---

# 12. Dependency Injection

Dependency Injection is implemented using **get_it**.

The service locator should be initialized once during application startup.

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
BLoCs
```

Lower-level dependencies should always be registered before higher-level dependencies.

---

## Dependency Rules

Only constructors should receive dependencies.

Avoid:

* Singleton business logic.
* Manual dependency creation.
* Static service access.

All dependencies should be resolved through injection.

---

# 13. Routing

Navigation is implemented using **go_router**.

The routing layer is responsible for:

* Deep links
* QR entry
* Navigation guards *(future)*
* Nested navigation

Routing should remain independent of business logic.

---

## Primary Routes

Examples include:

```text
/
        Home

/menu

/cart

/order-tracking

/session-expired

/error
```

Every route should represent a business workflow.

---

## Navigation Principles

Navigation should:

* Be declarative.
* Support browser history.
* Support deep linking.
* Avoid duplicated routes.

Business state should not depend on navigation.

---

# 14. Repository Implementation

Repositories isolate Firestore from the Domain layer.

Every repository implements a repository contract defined in the Domain layer.

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

Repositories should expose business operations rather than database operations.

Examples:

* getActiveMenu()
* submitOrder()
* updateCart()
* getCustomerOrders()

---

# 15. Firestore Integration

Only the Data layer communicates with Firestore.

The Presentation and Domain layers remain independent of Firebase.

Responsibilities of the Data layer include:

* Reading documents.
* Writing documents.
* Listening to real-time updates.
* Mapping DTOs.
* Translating infrastructure errors.

Firestore implementation details should never leak into higher layers.

---

# 16. DTO Mapping

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

Entities should never depend on JSON serialization.

---

# 17. Feature Communication

Features should remain loosely coupled.

Communication should occur through:

* Shared Use Cases.
* Repository interfaces.
* Domain entities.

Avoid direct communication between BLoCs belonging to different features.

Example:

```text
Menu Feature
        │
        ▼
Submit Order Use Case
        │
        ▼
Ordering Feature
```

Business workflows should coordinate features rather than creating feature dependencies.

---

# 18. Real-Time Synchronization

The Flutter Customer PWA relies on Firestore's real-time capabilities.

Real-time listeners should be used only where they provide business value.

Examples:

* Customer Session
* Cart
* Order Tracking

Collections that change infrequently should be loaded on demand.

Examples:

* Restaurant information
* Menus
* Categories

Listeners should be disposed immediately when no longer needed.

---

# 19. Error Handling

Errors should be translated into user-friendly failures.

Layer responsibilities:

Presentation

* Display messages.
* Offer retry actions.

Domain

* Represent business failures.

Data

* Handle infrastructure exceptions.
* Translate Firebase exceptions.

Infrastructure-specific exceptions should never reach the UI unchanged.