# ScanServe Firestore Data Model

**Version:** 1.0
**Status:** Draft
**Last Updated:** July 2026

---

# 1. Purpose

This document defines the physical data model of the ScanServe platform within Cloud Firestore.

It translates the business domain defined in the Domain Model into concrete Firestore collections, documents, and relationships.

The objectives are to:

* Define a consistent Firestore schema.
* Standardize document structures.
* Establish ownership boundaries.
* Support efficient query patterns.
* Minimize Firestore read and write costs.
* Maintain strict tenant isolation.
* Serve as the backend contract for Flutter, Angular, and Cloud Functions.

This document should be considered the single source of truth for the Firestore database structure.

---

# 2. Scope

This document defines:

* Firestore collection hierarchy
* Document ownership
* Collection purposes
* Document structures
* Identifier strategy
* Metadata conventions
* Reference strategy
* Denrichment and denormalization rules
* Timestamp conventions
* Document lifecycle
* Collection relationships

This document intentionally excludes:

* Firestore Security Rules
* Cloud Function implementations
* Repository implementations
* Flutter models
* Angular interfaces
* API contracts

These topics are covered in later architecture documents.

---

# 3. Design Principles

The Firestore data model follows the architectural principles established in:

* 001 System Overview
* 002 Domain Model
* 003 Firestore Design

The following principles govern every collection and document.

---

## 3.1 Domain First

Collections represent business concepts.

Firestore exists to support the domain—not define it.

Every document should map directly to a business entity whenever practical.

---

## 3.2 Ownership Before References

Every document has exactly one owner.

Ownership determines:

* Lifecycle
* Security
* Deletion
* Authorization
* Transaction boundaries

References never imply ownership.

---

## 3.3 Query-Driven Structure

Collections exist because applications need to query them.

Document organization is optimized around read patterns rather than object-oriented design.

---

## 3.4 Tenant Isolation

Every business document belongs to exactly one restaurant tenant.

Tenant ownership is explicit.

Cross-tenant references are prohibited.

---

## 3.5 Immutable History

Historical business records should never lose accuracy.

Examples include:

* Orders
* Order Items
* Payments (future)
* Audit Logs

Historical documents may contain duplicated data to preserve historical correctness.

---

## 3.6 Predictable Scaling

The schema should continue functioning without redesign as restaurants increase in:

* Orders
* Tables
* Staff
* Menu Items
* Customers

No document should become a write hotspot.

---

## 3.7 Consistent Naming

Collections, documents, and fields should follow one naming convention throughout the platform.

Consistency is preferred over abbreviation.

---

# 4. Firestore Naming Conventions

## Collection Names

Collections use:

* lowercase
* camelCase
* plural nouns

Examples:

```
restaurants
branches
tables
tableSessions
customerSessions
menus
categories
menuItems
orders
orderItems
staff
roles
```

---

## Document IDs

Document IDs use randomly generated UUIDs unless otherwise specified.

Document IDs must:

* Never encode business meaning.
* Never expose sequential numbering.
* Remain immutable.

Examples:

```
restaurantId
branchId
tableId
tableSessionId
customerSessionId
menuId
categoryId
menuItemId
orderId
orderItemId
staffId
```

---

## Field Names

Fields use:

* lowerCamelCase
* descriptive names
* singular nouns

Good:

```
restaurantId
branchId
displayNumber
createdAt
updatedAt
isAvailable
```

Avoid:

```
RestaurantID
restaurant_id
tbl
flag
itemNameText
```

---

## Boolean Fields

Boolean fields begin with:

```
is
has
can
should
```

Examples:

```
isActive
isArchived
isAvailable
hasModifier
canOrder
```

---

## Timestamp Fields

Every timestamp ends with:

```
At
```

Examples:

```
createdAt
updatedAt
submittedAt
acceptedAt
preparedAt
servedAt
deletedAt
expiresAt
```

---

## Reference Fields

Reference fields always end with:

```
Id
```

Examples:

```
restaurantId
branchId
tableId
menuId
categoryId
orderId
customerSessionId
```

Firestore DocumentReference types are intentionally avoided.

Relationships are represented using IDs to simplify serialization, migrations, testing, and interoperability across applications.

---

# 5. Document Identifier Strategy

Every business entity owns one globally unique identifier.

Identifiers remain stable throughout the document lifetime.

Identifiers never change after creation.

---

## Global Identifiers

The following entities require globally unique IDs.

| Entity | Identifier |
|---------|------------|
| Restaurant | restaurantId |
| Branch | branchId |
| Table | tableId |
| Table Session | tableSessionId |
| Customer Session | customerSessionId |
| Menu | menuId |
| Category | categoryId |
| Menu Item | menuItemId |
| Order | orderId |
| Order Item | orderItemId |
| Staff | staffId |
| Role | roleId |

---

## Display Identifiers

Some business entities also expose human-readable identifiers.

Examples:

| Entity | Display Field |
|---------|---------------|
| Table | displayNumber |
| Order | orderNumber *(future)* |
| Branch | code *(optional)* |

Display identifiers are intended for users and may change.

They must never be used as document identifiers.

---

# 6. Firestore Collection Hierarchy

The logical ownership hierarchy of Firestore is illustrated below.

```text
Platform
│
├── restaurants
│   │
│   └── Restaurant
│       │
│       ├── branches
│       │
│       ├── tables
│       │
│       ├── tableSessions
│       │
│       ├── customerSessions
│       │
│       ├── menus
│       │
│       ├── categories
│       │
│       ├── menuItems
│       │
│       ├── orders
│       │
│       ├── orderItems
│       │
│       ├── staff
│       │
│       └── roles
│
└── platform
```

This hierarchy represents ownership.

It does not imply nested Firestore collections.

The physical collection layout is intentionally optimized for querying while preserving these ownership relationships.

---

# 7. Root Collections

The ScanServe Firestore database contains a limited number of root collections.

Root collections represent the highest level of ownership within the platform.

Business data should never exist outside these roots.

| Collection | Purpose |
|------------|---------|
| restaurants | Restaurant tenant data |
| platform | Shared platform configuration |

Additional root collections may be introduced in future versions only when they represent platform-wide concerns.

Examples include:

* billing
* subscriptions
* featureFlags
* auditLogs

Restaurant-owned business entities should never become root collections.

---

# 8. Common Metadata Fields

Every business document should include a standard set of metadata fields.

These fields provide consistency across the platform and simplify auditing, synchronization, and future maintenance.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Document identifier. |
| restaurantId | String | ✓ | Owning restaurant. |
| branchId | String | Optional | Owning branch when applicable. |
| createdAt | Timestamp | ✓ | Creation timestamp. |
| updatedAt | Timestamp | ✓ | Last modification timestamp. |
| createdBy | String | Optional | Staff ID or system identifier responsible for creation. |
| updatedBy | String | Optional | Staff ID or system identifier responsible for the last update. |
| isArchived | Boolean | ✓ | Indicates whether the document has been archived. |

Not every entity requires every metadata field. Documents should only include fields applicable to their ownership and lifecycle.

---

# 9. Restaurant Domain

The Restaurant domain represents the top-level business ownership within ScanServe.

Every operational document ultimately belongs to exactly one restaurant tenant.

The following sections define the Firestore representation of:

* Restaurants
* Branches
* Tables

These entities establish the ownership hierarchy for the remainder of the platform.