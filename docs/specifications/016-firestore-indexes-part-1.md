# ScanServe Firestore Indexes

**Version:** 1.0
**Status:** Draft
**Last Updated:** July 2026

---

# 1. Purpose

This document defines the Firestore indexing strategy used by the ScanServe platform.

The objectives are to:

* Optimize query performance.
* Minimize Firestore read costs.
* Support real-time operations.
* Prevent missing index errors during development.
* Provide a blueprint for the Firestore index configuration.

This document defines **which indexes are required** rather than the implementation format of `firestore.indexes.json`.

---

# 2. Scope

This document defines:

* Composite indexes
* Query patterns
* Sorting strategy
* Filtering strategy
* Collection Group indexes *(future)*
* Index maintenance

This document intentionally excludes:

* Firestore document schema
* Security Rules
* Query implementation
* Client repositories

---

# 3. Index Design Principles

Every Firestore index should follow these principles.

---

## 3.1 Query-Driven

Indexes exist to support business queries.

Never create an index that is not required by an application workflow.

---

## 3.2 Minimize Composite Indexes

Prefer the smallest number of composite indexes necessary.

Avoid creating indexes "just in case."

---

## 3.3 Business-Oriented

Indexes should optimize business operations.

Examples:

* Kitchen Queue
* Active Orders
* Customer Order Tracking

Avoid indexes created solely for development convenience.

---

## 3.4 Predictable Ordering

Every frequently queried collection should have a predictable default ordering.

Examples:

* createdAt
* updatedAt
* displayOrder
* statusChangedAt

---

## 3.5 Scalability

Indexes should support future growth without redesign.

Index strategy should remain stable as additional restaurants are added.

---

# 4. Query Categories

Business queries are grouped into four categories.

---

## Customer Queries

Examples:

* Load active Menu.
* Browse Categories.
* Browse Menu Items.
* Load Customer Orders.
* Track Order Status.

---

## Operational Queries

Examples:

* Kitchen Queue.
* Active Orders.
* Waiter Requests.
* Active Table Sessions.

---

## Administrative Queries

Examples:

* Manage Menus.
* Manage Tables.
* Manage Staff.
* Daily Orders.

---

## Platform Queries

Examples:

* Session Cleanup.
* Analytics.
* Notification Processing.

---

# 5. Index Strategy

Firestore automatically creates single-field indexes.

Composite indexes should be added only when required by multi-field queries.

Typical query structure:

```text
Filter
    +
Sort
    +
Limit
```

Each composite index should directly correspond to one or more business queries.

---

# 6. Ordering Strategy

The following fields are recommended for sorting.

| Collection | Default Order |
|------------|---------------|
| menus | displayOrder |
| categories | displayOrder |
| menuItems | displayOrder |
| orders | createdAt DESC |
| tableSessions | startedAt DESC |
| customerSessions | createdAt DESC |
| staff | displayName |
| waiterRequests *(future)* | createdAt DESC |

These defaults should remain consistent across all client applications.

---

# 7. Query Guidelines

Queries should:

* Filter before sorting.
* Use indexed fields.
* Avoid unnecessary client-side filtering.
* Limit returned documents.
* Paginate large result sets.

Firestore queries should always align with documented business workflows.

---

# 8. Composite Index Format

Each documented composite index includes:

* Collection
* Business Purpose
* Filter Fields
* Sort Fields
* Query Consumers

The following sections define the required composite indexes.