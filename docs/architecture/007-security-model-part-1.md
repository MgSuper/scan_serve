# ScanServe Security Model

**Version:** 1.0
**Status:** Draft
**Last Updated:** July 2026

---

# 1. Purpose

This document defines the security architecture of the ScanServe platform.

Its objectives are to:

* Protect restaurant data.
* Enforce tenant isolation.
* Define authentication and authorization.
* Establish trust boundaries.
* Specify ownership-based access control.
* Define where business rules are enforced.

Security is considered a core architectural concern rather than an implementation detail.

---

# 2. Scope

This document defines:

* Authentication strategy
* Authorization model
* Tenant isolation
* Role-based access control
* Firestore access principles
* Cloud Function authorization
* Trust boundaries
* Security responsibilities

This document intentionally excludes:

* Firestore Security Rules syntax
* Firebase Authentication configuration
* OAuth providers
* API implementation

These topics are implementation details built upon this architecture.

---

# 3. Security Principles

The ScanServe platform follows the following security principles.

---

## 3.1 Never Trust the Client

All client applications are considered untrusted.

Business-critical validation must always occur within trusted backend components.

Client applications request operations.

The backend authorizes operations.

---

## 3.2 Least Privilege

Users receive only the permissions required to perform their responsibilities.

Additional permissions must be explicitly granted.

---

## 3.3 Tenant Isolation

Restaurant data is completely isolated.

A tenant must never access another tenant's data.

Tenant isolation is enforced by:

* Firestore Security Rules
* Cloud Functions
* Authentication
* Ownership validation

---

## 3.4 Ownership Enforcement

Every document has exactly one owner.

Ownership determines:

* Read access
* Write access
* Update access
* Delete access

References never imply ownership.

---

## 3.5 Backend Authority

Business-critical operations must execute in trusted backend services.

Examples include:

* Order creation
* Payment processing *(future)*
* Permission assignment
* Session cleanup
* Notification dispatch

---

## 3.6 Defense in Depth

Security is enforced across multiple layers.

Failure of one layer must not compromise the platform.

Typical layers include:

* Authentication
* Authorization
* Firestore Security Rules
* Cloud Functions
* Audit Logging

---

# 4. Trust Boundaries

The ScanServe platform is divided into trusted and untrusted components.

```text
Customer PWA
        │
        │
Angular Dashboard
        │
──────── Trust Boundary ────────
        │
Firestore Security Rules
        │
Cloud Functions
        │
Cloud Firestore
```

Everything above the trust boundary is considered untrusted.

Everything below the trust boundary is trusted.

Business rules should never depend on client-side validation.

---

# 5. Authentication Model

Authentication establishes identity.

Authorization determines permissions.

These concerns remain separate throughout the platform.

---

## Customer

Authentication is not required.

Customers operate using anonymous Customer Sessions.

Identity is represented by:

* Customer Session ID
* Device ID *(optional)*

---

## Staff

Restaurant Staff authenticate using Firebase Authentication.

Each authenticated account is linked to:

* Staff document
* Role
* Restaurant
* Branch *(optional)*

---

## Platform Administrators *(Future)*

Platform administrators authenticate separately from restaurant staff.

They operate outside tenant boundaries and require elevated privileges.

---

# 6. Authorization Model

Authorization is ownership-based and role-based.

Both models work together.

Ownership determines:

* Which tenant owns the document.
* Which business entity controls the document.

Roles determine:

* Which operations are permitted.

A request must satisfy both ownership and permission requirements before it is authorized.