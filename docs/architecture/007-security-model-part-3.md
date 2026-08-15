# 15. Cloud Functions Security

Cloud Functions are trusted backend components.

They execute business-critical operations that should never rely on client-side validation.

---

## Responsibilities

Cloud Functions are responsible for:

* Order creation
* Order validation
* Permission validation
* Session cleanup
* Notification dispatch
* Analytics collection
* Future payment processing

Cloud Functions must verify every request regardless of client application.

---

## Validation Pipeline

Every privileged request should follow the same validation pipeline.

```text
Receive Request
        ↓
Authenticate User
        ↓
Validate Tenant Ownership
        ↓
Validate Role Permissions
        ↓
Validate Business Rules
        ↓
Execute Operation
        ↓
Persist Changes
        ↓
Return Result
```

Business logic must never execute before authorization succeeds.

---

# 16. Data Ownership Enforcement

Ownership is the primary mechanism used to authorize access to business data.

Every business document belongs to exactly one Restaurant.

Documents may additionally belong to subordinate business entities such as:

* Branch
* Table
* Customer Session
* Order

Ownership must always be validated before allowing access.

---

## Ownership Hierarchy

```text
Restaurant
│
├── Branch
│
├── Table
│
├── Table Session
│
├── Customer Session
│
├── Menu
│
├── Category
│
├── Menu Item
│
├── Order
│   └── Order Item
│
├── Staff
│
└── Role
```

Ownership defines:

* Read authorization
* Write authorization
* Lifecycle
* Security Rules
* Administrative boundaries

References never grant access.

---

# 17. Security Event Logging

Security-related operations should generate audit events.

Examples include:

* Staff login
* Failed authorization
* Role assignment
* Staff creation
* Restaurant configuration changes
* Menu publication
* Order cancellation *(future)*

Audit logging improves:

* Operational monitoring
* Incident investigation
* Compliance
* Platform support

Audit events should be immutable.

---

# 18. Common Attack Scenarios

The platform should be designed to resist common attack scenarios.

---

## Unauthorized Tenant Access

Attempt:

A Staff member attempts to read another Restaurant's data.

Mitigation:

* Tenant ownership validation.
* Firestore Security Rules.
* Cloud Function authorization.

---

## Order Tampering

Attempt:

A Customer modifies Order totals or prices.

Mitigation:

* Orders are created only by Cloud Functions.
* Totals are calculated on the backend.
* Clients cannot modify submitted Orders.

---

## Permission Escalation

Attempt:

A Staff member assigns themselves Manager permissions.

Mitigation:

* Role assignment requires Manager authorization.
* Security Rules validate permissions.
* Cloud Functions verify role ownership.

---

## QR Code Manipulation

Attempt:

A Customer manually edits QR parameters.

Mitigation:

* Validate Restaurant.
* Validate Branch.
* Validate Table.
* Validate active Table status.
* Reject invalid combinations.

---

## Direct Firestore Writes

Attempt:

A malicious client bypasses the application.

Mitigation:

* Firestore Security Rules.
* Ownership validation.
* Authentication.
* Backend authorization.

Applications must never rely on hidden UI elements for security.

---

# 19. Security Checklist

Every new feature should satisfy the following checklist before implementation.

| Requirement | Required |
|------------|----------|
| Authentication verified | ✓ |
| Tenant ownership validated | ✓ |
| Role permissions validated | ✓ |
| Business rules enforced | ✓ |
| Firestore Security Rules updated | ✓ |
| Cloud Functions validated | ✓ |
| Audit events considered | ✓ |
| Least privilege maintained | ✓ |

Features should not be considered production-ready until every applicable requirement has been addressed.

---

# 20. Guiding Principle

Security is an architectural responsibility shared across every layer of the ScanServe platform.

Client applications provide the user experience.

Trusted backend components enforce business rules.

Every request should be evaluated according to:

* Identity
* Ownership
* Permissions
* Business rules

No client application should ever be trusted to enforce business-critical behavior.
