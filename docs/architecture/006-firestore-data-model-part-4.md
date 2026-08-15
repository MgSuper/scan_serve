# 18. Menu Domain

The Menu domain defines the products available for customer ordering.

Menu entities are relatively stable compared to session and ordering data.

Changes are performed by restaurant staff through the Angular Administration Dashboard.

The Menu domain consists of:

* Menus
* Categories
* Menu Items

---

# 19. Menu Collection

A Menu represents a collection of categories available for ordering.

Version 1 supports one active menu per branch.

The data model allows future support for multiple menus such as breakfast, lunch, dinner, or seasonal menus.

---

## Collection

```
menus
```

---

## Ownership

Branch

---

## Lifecycle

```text
Created
    ↓
Published
    ↓
Updated
    ↓
Archived
```

---

## Document Structure

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Menu identifier. |
| restaurantId | String | ✓ | Owning restaurant. |
| branchId | String | ✓ | Owning branch. |
| name | String | ✓ | Menu name. |
| description | String | | Menu description. |
| isActive | Boolean | ✓ | Indicates whether customers can use this menu. |
| createdAt | Timestamp | ✓ | Creation timestamp. |
| updatedAt | Timestamp | ✓ | Last modification timestamp. |

---

## Owns

* Categories

---

## Frequently Queried By

* Customer PWA
* Angular Dashboard

---

# 20. Category Collection

Categories organize Menu Items into logical groups.

Examples include:

* Coffee
* Tea
* Dessert
* Smoothies

---

## Collection

```
categories
```

---

## Ownership

Menu

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

---

## Document Structure

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Category identifier. |
| restaurantId | String | ✓ | Owning restaurant. |
| branchId | String | ✓ | Owning branch. |
| menuId | String | ✓ | Parent menu. |
| name | String | ✓ | Category name. |
| description | String | | Description. |
| displayOrder | Number | ✓ | Display sequence. |
| isActive | Boolean | ✓ | Visibility status. |
| createdAt | Timestamp | ✓ | Creation timestamp. |
| updatedAt | Timestamp | ✓ | Last update timestamp. |

---

## Owns

* Menu Items

---

## Frequently Queried By

* Customer PWA
* Angular Dashboard

---

# 21. Menu Item Collection

A Menu Item represents an orderable product.

Examples include:

* Cappuccino
* Americano
* Matcha Latte
* Cheesecake

Menu Items are editable by restaurant staff.

Historical Orders must never depend on the current Menu Item document.

---

## Collection

```
menuItems
```

---

## Ownership

Category

---

## Lifecycle

```text
Created
    ↓
Available
    ↓
Unavailable
    ↓
Archived
```

---

## Document Structure

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Menu Item identifier. |
| restaurantId | String | ✓ | Owning restaurant. |
| branchId | String | ✓ | Owning branch. |
| menuId | String | ✓ | Parent menu. |
| categoryId | String | ✓ | Parent category. |
| name | String | ✓ | Product name. |
| description | String | | Product description. |
| imageUrl | String | | Product image. |
| price | Number | ✓ | Selling price. |
| displayOrder | Number | ✓ | Display sequence. |
| isAvailable | Boolean | ✓ | Customer visibility. |
| createdAt | Timestamp | ✓ | Creation timestamp. |
| updatedAt | Timestamp | ✓ | Last update timestamp. |

---

## References

Referenced by:

* Cart Items
* Order Items

Menu Items never own business transactions.

---

## Frequently Queried By

* Customer PWA
* Angular Dashboard

---

# 22. Ordering Domain

The Ordering domain represents the core business transaction of the ScanServe platform.

Unlike Menu entities, Orders are immutable after successful submission.

Historical accuracy takes precedence over normalization.

The Ordering domain consists of:

* Orders
* Order Items

---

# 23. Order Collection

An Order represents a customer's confirmed purchase request.

Orders are created only after successful business validation.

Once submitted, business information should remain immutable.

Only lifecycle status fields may change.

---

## Collection

```
orders
```

---

## Ownership

Restaurant

---

## Lifecycle

```text
Created
    ↓
Pending
    ↓
Accepted
    ↓
Preparing
    ↓
Ready
    ↓
Served
```

---

## Document Structure

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | ✓ | Order identifier. |
| restaurantId | String | ✓ | Owning restaurant. |
| branchId | String | ✓ | Owning branch. |
| tableId | String | ✓ | Associated table. |
| tableSessionId | String | ✓ | Parent Table Session. |
| customerSessionId | String | ✓ | Customer Session. |
| status | String | ✓ | Current order status. |
| subtotal | Number | ✓ | Order subtotal. |
| total | Number | ✓ | Final total. |
| totalQuantity | Number | ✓ | Total purchased items. |
| customerNote | String | | Optional customer note. |
| submittedAt | Timestamp | ✓ | Submission time. |
| acceptedAt | Timestamp | | Kitchen acceptance time. |
| preparedAt | Timestamp | | Preparation completed. |
| servedAt | Timestamp | | Served to customer. |
| createdAt | Timestamp | ✓ | Creation timestamp. |
| updatedAt | Timestamp | ✓ | Last update timestamp. |

---

## Status Values

```
PENDING
ACCEPTED
PREPARING
READY
SERVED
CANCELLED
```

---

## Owns

* Order Items

---

## Frequently Queried By

* Customer PWA
* Angular Dashboard
* Cloud Functions

---

## Design Notes

Orders should never be edited after submission.

Only lifecycle status fields may change.

Business information such as totals and purchased items should remain immutable.

This guarantees accurate historical reporting and simplifies auditing.