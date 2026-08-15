# 10. Restaurant Collection

The `restaurants` collection represents the highest level of business ownership within the ScanServe platform.

Every restaurant is an independent tenant.

All restaurant-owned resources inherit their ownership from this entity.

---

## Collection

```
restaurants
```

---

## Ownership

Platform

---

## Lifecycle

```text
Created
    ↓
Active
    ↓
Updated
    ↓
Archived (optional)
```

Restaurants are never physically deleted during normal platform operation.

---

## Document Structure

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Restaurant identifier. |
| name | String | ✓ | Restaurant name. |
| description | String | | Public description. |
| logoUrl | String | | Restaurant logo. |
| phone | String | | Contact phone number. |
| email | String | | Contact email. |
| website | String | | Website URL. |
| isActive | Boolean | ✓ | Restaurant availability. |
| createdAt | Timestamp | ✓ | Creation time. |
| updatedAt | Timestamp | ✓ | Last update time. |
| createdBy | String | | Platform administrator. |
| updatedBy | String | | Platform administrator. |

---

## Owns

* Branches
* Tables
* Table Sessions
* Customer Sessions
* Menus
* Categories
* Menu Items
* Orders
* Order Items
* Staff
* Roles

---

## Frequently Queried By

* Customer PWA
* Angular Dashboard
* Cloud Functions

---

# 11. Branch Collection

Branches represent physical restaurant locations.

Every customer visit belongs to exactly one branch.

---

## Collection

```
branches
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
Updated
    ↓
Archived
```

Branches should not be deleted once operational data exists.

---

## Document Structure

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Branch identifier. |
| restaurantId | String | ✓ | Owning restaurant. |
| name | String | ✓ | Branch name. |
| code | String | | Internal branch code. |
| address | String | ✓ | Physical address. |
| phone | String | | Contact phone. |
| timezone | String | ✓ | Business timezone. |
| currency | String | ✓ | Operating currency. |
| openingHours | Map | | Weekly schedule. |
| isActive | Boolean | ✓ | Branch availability. |
| createdAt | Timestamp | ✓ | Creation timestamp. |
| updatedAt | Timestamp | ✓ | Last update timestamp. |

---

## Owns

* Tables
* Table Sessions
* Customer Sessions
* Menus
* Categories
* Menu Items
* Orders
* Order Items
* Staff

---

## Frequently Queried By

* Customer PWA
* Angular Dashboard

---

# 12. Table Collection

Tables represent physical dining locations inside a branch.

Each table is identified by a unique QR code.

A table may participate in many Table Sessions during its lifetime.

Only one active Table Session may exist at any time.

---

## Collection

```
tables
```

---

## Ownership

Branch

---

## Lifecycle

```text
Created
    ↓
Active
    ↓
Disabled
    ↓
Archived
```

Tables should rarely be deleted.

Historical orders reference tables permanently.

---

## Document Structure

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Table identifier. |
| restaurantId | String | ✓ | Owning restaurant. |
| branchId | String | ✓ | Owning branch. |
| displayNumber | String | ✓ | Human-readable table number. |
| qrCode | String | ✓ | QR identifier or token. |
| capacity | Number | | Seating capacity. |
| status | String | ✓ | Operational status. |
| isActive | Boolean | ✓ | Availability. |
| createdAt | Timestamp | ✓ | Creation timestamp. |
| updatedAt | Timestamp | ✓ | Last update timestamp. |

---

## Status Values

```
ACTIVE
DISABLED
MAINTENANCE
```

---

## References

A table may be referenced by:

* Table Sessions
* Orders
* Customer Sessions

The table never owns these documents directly.

Ownership remains at the Restaurant level.

---

## Frequently Queried By

* Customer PWA
* Angular Dashboard
* Cloud Functions

---

# 13. Session Domain

The Session domain represents a customer's visit to the restaurant.

Unlike physical entities such as Restaurants or Tables, session documents are temporary.

They are created when customers begin interacting with the restaurant and automatically expire after the visit ends.

The Session domain consists of:

* Table Sessions
* Customer Sessions
* Carts

These entities coordinate the customer ordering experience while maintaining a clear separation between shared table activity and individual customer activity.

Session documents have the shortest lifecycle of all primary business entities and require periodic cleanup by Cloud Functions.