# 7. Roles and Permissions

ScanServe uses Role-Based Access Control (RBAC) for authenticated staff.

Permissions are assigned to Roles rather than individual Staff members.

This approach simplifies permission management while maintaining flexibility for future platform growth.

---

## Role Hierarchy

```text
Platform Administrator (Future)
            │
Restaurant Manager
            │
 ┌──────────┴──────────┐
 │                     │
Waiter          Kitchen Staff
```

Higher-level roles may inherit permissions from lower-level roles where appropriate.

Permission inheritance is defined by the authorization layer rather than Firestore.

---

## Standard Roles

Version 1 defines the following business roles.

| Role | Purpose |
|------|---------|
| Restaurant Manager | Full restaurant administration. |
| Waiter | Customer assistance and table operations. |
| Kitchen Staff | Kitchen workflow management. |

Future versions may introduce:

* Cashier
* Branch Manager
* Franchise Manager
* Platform Administrator

---

# 8. Permission Model

Permissions represent business capabilities.

Permission names should remain stable across:

* Angular
* Cloud Functions
* Firestore Security Rules
* Documentation

Permissions should describe actions rather than screens.

Good examples:

```
orders.read
orders.updateStatus
menus.update
tables.manage
staff.manage
```

Avoid permission names tied to UI components.

Examples:

```
dashboardPage
buttonAccess
menuScreen
```

---

# 9. Customer Permissions

Customers operate anonymously through Customer Sessions.

Their permissions are intentionally limited.

---

## Allowed Operations

Customers may:

* Read restaurant information.
* Read menus.
* Read categories.
* Read menu items.
* Create Customer Sessions.
* Update their own Customer Session.
* Read their own Cart.
* Update their own Cart.
* Submit an order through Cloud Functions.
* Read their own Orders.
* Track Order status.
* Request waiter assistance.

---

## Prohibited Operations

Customers must never:

* Read another customer's data.
* Modify submitted Orders.
* Update Order status.
* Modify Menu Items.
* Modify prices.
* Modify totals.
* Access Staff data.
* Access another Restaurant.

---

# 10. Waiter Permissions

Waiters support customers during restaurant operations.

---

## Allowed Operations

* Read active tables.
* Read active Table Sessions.
* Read Customer Sessions.
* Read Orders.
* Respond to waiter requests.
* Update table operational status.
* View menu information.

---

## Prohibited Operations

* Create Staff accounts.
* Modify Roles.
* Edit restaurant settings.
* Modify historical Orders.
* Change menu pricing.
* Access another Restaurant.

---

# 11. Kitchen Staff Permissions

Kitchen Staff manage order preparation.

---

## Allowed Operations

* Read kitchen queue.
* Read Orders.
* Update Order status.
* Read Menu Items.

---

## Prohibited Operations

* Edit Menus.
* Modify Staff.
* Modify Roles.
* Change restaurant settings.
* Access another Restaurant.

---

# 12. Restaurant Manager Permissions

Restaurant Managers administer their restaurant.

---

## Allowed Operations

* Manage Menus.
* Manage Categories.
* Manage Menu Items.
* Manage Tables.
* Manage Staff.
* Assign Roles.
* Read operational reports.
* Configure restaurant settings.

Restaurant Managers may perform every operation within their own tenant unless explicitly restricted.

---

## Prohibited Operations

Restaurant Managers must never:

* Access another Restaurant.
* Modify platform configuration.
* Grant Platform Administrator permissions.
* Modify platform billing.

---

# 13. Tenant Isolation

Tenant isolation is the foundation of the ScanServe security model.

Every business document belongs to exactly one Restaurant.

Every authenticated Staff member belongs to exactly one Restaurant.

Authorization must always verify tenant ownership before evaluating permissions.

---

## Tenant Validation

Every request should validate:

1. Authenticated identity.
2. Restaurant ownership.
3. Requested operation.
4. Assigned permissions.

If any validation fails, access must be denied.

---

## Cross-Tenant Access

Cross-tenant access is prohibited.

Examples:

Restaurant A must never:

* Read Restaurant B Orders.
* Read Restaurant B Staff.
* Read Restaurant B Menus.
* Modify Restaurant B Tables.
* Query Restaurant B Customer Sessions.

Tenant isolation is enforced regardless of client application.

---

# 14. Firestore Security Strategy

Firestore Security Rules provide the first layer of backend authorization.

Rules should validate:

* Authentication.
* Restaurant ownership.
* Role permissions.
* Document ownership.
* Allowed operations.

Security Rules should never implement complex business workflows.

Complex validation belongs in Cloud Functions.

---

## Read Strategy

Read access should follow the principle of least privilege.

Examples:

Customer:

* Own Customer Session
* Own Cart
* Own Orders
* Public Menu

Staff:

* Restaurant-owned business data

---

## Write Strategy

Client write access should remain minimal.

Examples of permitted client writes:

* Customer Session
* Cart
* Waiter Request

Business-critical writes should be delegated to Cloud Functions.

Examples:

* Order creation
* Staff management
* Role assignment
* Session cleanup