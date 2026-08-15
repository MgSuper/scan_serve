# 14. Table Session Collection

A Table Session represents a single dining occasion at a physical table.

It begins when the first customer scans the table QR code and ends when the restaurant closes the session or it expires automatically.

A Table Session groups one or more Customer Sessions into a single restaurant visit.

---

## Collection

```
tableSessions
```

---

## Ownership

Restaurant

---

## Lifecycle

```text
Created
    ↓
Active
    ↓
Completed
    ↓
Archived
```

Only one active Table Session may exist for a table at any given time.

---

## Document Structure

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Table Session identifier. |
| restaurantId | String | ✓ | Owning restaurant. |
| branchId | String | ✓ | Owning branch. |
| tableId | String | ✓ | Associated table. |
| status | String | ✓ | Session status. |
| customerCount | Number | ✓ | Active customer sessions. |
| startedAt | Timestamp | ✓ | Session start time. |
| endedAt | Timestamp | | Session end time. |
| expiresAt | Timestamp | ✓ | Automatic expiration time. |
| createdAt | Timestamp | ✓ | Creation timestamp. |
| updatedAt | Timestamp | ✓ | Last update timestamp. |

---

## Status Values

```
ACTIVE
COMPLETED
EXPIRED
```

---

## Owns

None.

Table Sessions coordinate Customer Sessions but do not own them physically.

---

## References

Referenced by:

* Customer Sessions
* Orders

---

## Frequently Queried By

* Customer PWA
* Angular Dashboard
* Cloud Functions

---

## Lifecycle Notes

A Table Session should remain active while customers continue ordering.

Cloud Functions periodically close expired sessions after inactivity.

Historical sessions should remain available for reporting.

---

# 15. Customer Session Collection

A Customer Session represents one customer's interaction with the restaurant.

Every customer scanning the table QR code receives an independent Customer Session.

Multiple Customer Sessions may belong to the same Table Session.

Each Customer Session owns exactly one Cart.

Orders remain independent after submission.

---

## Collection

```
customerSessions
```

---

## Ownership

Restaurant

---

## Lifecycle

```text
Created
    ↓
Active
    ↓
Inactive
    ↓
Expired
```

---

## Document Structure

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Customer Session identifier. |
| restaurantId | String | ✓ | Owning restaurant. |
| branchId | String | ✓ | Owning branch. |
| tableId | String | ✓ | Associated table. |
| tableSessionId | String | ✓ | Parent Table Session. |
| languageCode | String | | Preferred language. |
| deviceId | String | | Anonymous device identifier. |
| status | String | ✓ | Session status. |
| lastActivityAt | Timestamp | ✓ | Last customer activity. |
| expiresAt | Timestamp | ✓ | Automatic expiration. |
| createdAt | Timestamp | ✓ | Creation timestamp. |
| updatedAt | Timestamp | ✓ | Last update timestamp. |

---

## Status Values

```
ACTIVE
INACTIVE
EXPIRED
```

---

## Owns

* Cart

---

## References

Referenced by:

* Orders

---

## Frequently Queried By

* Customer PWA
* Cloud Functions

---

## Lifecycle Notes

Customer Sessions are anonymous.

Authentication is intentionally not required in Version 1.

Future customer accounts should reference Customer Sessions rather than replace them.

---

# 16. Cart Collection

The Cart represents a customer's current selection before checkout.

Every Customer Session owns exactly one Cart.

The Cart is mutable until an Order is submitted.

After successful checkout, the Cart is cleared while remaining associated with the Customer Session.

---

## Collection

```
carts
```

---

## Ownership

Customer Session

---

## Lifecycle

```text
Created
    ↓
Updated
    ↓
Submitted
    ↓
Cleared
```

---

## Document Structure

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Cart identifier. |
| restaurantId | String | ✓ | Owning restaurant. |
| branchId | String | ✓ | Owning branch. |
| tableId | String | ✓ | Associated table. |
| tableSessionId | String | ✓ | Parent Table Session. |
| customerSessionId | String | ✓ | Owning Customer Session. |
| items | Array | ✓ | Current cart items. |
| subtotal | Number | ✓ | Calculated subtotal. |
| totalQuantity | Number | ✓ | Total item quantity. |
| updatedAt | Timestamp | ✓ | Last modification time. |
| createdAt | Timestamp | ✓ | Creation timestamp. |

---

## Cart Item Structure

Each item inside the Cart contains a lightweight snapshot of the selected Menu Item.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| menuItemId | String | ✓ | Selected Menu Item. |
| name | String | ✓ | Product name snapshot. |
| unitPrice | Number | ✓ | Price at selection time. |
| quantity | Number | ✓ | Ordered quantity. |
| note | String | | Customer note. |
| modifiers | Array | | Future support for modifiers. |

---

## Frequently Queried By

* Customer PWA

---

## Lifecycle Notes

The Cart is temporary.

It should never be considered the source of truth for historical purchases.

Once an Order is successfully created:

* Order data becomes immutable.
* Cart contents may be cleared.
* Customer Session remains active for additional orders.

---

# 17. Session Relationships

The following diagram illustrates the relationship between session entities.

```text
Restaurant
    │
    └── Branch
            │
            └── Table
                    │
                    └── Table Session
                            │
            ┌───────────────┴───────────────┐
            │                               │
    Customer Session                Customer Session
            │                               │
            │                               │
          Cart                            Cart
            │                               │
            └───────────────┬───────────────┘
                            │
                         Orders
```

The separation between Table Session and Customer Session allows groups of customers to order independently while remaining associated with the same dining visit.