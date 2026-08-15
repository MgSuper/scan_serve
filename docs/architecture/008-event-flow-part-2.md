# 8. Customer Journey Event Flow

This section defines the sequence of business events initiated by customers.

---

## EF-001 — QR Code Scan

### Trigger

Customer scans a table QR code.

---

### Flow

```text
Customer
        │
        ▼
Scan QR Code
        │
        ▼
Parse QR Payload
        │
        ▼
Validate Restaurant
        │
        ▼
Validate Branch
        │
        ▼
Validate Table
        │
        ▼
Find Active Table Session
        │
        │
        ├───────────────┐
        │               │
        ▼               ▼
Session Exists     Create Session
        │               │
        └───────┬───────┘
                │
                ▼
Create Customer Session
                │
                ▼
Create Cart
                │
                ▼
Load Active Menu
                │
                ▼
Customer Ready
```

---

### Generated Events

* Table Session Created *(optional)*
* Customer Session Created
* Cart Created

---

### Updated Documents

* tableSessions *(optional)*
* customerSessions
* carts

---

## EF-002 — Browse Menu

### Trigger

Customer enters the application.

---

### Flow

```text
Customer
        │
        ▼
Load Active Menu
        │
        ▼
Load Categories
        │
        ▼
Load Menu Items
        │
        ▼
Render Menu
```

---

### Generated Events

None.

Menu browsing is read-only.

---

### Updated Documents

None.

---

## EF-003 — Cart Update

### Trigger

Customer modifies Cart.

---

### Flow

```text
Customer
        │
        ▼
Add / Remove Item
        │
        ▼
Validate Menu Item
        │
        ▼
Recalculate Totals
        │
        ▼
Update Cart
        │
        ▼
Realtime Sync
```

---

### Generated Events

* Cart Updated

---

### Updated Documents

* carts

---

## EF-004 — Submit Order

### Trigger

Customer presses **Place Order**.

---

### Flow

```text
Customer
        │
        ▼
Callable Cloud Function
        │
        ▼
Validate Customer Session
        │
        ▼
Validate Cart
        │
        ▼
Validate Menu Items
        │
        ▼
Calculate Totals
        │
        ▼
Create Order
        │
        ▼
Create Order Items
        │
        ▼
Clear Cart
        │
        ▼
Notify Kitchen
        │
        ▼
Realtime Sync
```

---

### Generated Events

* Order Created
* Order Items Created
* Cart Cleared
* Kitchen Notified

---

### Updated Documents

* orders
* orderItems
* carts

---

## EF-005 — Track Order

### Trigger

Order status changes.

---

### Flow

```text
Kitchen Updates Order
            │
            ▼
Firestore Updated
            │
            ▼
Realtime Listener
            │
            ▼
Customer UI Updated
```

---

### Generated Events

* Order Status Changed

---

### Updated Documents

* orders

---

# 9. Restaurant Operations Event Flow

This section defines operational events initiated by restaurant staff.

---

## EF-101 — Kitchen Accepts Order

### Trigger

Kitchen Staff accepts a new order.

---

### Flow

```text
Kitchen Dashboard
        │
        ▼
Select Order
        │
        ▼
Update Status
        │
        ▼
Firestore
        │
        ▼
Realtime Sync
```

---

### Status Transition

```text
PENDING
    ↓
ACCEPTED
```

---

### Updated Documents

* orders

---

## EF-102 — Kitchen Preparation

### Trigger

Kitchen begins preparing an order.

---

### Status Transition

```text
ACCEPTED
    ↓
PREPARING
    ↓
READY
```

---

### Generated Events

* Preparation Started
* Preparation Completed

---

### Updated Documents

* orders

---

## EF-103 — Order Served

### Trigger

Restaurant staff serve the completed order.

---

### Status Transition

```text
READY
    ↓
SERVED
```

---

### Generated Events

* Order Served

---

### Updated Documents

* orders

---

## EF-104 — Customer Calls Waiter

### Trigger

Customer presses **Call Waiter**.

---

### Flow

```text
Customer
        │
        ▼
Create Waiter Request
        │
        ▼
Firestore
        │
        ▼
Realtime Listener
        │
        ▼
Angular Dashboard
        │
        ▼
Waiter Responds
```

---

### Generated Events

* Waiter Requested

---

### Updated Documents

* waiterRequests *(future collection)*

---

# 10. Administration Event Flow

Restaurant Managers initiate configuration events.

Examples include:

* Publish Menu
* Archive Menu
* Create Table
* Disable Table
* Invite Staff
* Assign Role

These events primarily affect configuration data and typically do not require real-time synchronization for customers.
