# 9. Callable Functions

Callable Functions are invoked directly by client applications.

They execute business-critical operations requiring trusted backend validation.

Every Callable Function should:

* Authenticate the caller when required.
* Validate the request payload.
* Validate tenant ownership.
* Validate business rules.
* Execute the requested operation.
* Return a standardized response.

---

## Customer Functions

### CF-001 — Start Dining Session

Purpose

Create or join an active Table Session and initialize a Customer Session.

Triggered By

* Flutter Customer PWA

Responsibilities

* Validate QR payload.
* Validate Restaurant.
* Validate Branch.
* Validate Table.
* Find or create active Table Session.
* Create Customer Session.
* Create Cart.

Returns

* Customer Session
* Table Session
* Cart

---

### CF-002 — Submit Order

Purpose

Create a new Order from the Customer's Cart.

Triggered By

* Flutter Customer PWA

Responsibilities

* Validate Customer Session.
* Validate Cart.
* Validate Menu Items.
* Calculate totals.
* Create Order.
* Create Order Items.
* Clear Cart.

Returns

* Order Summary

---

### CF-003 — Call Waiter

Purpose

Create a waiter assistance request.

Triggered By

* Flutter Customer PWA

Responsibilities

* Validate Customer Session.
* Validate Table.
* Create Waiter Request.
* Notify Restaurant Staff.

Returns

* Success status

---

## Restaurant Functions

### CF-101 — Update Order Status

Purpose

Update the lifecycle status of an Order.

Triggered By

* Angular Dashboard

Responsibilities

* Validate Staff.
* Validate Restaurant ownership.
* Validate status transition.
* Update Order.
* Record timestamps.

Returns

* Updated Order

---

### CF-102 — Publish Menu

Purpose

Publish a Menu for customer ordering.

Triggered By

* Angular Dashboard

Responsibilities

* Validate Restaurant Manager.
* Validate Menu.
* Activate Menu.
* Deactivate previous active Menu.

Returns

* Active Menu

---

### CF-103 — Invite Staff

Purpose

Create a new Staff account.

Triggered By

* Angular Dashboard

Responsibilities

* Validate permissions.
* Create Staff document.
* Initialize Staff profile.

Returns

* Staff Summary

---

# 10. Firestore Trigger Functions

Firestore Trigger Functions react to document changes.

Clients never invoke these functions directly.

---

## TF-001 — Order Created

Trigger

```
orders
```

Responsibilities

* Notify Kitchen.
* Generate analytics event.
* Update operational metrics.

---

## TF-002 — Order Updated

Trigger

```
orders
```

Responsibilities

* Detect status changes.
* Notify Customer.
* Record analytics.

---

## TF-003 — Staff Created

Trigger

```
staff
```

Responsibilities

* Initialize default preferences.
* Generate audit event.

---

## TF-004 — Menu Published

Trigger

```
menus
```

Responsibilities

* Refresh cached menu state.
* Record operational metrics.

---

# 11. Scheduled Functions

Scheduled Functions execute automatically.

---

## SF-001 — Session Cleanup

Frequency

Periodic

Responsibilities

* Close expired Table Sessions.
* Expire Customer Sessions.
* Archive inactive data.

---

## SF-002 — Analytics Aggregation

Frequency

Periodic

Responsibilities

* Aggregate operational metrics.
* Generate reporting data.

---

## SF-003 — Platform Health Check

Frequency

Periodic

Responsibilities

* Verify backend availability.
* Verify Firestore connectivity.
* Record system health.

---

# 12. Repository Layer

Repositories isolate Firestore operations from business logic.

Responsibilities include:

* Reading Firestore documents.
* Writing Firestore documents.
* Transaction handling.
* Query execution.

Repositories should not contain business rules.

Examples:

```
OrderRepository

MenuRepository

SessionRepository

StaffRepository
```

---

# 13. Transaction Strategy

Transactions should be used only when multiple documents must remain consistent.

Recommended transaction boundaries include:

* Submit Order
* Publish Menu
* Assign Role

Transactions should remain:

* Small
* Fast
* Deterministic

Long-running operations should execute outside transactions.

---

# 14. Batch Operations

Batch writes should be used when atomic consistency is unnecessary.

Examples:

* Archive Menu Items.
* Update display order.
* Bulk availability changes.
* Initial Restaurant setup.

Batch operations should remain within Firestore limits.

---

# 15. Error Handling

Functions should return standardized application errors.

Categories include:

* Validation failures.
* Authorization failures.
* Business rule violations.
* Infrastructure failures.

Internal implementation details should never be exposed to clients.

Unexpected failures should be logged for investigation.