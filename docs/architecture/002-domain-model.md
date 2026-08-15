# ScanServe Domain Model

**Version:** 1.0
**Status:** Draft
**Last Updated:** July 2026

---

# 1. Purpose

This document defines the business domain of the ScanServe platform.

It establishes a shared, technology-independent model that is used consistently across:

* Flutter Customer PWA
* Angular Administration Dashboard
* Firebase Firestore
* Cloud Functions
* Documentation

The domain model represents business concepts rather than implementation details.

---

# 2. Domain Philosophy

ScanServe follows a **Shared Domain First** approach.

The business domain is the single source of truth.

Technology choices such as Flutter, Angular, Firestore, or Cloud Functions must adapt to the domain—not the other way around.

Business terminology should remain consistent across every layer of the platform.

---

# 3. Tenant Hierarchy

ScanServe is designed as a multi-tenant SaaS platform.

The tenant hierarchy is:

```text
Platform
└── Restaurant (Tenant)
    └── Branch
        ├── Tables
        │   └── Table Session
        │       └── Customer Sessions
        │
        ├── Menus
        ├── Staff
        └── Orders
```

## Platform

Represents the ScanServe SaaS platform.

Responsibilities:

- Tenant management
- Global configuration
- Platform administration
- Billing (future)

---

## Restaurant

Represents an independent business.

Examples:

- Starbucks
- Highlands Coffee
- Local Coffee House

A restaurant owns one or more branches.

---

## Branch

Represents a physical operating location.

Every customer visit occurs within exactly one branch.

A branch owns:

- Tables
- Menus
- Orders
- Staff

---

## Table

Represents a physical dining table.

Properties include:

- Identifier
- Display number
- QR code
- Capacity
- Status

A table may host many table sessions throughout its lifetime, but only one active table session at a time.

---

## Table Session

Represents one dining occasion at a physical table.

A table session begins when the first customer scans the table QR code.

It ends when the restaurant closes the table or the session expires.

Responsibilities:

- Tracks table occupancy
- Groups multiple customer sessions
- Coordinates table-level operations
- Maintains overall visit lifecycle
```

# 4. Business Domains

The platform is divided into the following bounded contexts.

## Restaurant Management

Owns:

* Restaurant
* Branch
* Staff

---

## Table Session

Owns:

* Table
* Table Session
* Customer Session

---

## Menu Management

Owns:

* Menu
* Category
* Menu Item
* Modifier (future)

---

## Ordering

Owns:

* Cart
* Order
* Order Item

---

## Kitchen Operations

Owns:

* Kitchen Ticket
* Preparation Status

---

## Administration

Owns:

* Roles
* Permissions
* Operational Settings

---

## Platform Services

Owns:

* Notifications
* Audit Logs
* Analytics
* Files

---

# 5. Core Business Entities

## Restaurant

Represents an organization using ScanServe.

Responsibilities:

* Branding
* Configuration
* Subscription
* Ownership of branches

---

## Branch

Represents a physical restaurant location.

Responsibilities:

* Tables
* Menus
* Orders
* Staff
* Operating hours

---

## Table

Represents a physical customer table.

Properties include:

* Identifier
* Display number
* QR code
* Status
* Capacity

A table belongs to exactly one branch.

---

## Customer Session

Represents one individual customer participating in a table session.

Each customer scans the QR code independently and receives their own customer session.

Responsibilities:

- Stores customer context
- Owns exactly one cart
- Owns one or more orders
- Stores language preference
- Stores device/session information

Multiple customer sessions may belong to the same table session.

This design allows groups of customers sharing one physical table to order independently while remaining associated with the same dining visit.

---

## Menu

Represents a collection of menu categories.

Menus allow future support for:

* Breakfast
* Lunch
* Dinner
* Seasonal menus

A branch may own multiple menus.

---

## Category

Groups related menu items.

Examples:

* Coffee
* Tea
* Desserts

---

## Menu Item

Represents an orderable product.

Examples:

* Cappuccino
* Matcha Latte
* Cheesecake

A menu item belongs to one category.

---

## Cart

Represents the customer's current selection before checkout.

A cart belongs to exactly one customer session.

---

## Order

Represents a submitted purchase request.

An order is immutable once submitted, except for lifecycle status updates.

---

## Order Item

Represents an individual purchased menu item.

Each order item maintains its own preparation lifecycle.

---

## Kitchen Ticket

Represents the kitchen's operational view of an order.

Separating kitchen workflow from customer ordering allows future operational enhancements without changing customer-facing behavior.

---

## Staff

Represents restaurant employees.

Examples:

* Manager
* Cashier
* Kitchen Staff
* Waiter

---

# 6. Domain Identity

Every core business entity has a stable identity that remains independent of its current state.

Identity is represented by a globally unique identifier (UUID) and should never change during the entity's lifetime.

Examples include:

Restaurant ID
Branch ID
Table ID
Table Session ID
Customer Session ID
Menu ID
Category ID
Menu Item ID
Order ID
Order Item ID
Staff ID

Business logic should always reference entity identity rather than mutable properties such as names, display numbers, or status.

This principle ensures referential integrity across Firestore documents, Cloud Functions, and client applications.

# 7. Supporting Platform Entities

These entities support the platform but are not part of the restaurant business domain.

* User
* Role
* Permission
* Notification
* Audit Log
* Device
* File
* Analytics Event

---

# 8. Entity Relationships

```text
Platform
└── Restaurant
    └── Branch
        ├── Table
        │   └── Table Session
        │       ├── Customer Session
        │       │   ├── Cart
        │       │   └── Order
        │       │       └── Order Item
        │       │
        │       └── Customer Session
        │
        ├── Menu
        │   └── Category
        │       └── Menu Item
        │
        └── Staff
