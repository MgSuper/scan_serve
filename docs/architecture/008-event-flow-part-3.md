# 11. Platform Event Flow

Platform Events are generated automatically by the ScanServe backend.

Unlike Customer or Staff Events, Platform Events are not initiated directly by users.

Platform Events maintain platform health, enforce business policies, and perform asynchronous operations.

---

## EF-201 — Session Cleanup

### Trigger

Scheduled Cloud Function.

---

### Flow

```text
Scheduled Trigger
        │
        ▼
Find Expired Table Sessions
        │
        ▼
Find Expired Customer Sessions
        │
        ▼
Archive Session
        │
        ▼
Update Firestore
```

---

### Generated Events

* Table Session Expired
* Customer Session Expired

---

### Updated Documents

* tableSessions
* customerSessions

---

## EF-202 — Notification Dispatch

### Trigger

Business event requiring user notification.

Examples:

* Order Created
* Order Ready
* Waiter Requested

---

### Flow

```text
Business Event
        │
        ▼
Cloud Function
        │
        ▼
Generate Notification
        │
        ▼
Dispatch Notification
```

Notification delivery should never block the originating business process.

---

## EF-203 — Analytics Collection

### Trigger

Successful completion of significant business events.

Examples include:

* Customer Session Created
* Order Submitted
* Order Served
* Menu Published

---

### Flow

```text
Business Event
        │
        ▼
Cloud Function
        │
        ▼
Generate Analytics Event
        │
        ▼
Persist Analytics
```

Analytics collection should always execute asynchronously.

---

# 12. Order Lifecycle

The Order lifecycle is the most important business state machine within ScanServe.

```text
Customer
    │
    ▼
Submit Order
    │
    ▼
PENDING
    │
    ▼
ACCEPTED
    │
    ▼
PREPARING
    │
    ▼
READY
    │
    ▼
SERVED
```

Optional future transitions:

```text
PENDING
    │
    └────────► CANCELLED
```

Order lifecycle transitions should be strictly validated.

Invalid state transitions must be rejected.

Example:

```
PENDING
    │
    └──────► READY
```

This transition is invalid because the Order must first be accepted and prepared.

---

# 13. Event Dependencies

Business events often depend upon successful completion of previous events.

Examples include:

| Event | Depends On |
|--------|------------|
| Customer Session Created | QR Scan |
| Cart Created | Customer Session Created |
| Order Created | Cart Updated |
| Kitchen Notification | Order Created |
| Order Ready | Order Accepted |
| Order Served | Order Ready |

Dependencies should remain explicit to avoid inconsistent business state.

---

# 14. Event Failure Handling

Not every business event succeeds.

Failures should leave the platform in a consistent state.

---

## Validation Failure

Examples:

* Invalid QR Code
* Inactive Table
* Empty Cart
* Menu Item Unavailable

Result:

* Reject request.
* Persist nothing.
* Return descriptive error.

---

## Authorization Failure

Examples:

* Invalid Role
* Cross-Tenant Access
* Unauthorized Operation

Result:

* Reject request.
* Log security event.
* Return permission error.

---

## Infrastructure Failure

Examples:

* Firestore unavailable
* Cloud Function timeout
* Network interruption

Result:

* Retry where appropriate.
* Never partially complete business operations.

---

# 15. Retry Strategy

Retries should occur only for transient failures.

Suitable retry scenarios include:

* Cloud Function timeout
* Notification dispatch
* Analytics collection

Business transactions such as Order creation should never be executed twice.

Idempotent operations should use unique identifiers to prevent duplicate processing.

---

# 16. Event Sequence Matrix

The following table summarizes primary business event ownership.

| Event | Producer | Processor | Consumers |
|--------|----------|-----------|-----------|
| QR Scan | Customer PWA | Customer PWA | Firestore |
| Customer Session Created | Customer PWA | Firestore | Customer PWA |
| Cart Updated | Customer PWA | Firestore | Customer PWA |
| Order Submitted | Customer PWA | Cloud Functions | Firestore, Angular |
| Order Accepted | Angular | Firestore | Customer PWA |
| Order Prepared | Angular | Firestore | Customer PWA |
| Order Served | Angular | Firestore | Customer PWA |
| Waiter Requested | Customer PWA | Firestore | Angular |
| Session Cleanup | Cloud Functions | Firestore | — |
| Notification Dispatch | Cloud Functions | Notification Service | Customer / Staff |

---

# 17. Event Consistency

ScanServe follows an event-driven architecture built on Firestore's real-time capabilities.

The platform favors eventual consistency where immediate consistency is unnecessary.

Examples:

* Analytics
* Notifications
* Session Cleanup

Business-critical operations requiring strong consistency include:

* Order Creation
* Order Status Updates
* Staff Role Assignment

These operations should execute within controlled transactional boundaries.

---

# 18. Guiding Principle

Business events represent the evolution of the ScanServe platform over time.

Every event should:

* Have one authoritative producer.
* Follow a predictable lifecycle.
* Produce a valid business state.
* Be observable through Firestore.
* Maintain tenant isolation.
* Preserve historical accuracy.

Client applications initiate events.

Trusted backend components validate and execute them.
