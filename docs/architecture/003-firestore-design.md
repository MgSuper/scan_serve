# ScanServe Firestore Design

**Version:** 1.0
**Status:** Draft
**Last Updated:** July 2026

---

# 1. Purpose

This document defines how the ScanServe business domain is mapped into Cloud Firestore.

The objectives are to:

* Optimize for real-time user experiences.
* Minimize Firestore read costs.
* Support horizontal scaling across multiple restaurants.
* Maintain a clear ownership model.
* Keep Flutter, Angular, and Cloud Functions aligned around a single backend contract.

Firestore is treated as an implementation of the domain model—not the domain model itself.

---

# 2. Scope

This document defines the architectural principles governing the ScanServe Firestore database.

It intentionally does not define:

Exact collection paths
Document schemas
Security Rules
Firestore indexes
Cloud Function implementations

These topics are specified in their respective architecture documents.

This separation allows the Firestore architecture to remain stable while implementation details evolve independently.

---

# 3. Firestore Design Principles

## 3.1 Query-First Design

Collections are designed around how data is accessed rather than how entities are related.

Every collection must exist because there is a real query that needs it.

---

## 3.2 Ownership Before References

Every document has one clear owner.

Example:

* Restaurant owns Branches.
* Branch owns Tables.
* Table owns Table Sessions.

References may exist between documents, but ownership must remain unambiguous.

---

## 3.3 Denormalize for Read Performance

Firestore favors fast reads over normalized storage.

Duplicating immutable or infrequently changing data is acceptable when it significantly reduces read operations.

---

## 3.4 Real-Time Only Where Valuable

Only collections requiring live updates should be streamed.

Examples:

* Active Orders
* Kitchen Queue
* Table Calls

Collections such as restaurant settings or historical reports should be queried on demand.

---

## 3.5 Multi-Tenant Isolation

Every document belongs to exactly one restaurant tenant.

Data belonging to different restaurants must never mix.

Security Rules enforce this boundary.

---

# 4. Firestore Ownership Hierarchy

Business ownership is represented as follows:

```text
Platform
└── Restaurant
    └── Branch
        ├── Tables
        ├── Menus
        ├── Staff
        ├── Orders
        └── Active Table Sessions
```

This hierarchy describes ownership—not necessarily document nesting.

---

# 5. Read Patterns

Firestore should be optimized around the application's primary consumers.

## Customer PWA

Frequently reads:

* Restaurant information
* Active menu
* Categories
* Menu items
* Customer session
* Cart
* Own orders
* Order status

---

## Kitchen Dashboard

Frequently reads:

* Active orders
* Kitchen queue
* Preparation status

---

## Restaurant Manager

Frequently reads:

* Menu management
* Tables
* Daily orders
* Staff
* Reports

---

## Cloud Functions

Reads and writes:

* Orders
* Payments
* Session lifecycle
* Notifications
* Analytics

---

# 6. Write Patterns

## Customer

Creates:

* Customer Session
* Cart
* Order

Updates:

* Cart
* Customer preferences

---

## Kitchen

Updates:

* Order status
* Kitchen workflow

---

## Manager

Updates:

* Menus
* Categories
* Menu Items
* Restaurant configuration

---

## Cloud Functions

Responsible for privileged writes such as:

* Order validation
* Payment processing
* Notification generation
* Session cleanup

---

# 7. Collection Strategy

Collections represent operational boundaries rather than object-oriented object graphs.

Collections should satisfy the following principles:

* Each collection exists to support one or more well-defined query patterns.
* Collection ownership follows the business domain.
* Collections should avoid excessive nesting.
* Collection names represent business concepts rather than implementation details.
* Documents should remain independently readable whenever practical.

Typical business collections include:

* Restaurants
* Branches
* Tables
* Table Sessions
* Customer Sessions
* Menus
* Categories
* Menu Items
* Orders
* Staff

The exact collection hierarchy is defined in 006 Firestore Data Model, after ownership, security, and event flow have been finalized.

---

# 8. Data Ownership vs References

Ownership determines lifecycle.

References provide relationships.

Example:

Restaurant
owns

* Branches

Branch
owns

* Tables
* Menus
* Staff

Table
owns

* Table Sessions

Table Session
owns

* Customer Sessions

Customer Session
owns

* Cart

Order references:

* Table
* Table Session
* Customer Session
* Branch
* Restaurant

This separation allows efficient querying while preserving clear ownership.

---

# 9. Document Lifecycle

Every Firestore document has a clearly defined lifecycle.

A document is expected to progress through the following stages:

Created
    ↓
Active
    ↓
Updated
    ↓
Archived (optional)
    ↓
Deleted (optional)

Lifecycle rules are determined by the owning aggregate.

Examples:

* Customer Sessions expire after inactivity.
* Orders remain immutable after submission except for lifecycle status updates.
* Menu Items may become unavailable without being deleted.
* Tables persist for the lifetime of a branch.

Understanding document lifecycle helps define retention policies, Cloud Function responsibilities, and Security Rules.

---

# 10. Denormalization Strategy

Orders should store immutable snapshots of menu data.

For example, an Order Item should contain:

* Product name
* Product price
* Quantity
* Selected options

rather than relying on the current Menu Item document.

Historical orders must remain accurate even if the menu changes later.

---

# 11. Real-Time Strategy

Live listeners are reserved for operational workflows.

| Feature             | Real-Time |
| ------------------- | --------- |
| Kitchen Queue       | Yes       |
| Order Status        | Yes       |
| Table Calls         | Yes       |
| Cart                | Yes       |
| Menu Management     | No        |
| Restaurant Settings | No        |
| Reports             | No        |

This minimizes unnecessary Firestore reads while preserving responsiveness.

---

# 12. Hotspot Prevention

Firestore scales automatically, but application design should avoid unnecessary contention.

Architectural guidelines include:

* Avoid write-heavy shared documents.
* Prefer append-oriented collections over frequently updated arrays.
* Keep documents small and focused.
* Store counters separately when high write frequency is expected.
* Avoid using a single document as a synchronization point.
* Design writes so that traffic naturally distributes across many documents.

These practices improve scalability while reducing latency and contention under high load.

---

# 13. Firestore Design Goals

The Firestore implementation should satisfy the following goals:

* Low operational cost
* Predictable query performance
* Strong tenant isolation
* Simple Security Rules
* Clear document ownership
* Efficient real-time synchronization
* Straightforward client implementation

---

# 14. Deferred Decisions

The following implementation details are intentionally deferred to later architecture documents:

* Exact collection hierarchy
* Document schemas
* Firestore indexes
* Composite indexes
* Security Rules
* Offline persistence strategy
* Cloud Function triggers
* Transaction boundaries
* Batch write strategies
* Data retention policies

Separating these concerns keeps the Firestore design focused on architectural principles rather than implementation details.

---

# 15. Guiding Principle

Firestore is an implementation detail of the ScanServe domain.

Collections, documents, and indexes exist to efficiently serve the business workflows defined by the domain model.

The database should remain easy to understand, cost-efficient to operate, and capable of supporting future platform growth without fundamental restructuring.