```

Relationships express ownership rather than storage strategy.

Database representation is defined separately in the Firestore Design document.

---

# 9. Aggregate Boundaries

To maintain consistency, the following aggregates define transactional boundaries.

## Restaurant Aggregate

Root:

* Restaurant

Contains:

* Branches

---

## Branch Aggregate

Root:

* Branch

Contains:

* Tables
* Menus
* Staff

---

## Table Session Aggregate

Root:

- Table Session

Contains:

- Customer Sessions

---

## Customer Session Aggregate

Root:

- Customer Session

Contains:

- Cart

References:

- Orders (read-only)

Customer Sessions never own Orders.

Orders remain an independent aggregate after submission to allow immutable order history and asynchronous kitchen processing.

---

## Order Aggregate

Root:

- Order

Contains:

- Order Items

References:

- Kitchen Ticket

---

# 10. Domain Invariants

The following rules must always hold true.

- A restaurant owns one or more branches.
- A branch belongs to exactly one restaurant.
- A table belongs to exactly one branch.
- A table session belongs to exactly one table.
- Only one active table session may exist for a table at any given time.
- A customer session belongs to exactly one table session.
- A cart belongs to exactly one customer session.
- An order belongs to exactly one customer session.
- An order item belongs to exactly one order.
- A menu belongs to exactly one branch.
- A category belongs to exactly one menu.
- A menu item belongs to exactly one category.
- Every entity has a globally unique identifier.

Business logic, Firestore Security Rules, and Cloud Functions must enforce these invariants.

---

# 11. Ubiquitous Language

The following terminology is canonical throughout the ScanServe platform. These names must be used consistently across documentation, Flutter, Angular, Firebase, Cloud Functions, and future services.

| Business Concept          | Canonical Name   | Description                                                                 |
| ------------------------- | ---------------- | --------------------------------------------------------------------------- |
| Restaurant                | Restaurant       | A business operating on the ScanServe platform.                             |
| Physical location         | Branch           | A physical operating location of a restaurant.                              |
| Dining table              | Table            | A physical table identified by a QR code.                                   |
| Shared dining visit       | Table Session    | A dining occasion at a table that groups one or more customer sessions.     |
| Individual customer visit | Customer Session | A single customer's interaction during a table session. *(See note below.)* |
| Food catalogue            | Menu             | A collection of categories available for ordering.                          |
| Menu grouping             | Category         | A logical grouping of menu items.                                           |
| Sellable product          | Menu Item        | An individual product that can be ordered.                                  |
| Current selection         | Cart             | A customer's unsubmitted selection of menu items.                           |
| Submitted purchase        | Order            | A confirmed order submitted to the restaurant.                              |
| Purchased product         | Order Item       | An individual item within an order.                                         |
| Kitchen workflow          | Kitchen Ticket   | The kitchen's operational representation of an order.                       |
| Restaurant employee       | Staff            | Personnel responsible for restaurant operations.                            |

Alternative names should not be introduced into code or documentation.

Examples of names that should be avoided include:

* Visit
* Active Table
* Customer Context
* Guest Context
* Basket
* Product Category
* Food Item
* Purchase
* Kitchen Order

Always use the canonical terminology defined above.

> **Note:** In Version 1, the term **Customer Session** represents an anonymous browser session created after scanning a QR code. If customer authentication is introduced in a future version, this entity may be renamed to **Guest Session** to distinguish anonymous visits from authenticated customer identities without changing the underlying business model.

---

# 12. Future Extensions

The domain model is designed to support future capabilities without breaking existing concepts.

Potential extensions include:

* Menu modifiers
* Combo meals
* Promotions and discounts
* Reservations
* Delivery orders
* Loyalty programs
* Online payments
* Inventory management
* Multi-brand organizations
* POS integrations

Future features should extend the existing domain rather than redefine it.

---

# 13. Guiding Principle

The domain model is the foundation of the ScanServe platform.

Every implementation—whether in Flutter, Angular, Firebase, or Cloud Functions—must remain consistent with the business concepts defined in this document.

Technology may evolve over time; the shared business domain remains the platform's most stable and valuable asset.

# 14. Related Documents

This document defines the business concepts used throughout the ScanServe architecture.

The following documents build upon this domain model:

| Document                 | Relationship                                      |
| ------------------------ | ------------------------------------------------- |
| 001 System Overview      | Defines overall platform architecture             |
| 003 Firestore Design     | Maps the domain model to Firestore collections    |
| 005 Business Processes   | Describes business workflows using these entities |
| 006 Firestore Data Model | Defines document structures for each entity       |
| 007 Security Model       | Defines authorization based on domain ownership   |
| 008 Event Flow           | Describes domain events and lifecycle transitions |
