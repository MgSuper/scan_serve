# ScanServe Cloud Functions Architecture

**Version:** 1.0
**Status:** Draft
**Last Updated:** July 2026

---

# 1. Purpose

This document defines the architecture of the ScanServe Cloud Functions backend.

Cloud Functions provide trusted backend services responsible for executing business-critical operations.

The objectives are to:

* Centralize business logic.
* Protect business data.
* Enforce authorization.
* Coordinate business workflows.
* Execute asynchronous platform operations.
* Provide a scalable serverless backend.

Cloud Functions are the primary execution environment for privileged business operations.

---

# 2. Scope

This document defines:

* Cloud Functions architecture
* Function categories
* Folder organization
* Callable Functions
* Firestore Trigger Functions
* Scheduled Functions
* Shared backend services
* Validation pipeline
* Error handling
* Logging strategy

This document intentionally excludes:

* Firestore schema
* Security Rules
* Client implementation
* Firebase project configuration

---

# 3. Architectural Principles

Every Cloud Function should follow these principles.

---

## 3.1 Business First

Functions implement business operations rather than database operations.

Good:

```
submitOrder()
```

Avoid:

```
createOrderDocument()
```

---

## 3.2 Stateless

Functions should never depend on in-memory application state.

Every request should be independently executable.

---

## 3.3 Idempotent

Functions should safely handle repeated execution whenever practical.

Duplicate requests must not create duplicate business transactions.

---

## 3.4 Small Responsibility

Each function should perform one business operation.

Avoid functions that implement multiple unrelated workflows.

---

## 3.5 Reusable Services

Business logic should reside inside reusable services rather than directly inside function handlers.

---

# 4. Function Categories

Cloud Functions are divided into four categories.

---

## Callable Functions

Directly invoked by Flutter or Angular.

Examples:

* Start Dining Session
* Submit Order
* Publish Menu

---

## Firestore Trigger Functions

Automatically execute after Firestore changes.

Examples:

* Order Created
* Order Updated
* Staff Created

---

## Scheduled Functions

Execute periodically.

Examples:

* Session Cleanup
* Analytics Aggregation
* Expired Session Detection

---

## Platform Functions

Internal platform operations.

Examples:

* Notification Dispatch
* Health Checks
* Future Billing

---

# 5. Project Structure

Recommended folder structure:

```text
functions/
│
├── src/
│   │
│   ├── callable/
│   │
│   ├── triggers/
│   │
│   ├── scheduled/
│   │
│   ├── services/
│   │
│   ├── repositories/
│   │
│   ├── validators/
│   │
│   ├── models/
│   │
│   ├── shared/
│   │
│   └── index.ts
│
├── package.json
│
└── tsconfig.json
```

Each folder has a single responsibility.

---

# 6. Layer Architecture

Cloud Functions should follow a layered architecture.

```text
Function
      │
      ▼
Validator
      │
      ▼
Service
      │
      ▼
Repository
      │
      ▼
Firestore
```

Responsibilities:

Function

* Receive request
* Authenticate
* Return response

Validator

* Validate input
* Validate permissions
* Validate business rules

Service

* Execute business logic

Repository

* Read and write Firestore

Firestore

* Persistent storage

---

# 7. Shared Services

Shared services contain reusable business logic.

Examples:

* OrderService
* MenuService
* SessionService
* NotificationService
* StaffService

Services should remain framework-independent whenever practical.

---

# 8. Validation Pipeline

Every callable function should execute the following pipeline.

```text
Receive Request
        ↓
Authenticate
        ↓
Validate Request
        ↓
Validate Tenant
        ↓
Validate Permissions
        ↓
Validate Business Rules
        ↓
Execute Service
        ↓
Persist Changes
        ↓
Return Response
```

No business operation should execute before validation completes.