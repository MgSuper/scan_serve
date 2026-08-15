# 13. Menu Collection Rules

The Menu domain contains public information required by customers.

Customers should be able to browse active menus without authentication.

Business management operations remain restricted to authorized staff.

---

## Menus

Collection:

```
menus
```

### Read

Allowed:

* Customer
* Staff

Only active menus should be visible to customers.

---

### Create

Allowed:

* Restaurant Manager

---

### Update

Allowed:

* Restaurant Manager

---

### Delete

Not permitted.

Menus should be archived rather than deleted.

---

## Categories

Collection:

```
categories
```

### Read

Allowed:

* Customer
* Staff

---

### Create

Allowed:

* Restaurant Manager

---

### Update

Allowed:

* Restaurant Manager

---

### Delete

Not permitted.

---

## Menu Items

Collection:

```
menuItems
```

### Read

Allowed:

* Customer
* Staff

Only available Menu Items should be visible to customers.

---

### Create

Allowed:

* Restaurant Manager

---

### Update

Allowed:

* Restaurant Manager

---

### Delete

Not permitted.

Menu Items should be archived to preserve historical references.

---

# 14. Order Collection Rules

Orders represent completed business transactions.

Order creation is one of the most security-sensitive operations within the platform.

---

## Collection

```
orders
```

---

## Read

Allowed:

Customer:

* Own Orders only.

Staff:

* Orders belonging to their Restaurant.

Platform:

* Full access.

---

## Create

Allowed:

* Cloud Functions only.

Customers must never create Order documents directly.

---

## Update

Allowed:

Kitchen Staff:

* Order status.

Restaurant Manager:

* Operational fields where applicable.

Cloud Functions:

* Backend-managed fields.

Customers must never modify submitted Orders.

---

## Delete

Not permitted.

Orders are permanent business records.

---

# 15. Order Item Collection Rules

Order Items are immutable historical records.

---

## Collection

```
orderItems
```

---

## Read

Allowed:

* Order owner.
* Restaurant Staff.
* Platform.

---

## Create

Allowed:

* Cloud Functions only.

---

## Update

Not permitted.

---

## Delete

Not permitted.

Order Items must remain immutable after creation.

---

# 16. Staff Collection Rules

Staff information contains sensitive operational data.

---

## Collection

```
staff
```

---

## Read

Allowed:

* Restaurant Manager.
* Authorized Staff.

Staff should never access another Restaurant's employees.

---

## Create

Allowed:

* Restaurant Manager.

---

## Update

Allowed:

* Restaurant Manager.

Staff members must never modify their own permissions.

---

## Delete

Not permitted.

Staff should instead be disabled or archived.

---

# 17. Role Collection Rules

Roles define authorization.

Role modification is considered a privileged operation.

---

## Collection

```
roles
```

---

## Read

Allowed:

* Authenticated Staff.

---

## Create

Allowed:

* Restaurant Manager.

---

## Update

Allowed:

* Restaurant Manager.

---

## Delete

Not permitted.

Historical Staff records may reference existing Roles.

---

# 18. Ownership Validation

Every protected document should validate ownership.

Typical ownership fields include:

```
restaurantId
branchId
tableId
customerSessionId
```

Authorization should first verify:

* Authentication.
* Restaurant ownership.
* Business ownership.
* Requested operation.

Ownership validation should occur before evaluating business permissions.

---

# 19. Common Validation Rules

The following validations should be shared across collections.

---

## Restaurant Validation

Verify:

* Restaurant exists.
* Restaurant is active.

---

## Staff Validation

Verify:

* Staff exists.
* Staff is active.
* Staff belongs to Restaurant.

---

## Customer Validation

Verify:

* Customer Session exists.
* Customer Session is active.
* Customer owns requested resource.

---

## Business Validation

Verify:

* Document exists.
* Document is active.
* Operation is permitted.
* Immutable fields are unchanged.

---

# 20. Rule Helper Functions

The Firestore Security Rules implementation should define reusable helper functions whenever possible.

Typical helper functions include:

```
isAuthenticated()

isRestaurantMember()

isRestaurantManager()

isResourceOwner()

belongsToRestaurant()

isActiveStaff()

isCustomerSessionOwner()
```

Centralizing common validation logic improves readability and maintainability.

---

# 21. Recommended Rules Structure

The Firestore Rules implementation should follow a modular structure.

```text
rules_version = '2';

service cloud.firestore {

    match /databases/{database}/documents {

        Helper Functions

        Restaurant Rules

        Branch Rules

        Table Rules

        Session Rules

        Menu Rules

        Order Rules

        Staff Rules
    }
}
```

Each collection should remain independent and easy to understand.

Avoid deeply nested authorization logic.

---

# 22. Security Checklist

Before adding a new collection, verify the following.

| Requirement | Required |
|------------|----------|
| Authentication validated | ✓ |
| Tenant ownership validated | ✓ |
| Business ownership validated | ✓ |
| Read permissions defined | ✓ |
| Create permissions defined | ✓ |
| Update permissions defined | ✓ |
| Delete permissions defined | ✓ |
| Immutable fields protected | ✓ |
| Cloud Functions evaluated | ✓ |

---

# 23. Guiding Principle

Firestore Security Rules are the first line of defense for the ScanServe platform.

They should remain:

* Simple.
* Predictable.
* Ownership-based.
* Easy to audit.
* Easy to maintain.

Business workflows should remain inside Cloud Functions.

Security Rules should determine whether an operation is permitted—not execute business logic.
