# 9. Menu Indexes

Menu-related collections are primarily read by the Customer PWA.

Indexes should optimize browsing performance.

---

## IDX-001 — Active Menus

Collection

```
menus
```

Purpose

Load the currently active Menu.

Filter

* isActive

Sort

* updatedAt DESC

Consumers

* Flutter Customer PWA

---

## IDX-002 — Categories by Menu

Collection

```
categories
```

Purpose

Load Categories belonging to a Menu.

Filter

* menuId

Sort

* displayOrder ASC

Consumers

* Flutter Customer PWA
* Angular Dashboard

---

## IDX-003 — Menu Items by Category

Collection

```
menuItems
```

Purpose

Load Menu Items for a Category.

Filter

* categoryId
* isAvailable

Sort

* displayOrder ASC

Consumers

* Flutter Customer PWA

---

# 10. Order Indexes

Orders are the most frequently queried business collection.

Indexes should prioritize operational workflows.

---

## IDX-101 — Customer Orders

Collection

```
orders
```

Purpose

Load Orders belonging to a Customer Session.

Filter

* customerSessionId

Sort

* createdAt DESC

Consumers

* Flutter Customer PWA

---

## IDX-102 — Kitchen Queue

Collection

```
orders
```

Purpose

Load active kitchen workload.

Filter

* status

Sort

* createdAt ASC

Consumers

* Angular Dashboard

---

## IDX-103 — Daily Orders

Collection

```
orders
```

Purpose

Load Restaurant Orders for a business day.

Filter

* businessDate

Sort

* createdAt DESC

Consumers

* Angular Dashboard

---

## IDX-104 — Orders by Table

Collection

```
orders
```

Purpose

Display Orders associated with a Table.

Filter

* tableId

Sort

* createdAt DESC

Consumers

* Angular Dashboard

---

# 11. Session Indexes

Sessions support customer dining workflows.

---

## IDX-201 — Active Table Sessions

Collection

```
tableSessions
```

Purpose

Load active dining sessions.

Filter

* tableId
* isActive

Sort

* startedAt DESC

Consumers

* Flutter Customer PWA
* Angular Dashboard

---

## IDX-202 — Customer Sessions

Collection

```
customerSessions
```

Purpose

Load active Customer Sessions.

Filter

* tableSessionId

Sort

* createdAt ASC

Consumers

* Angular Dashboard

---

# 12. Staff Indexes

Staff queries primarily support administration.

---

## IDX-301 — Restaurant Staff

Collection

```
staff
```

Purpose

Load Staff members.

Filter

* restaurantId

Sort

* displayName ASC

Consumers

* Angular Dashboard

---

## IDX-302 — Staff by Role

Collection

```
staff
```

Purpose

Load Staff assigned to a Role.

Filter

* roleId

Sort

* displayName ASC

Consumers

* Angular Dashboard

---

# 13. Waiter Request Indexes

Waiter Requests support operational workflows.

---

## IDX-401 — Active Waiter Requests

Collection

```
waiterRequests
```

Purpose

Display pending customer requests.

Filter

* status

Sort

* createdAt ASC

Consumers

* Angular Dashboard

---

## IDX-402 — Table Waiter Requests

Collection

```
waiterRequests
```

Purpose

Display requests originating from a specific Table.

Filter

* tableId

Sort

* createdAt DESC

Consumers

* Angular Dashboard

---

# 14. Analytics Indexes

Analytics queries are primarily executed by backend services.

---

## IDX-501 — Daily Analytics

Collection

```
analytics
```

Purpose

Load Restaurant analytics for a business day.

Filter

* businessDate

Sort

* createdAt DESC

Consumers

* Cloud Functions

---

## IDX-502 — Restaurant Analytics

Collection

```
analytics
```

Purpose

Load analytics for a Restaurant.

Filter

* restaurantId

Sort

* businessDate DESC

Consumers

* Angular Dashboard