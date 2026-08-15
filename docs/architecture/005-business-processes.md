# 005. Business Processes

**Version:** 1.0
**Status:** Draft
**Last Updated:** July 2026

---

# 1. Purpose

This document defines the core business processes of the ScanServe platform.

A business process describes how the platform responds to a user action from the moment it is triggered until it reaches a stable outcome.

The goals are to:

* Define system behavior.
* Clarify process ownership.
* Establish responsibilities across Flutter, Angular, Firebase, and Cloud Functions.
* Provide the foundation for the Firestore data model and backend implementation.

---

# 2. Scope

This document defines the high-level business workflows executed by the ScanServe platform.

It describes:

* Business process ownership.
* Process triggers.
* High-level workflows.
* Responsibilities across applications and backend services.

It intentionally excludes:

* Firestore document structures
* API contracts
* Security Rules
* Client implementation details

These topics are defined in later architecture documents.

---

# 3. Process Classification

Business processes are grouped into four categories:

### Core Processes

Essential customer ordering workflows.

### Operational Processes

Restaurant day-to-day operations.

### Administrative Processes

Restaurant management and configuration.

### Platform Processes

Background platform services and automation.

---

# 4. Business Process Principles

Every business process within ScanServe should follow these principles:

* Each process has one clearly defined owner.
* Business-critical validation occurs in trusted backend components.
* User interfaces initiate actions but do not enforce business rules.
* Processes should produce predictable outcomes.
* Long-running operations should be asynchronous where appropriate.
* Business processes remain independent of user interface implementation.

---

# 5. Core Processes

---

## BP-001 — Start Dining Session

**Primary Actor**

Customer

**Owner**

Flutter Customer PWA

**Supporting Systems**

* Firestore
* Cloud Functions

**Trigger**

Customer scans a table QR code.

**Flow**

1. Extract restaurant and table identifiers.
2. Validate restaurant.
3. Validate branch.
4. Validate table.
5. Find or create an active Table Session.
6. Create a Customer Session.
7. Create an empty Cart.
8. Load the active Menu.
9. Display the customer home screen.

**Preconditions**

* Restaurant exists.
* Branch exists.
* Table is active.

**Postconditions**

* Customer Session exists.
* Cart exists.
* Customer can begin ordering.

**Failure Cases**

* Invalid QR code.
* Restaurant unavailable.
* Table disabled.
* Network failure.

---

## BP-002 — Browse Menu

**Primary Actor**

Customer

**Owner**

Flutter Customer PWA

**Supporting Systems**

Firestore

**Trigger**

Customer enters the application.

**Flow**

1. Load menu.
2. Load categories.
3. Load menu items.
4. Display products.

**Postconditions**

Customer can browse and search products.

---

## BP-003 — Manage Cart

**Primary Actor**

Customer

**Owner**

Flutter Customer PWA

**Supporting Systems**

Firestore

**Flow**

* Add item
* Remove item
* Update quantity
* Recalculate totals

**Postconditions**

Cart reflects the customer's intended purchase.

---

## BP-004 — Place Order

**Primary Actor**

Customer

**Owner**

Platform Backend (Cloud Functions)

**Supporting Systems**

* Firestore
* Flutter
* Angular

**Trigger**

Customer presses **Place Order**.

**Flow**

1. Validate Customer Session.
2. Validate Cart.
3. Validate Menu Items.
4. Calculate totals.
5. Create Order.
6. Create Order Items.
7. Notify Kitchen.
8. Clear Cart.

**Postconditions**

* Order created.
* Kitchen receives new order.
* Customer enters order tracking.

**Failure Cases**

* Menu item unavailable.
* Cart empty.
* Validation failure.

---

## BP-005 — Track Order

**Primary Actor**

Customer

**Owner**

Firestore

**Supporting Systems**

Flutter

**Flow**

Realtime updates:

Pending
    ↓
Accepted
    ↓
Preparing
    ↓
Ready
    ↓
Served

---

# 6. Operational Processes

---

## BP-101 — Kitchen Accepts Order

Primary Actor

Kitchen Staff

Owner

Angular Dashboard

Flow

Pending

↓

Accepted

↓

Preparing

---

## BP-102 — Kitchen Updates Order

Primary Actor

Kitchen Staff

Owner

Angular Dashboard

Flow

Preparing

↓

Ready

↓

Served

---

## BP-103 — Customer Calls Waiter

Primary Actor

Customer

Owner

Flutter

Supporting Systems

Firestore

Angular

Flow

Customer

↓

Press Call Waiter

↓

Firestore

↓

Angular Notification

↓

Waiter Responds

---

# 7. Administrative Processes

## BP-201 — Manage Menu

Owner

Restaurant Manager

Actions

* Create Menu
* Edit Menu
* Archive Menu

---

## BP-202 — Manage Tables

Actions

* Add Table
* Disable Table
* Generate QR

---

## BP-203 — Manage Staff

Actions

* Invite Staff
* Remove Staff
* Assign Roles

---

# 8. Platform Processes

## BP-301 — Session Cleanup

Owner

Cloud Functions

Runs periodically.

Responsibilities

* Close expired table sessions.
* Remove inactive customer sessions.

---

## BP-302 — Notification Dispatch

Owner

Cloud Functions

Responsibilities

* Notify kitchen.
* Notify customers.
* Notify waiters.

---

## BP-303 — Analytics Collection

Owner

Cloud Functions

Responsibilities

Capture operational metrics.

---

# 9. Process Ownership Matrix

| Process               | Customer PWA | Angular Dashboard | Firestore | Cloud Functions |
|-----------------------|--------------|-------------------|-----------|-----------------|
| Start Dining Session  | ✓            |                   | ✓         | ✓               |
| Browse Menu           | ✓            |                   | ✓         |                 |
| Manage Cart           | ✓            |                   | ✓         |                 |
| Place Order           | ✓            |                   | ✓         | ✓               |
| Track Order           | ✓            |                   | ✓         |                 |
| Kitchen Workflow      |              | ✓                 | ✓         |                 |
| Waiter Request        | ✓            | ✓                 | ✓         |                 |
| Menu Management       |              | ✓                 | ✓         |                 |
| Session Cleanup       |              |                   | ✓         | ✓               |
| Notification Dispatch |              |                   | ✓         | ✓               |
| Analytics Collection  |              |                   | ✓         | ✓               |

---

# 10. Guiding Principle

User interfaces request actions.

Business processes execute actions.

Business-critical logic must reside in trusted backend components rather than client applications.
