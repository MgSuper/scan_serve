# 004. Personas & User Journeys

**Version:** 1.0
**Status:** Draft
**Last Updated:** July 2026

---

# 1. Purpose

This document defines the primary users (personas) of the ScanServe platform and the journeys they perform.

The goals are to:

* Understand who uses the platform.
* Define what each user is trying to accomplish.
* Clarify which application they interact with.
* Provide the foundation for business processes and application design.

This document intentionally avoids implementation details.

---

# 2. Scope

This document defines the human interactions with the ScanServe platform.

It focuses on:

* Primary user personas.
* User goals.
* High-level business journeys.
* Application touchpoints.

It intentionally excludes:

* UI design
* Screen layouts
* API interactions
* Technical implementation details

These topics are defined in later architecture documents.

---

# 3. Primary Personas

| Persona                           | Application          | Description                                                                             |
| --------------------------------- | -------------------- | --------------------------------------------------------------------------------------- |
| Customer                          | Flutter Customer PWA | A guest dining at a restaurant who scans a QR code to browse the menu and place orders. |
| Waiter                            | Angular Admin        | Assists customers, monitors tables, and responds to table requests.                     |
| Kitchen Staff                     | Angular Admin        | Prepares food and updates cooking progress.                                             |
| Restaurant Manager                | Angular Admin        | Configures menus, tables, staff, and restaurant settings.                               |
| Platform Administrator *(Future)* | Platform Admin       | Manages tenants, subscriptions, and platform-wide operations.                           |

---

# 4. Persona Goals

## Customer

Goals:

* Scan a QR code.
* Browse the menu quickly.
* Place one or more orders.
* Track order status in real time.
* Request waiter assistance if needed.

Success means:

> "I ordered without waiting for a waiter."

---

## Waiter

Goals:

* Monitor active tables.
* Respond to assistance requests.
* Help resolve customer issues.
* Coordinate with the kitchen.

Success means:

> "Customers receive fast assistance."

---

## Kitchen Staff

Goals:

* Receive new orders instantly.
* Prepare food efficiently.
* Update order progress.
* Minimize preparation delays.

Success means:

> "Every order moves smoothly from Pending to Served."

---

## Restaurant Manager

Goals:

* Configure restaurant operations.
* Maintain menus.
* Manage staff.
* Monitor daily operations.

Success means:

> "The restaurant runs smoothly with minimal operational overhead."

---

## Platform Administrator (Future)

Goals:

* Manage restaurant tenants.
* Monitor platform health.
* Manage subscriptions.
* Resolve tenant-level issues.

Success means:

> "The platform remains healthy, secure, and scalable."

---

# 5. Persona Responsibilities

| Persona | Primary Responsibility |
|----------|------------------------|
| Customer | Browse menus and place orders. |
| Waiter | Assist customers and coordinate table operations. |
| Kitchen Staff | Prepare orders and update preparation progress. |
| Restaurant Manager | Configure restaurant operations and manage staff. |
| Platform Administrator *(Future)* | Operate and maintain the ScanServe platform. |

---

# 6. Customer Journey

```text
Enter Restaurant
        ↓
Locate Table
        ↓
Scan Table QR Code
        ↓
Create Customer Session
        ↓
Browse Menu
        ↓
Add Items to Cart
        ↓
Submit Order
        ↓
Track Order Status
        ↓
Receive Food
        ↓
(Optional) Place Additional Orders
        ↓
Table Session Ends
```

---

# 7. Waiter Journey

```text
Login
        ↓
Open Dashboard
        ↓
Monitor Active Tables
        ↓
Receive Customer Request
        ↓
Assist Customer
        ↓
Update Table Status (if required)
        ↓
Continue Monitoring
```

---

# 8. Kitchen Journey

```text
Login
        ↓
Open Kitchen Queue
        ↓
Receive New Order
        ↓
Accept Order
        ↓
Prepare Order
        ↓
Mark Ready
        ↓
Mark Served
```

---

# 9. Restaurant Manager Journey

```text
Login
        ↓
Open Dashboard
        ↓
Manage Menu
        ↓
Manage Tables
        ↓
Manage Staff
        ↓
Review Operations
```

---

# 10. Touchpoints

## Flutter Customer PWA

Supports:

* QR entry
* Menu browsing
* Cart
* Ordering
* Order tracking
* Waiter requests

---

## Angular Admin

Supports:

* Kitchen queue
* Table monitoring
* Menu management
* Restaurant administration
* Operational management

---

## Firebase Platform

Supports:

* Authentication
* Data persistence
* Real-time synchronization
* Business logic
* Notifications

---

# 11. Journey Principles

All user journeys should follow these principles:

* Minimize the number of steps.
* Provide immediate feedback.
* Support real-time updates where valuable.
* Recover gracefully from failures.
* Keep the experience intuitive for first-time users.

---

# 12. User Experience Principles

## Customer

* No account required.
* No application installation.
* QR scan to menu within seconds.
* Clear order status.
* Minimal friction.

---

## Restaurant Staff

* Operational information first.
* Fast interactions.
* Minimal clicks.
* Live updates.
* Clear prioritization.

---

# 13. Future Personas

Future platform growth may introduce:

* Delivery Driver
* Cashier
* Franchise Owner
* Corporate Administrator
* Customer (Authenticated)
* POS Operator

These personas should extend the existing architecture without changing established business concepts.

---

# 14. Guiding Principle

Every feature added to ScanServe must solve a real problem for at least one defined persona.

Technology decisions should always support user goals rather than introduce unnecessary complexity.
