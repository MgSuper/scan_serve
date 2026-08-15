# 31. Timestamp Strategy

All business documents should use Firestore `Timestamp` values.

Timestamps provide:

* Consistent ordering
* Auditability
* Synchronization
* Query support
* Lifecycle management

---

## Standard Timestamp Fields

| Field | Required | Description |
|-------|----------|-------------|
| createdAt | ✓ | Document creation time. |
| updatedAt | ✓ | Most recent modification time. |

---

## Optional Timestamp Fields

The following timestamps are used when applicable.

| Field | Purpose |
|-------|----------|
| submittedAt | Order submission |
| acceptedAt | Kitchen accepted order |
| preparedAt | Kitchen completed preparation |
| servedAt | Order served |
| startedAt | Table Session started |
| endedAt | Table Session ended |
| expiresAt | Automatic expiration |
| lastLoginAt | Staff login |
| deletedAt | Soft deletion timestamp |

---

## Timestamp Guidelines

* Use Firestore `Timestamp` instead of strings.
* Store timestamps in UTC.
* Client applications are responsible for localization.
* Never store formatted date strings in Firestore.
* Never overwrite `createdAt`.
* Always update `updatedAt` when business data changes.

---

# 32. Soft Delete Strategy

Business data should rarely be physically deleted.

Soft deletion preserves:

* Historical reporting
* Auditability
* Referential integrity
* Analytics

---

## Standard Fields

| Field | Type | Description |
|-------|------|-------------|
| isArchived | Boolean | Indicates archived state. |
| deletedAt | Timestamp | Optional deletion timestamp. |
| deletedBy | String | Optional staff identifier. |

---

## Archivable Entities

Examples include:

* Menus
* Categories
* Menu Items
* Tables
* Branches
* Staff
* Roles

---

## Non-Deletable Entities

The following documents should remain permanently available after creation.

* Orders
* Order Items
* Table Sessions
* Customer Sessions *(until retention policy expires)*

These entities represent historical business records.

---

# 33. Transaction Boundaries

Cloud Firestore transactions should be used only when multiple documents must remain consistent.

Transactions should remain small and short-lived.

---

## Recommended Transaction Usage

### Create Order

Single transaction:

* Validate Customer Session
* Validate Cart
* Create Order
* Create Order Items
* Update Customer Session
* Clear Cart

---

### Update Kitchen Status

Single transaction:

* Update Order status
* Update timestamps

---

### Staff Management

Single transaction:

* Create Staff
* Assign Role

---

## Avoid Large Transactions

Transactions should not include:

* Analytics updates
* Notification delivery
* Reporting
* Cleanup jobs

These operations should execute asynchronously using Cloud Functions.

---

# 34. Batch Operations

Batch writes are appropriate when atomic consistency is not required.

Typical examples include:

* Publishing an entire menu
* Updating display order
* Archiving categories
* Bulk availability updates
* Initial restaurant setup

Batch operations should remain below Firestore limits.

---

# 35. Firestore Index Guidelines

Indexes should be created only for production query patterns.

Avoid creating indexes for hypothetical use cases.

---

## Typical Composite Indexes

| Collection | Fields |
|------------|--------|
| tables | restaurantId + branchId |
| tableSessions | restaurantId + tableId + status |
| customerSessions | restaurantId + tableSessionId |
| menus | restaurantId + isActive |
| categories | menuId + displayOrder |
| menuItems | categoryId + displayOrder |
| orders | restaurantId + status |
| orders | restaurantId + createdAt |
| staff | restaurantId + roleId |

Additional indexes should be introduced only after query requirements have been validated.

---

# 36. Collection Summary

The following collections comprise the Version 1 ScanServe Firestore database.

| Collection | Owner | Primary Purpose |
|------------|-------|-----------------|
| restaurants | Platform | Restaurant tenant |
| branches | Restaurant | Physical locations |
| tables | Branch | Dining tables |
| tableSessions | Restaurant | Shared dining visit |
| customerSessions | Restaurant | Individual customer visit |
| carts | Customer Session | Temporary customer selections |
| menus | Branch | Available menus |
| categories | Menu | Product grouping |
| menuItems | Category | Orderable products |
| orders | Restaurant | Customer purchases |
| orderItems | Order | Purchased products |
| staff | Restaurant | Restaurant employees |
| roles | Restaurant | Staff authorization |

---

# 37. Complete Ownership Hierarchy

The complete ownership hierarchy of the ScanServe business domain is shown below.

```text
Platform
│
└── Restaurant
    │
    ├── Branch
    │
    ├── Table
    │
    ├── Table Session
    │   │
    │   └── Customer Session
    │           │
    │           └── Cart
    │
    ├── Menu
    │   │
    │   └── Category
    │           │
    │           └── Menu Item
    │
    ├── Order
    │   │
    │   └── Order Item
    │
    ├── Staff
    │
    └── Role
```

This hierarchy represents business ownership.

It does **not** imply nested Firestore collections.

The physical Firestore schema remains optimized for query performance while preserving these ownership relationships.

---

# 38. Guiding Principle

The Firestore data model exists to support the business domain—not replace it.

Every collection, document, and field should satisfy a clear business purpose while maintaining:

* Strong tenant isolation
* Predictable query performance
* Efficient real-time synchronization
* Historical accuracy
* Straightforward Security Rules
* Long-term maintainability

As the ScanServe platform evolves, new features should extend this model rather than redefine its core ownership structure.

---

# 39. Related Documents

This document defines the physical Firestore schema for the ScanServe platform.

The following architecture documents provide additional context.

| Document | Relationship |
|----------|--------------|
| 001 System Overview | Defines the overall platform architecture |
| 002 Domain Model | Defines the business entities represented in Firestore |
| 003 Firestore Design | Defines the architectural principles of the Firestore database |
| 005 Business Processes | Defines the workflows that create and modify documents |
| 007 Security Model | Defines authorization and Security Rules |
| 008 Event Flow | Defines how business events propagate through the platform |
| 009 Client Architecture | Defines how Flutter and Angular interact with the Firestore data model |