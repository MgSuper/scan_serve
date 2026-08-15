# ScanServe Firestore Security Rules Specification

**Version:** 1.0
**Status:** Draft
**Last Updated:** July 2026

---

# 1. Purpose

This document defines the authorization strategy for Cloud Firestore.

It specifies the security behavior expected for every collection used by the ScanServe platform.

The objectives are to:

* Enforce tenant isolation.
* Protect business-critical data.
* Define collection-level permissions.
* Standardize authorization logic.
* Provide the implementation blueprint for Firestore Security Rules.

This document defines **what the rules should enforce**, not the Firestore Rules syntax itself.

---

# 2. Scope

This document defines:

* Read permissions
* Create permissions
* Update permissions
* Delete permissions
* Ownership validation
* Tenant isolation
* Authentication requirements

This document intentionally excludes:

* Firestore Rules implementation syntax
* Cloud Function authorization
* Firebase Authentication configuration

---

# 3. Security Principles

Every Firestore rule follows these principles.

---

## 3.1 Deny By Default

Every request is denied unless explicitly allowed.

---

## 3.2 Never Trust The Client

Client applications are untrusted.

Security Rules must validate every request independently.

---

## 3.3 Ownership Validation

Every document belongs to exactly one Restaurant.

Every request must validate ownership before granting access.

---

## 3.4 Least Privilege

Users receive only the minimum permissions required.

---

## 3.5 Backend Authority

Business-critical writes should occur through Cloud Functions whenever possible.

---

# 4. Authorization Layers

Firestore authorization consists of multiple layers.

```text
Authentication
        ↓
Tenant Validation
        ↓
Role Validation
        ↓
Ownership Validation
        ↓
Document Validation
        ↓
Allow / Deny
```

All applicable layers must succeed before access is granted.

---

# 5. Authentication Requirements

## Customer

Authentication is not required.

Customers operate through Customer Sessions.

---

## Staff

Staff must authenticate using Firebase Authentication.

Every authenticated Staff member must be associated with:

* Restaurant
* Role
* Active account

---

## Platform

Cloud Functions execute with administrative privileges.

All privileged operations must perform business validation before modifying Firestore.

---

# 6. Collection Authorization Matrix

| Collection | Read | Create | Update | Delete |
|------------|------|--------|--------|--------|
| restaurants | Public *(limited)* | Platform | Platform | Platform |
| branches | Public | Manager | Manager | Platform |
| tables | Public | Manager | Manager | Platform |
| tableSessions | Customer / Staff | Customer | Backend | Backend |
| customerSessions | Owner | Customer | Owner | Backend |
| carts | Owner | Customer | Owner | Backend |
| menus | Public | Manager | Manager | Platform |
| categories | Public | Manager | Manager | Platform |
| menuItems | Public | Manager | Manager | Platform |
| orders | Owner / Staff | Cloud Functions | Staff | Platform |
| orderItems | Owner / Staff | Cloud Functions | Platform | Platform |
| staff | Staff | Manager | Manager | Platform |
| roles | Staff | Manager | Manager | Platform |

---

# 7. Restaurant Collection Rules

Collection:

```
restaurants
```

---

## Read

Allowed:

* Customer
* Staff

Only public business information should be readable.

Examples:

* Restaurant name
* Logo
* Contact information

Sensitive configuration should remain protected.

---

## Create

Allowed:

Platform only.

---

## Update

Allowed:

Platform only.

---

## Delete

Not permitted.

Restaurants should be archived rather than deleted.

---

# 8. Branch Collection Rules

Customers may read Branch information required for ordering.

Only Restaurant Managers may modify Branch documents.

Delete operations should not be allowed.

---

# 9. Table Collection Rules

Customers may read active Tables through QR entry.

Managers may:

* Create
* Update
* Archive

Customers must never modify Table information.

---

# 10. Table Session Rules

Customers may create a Table Session only through the Start Dining Session workflow.

Customers may read only the active Table Session associated with their Customer Session.

Status updates should occur only through backend services.

---

# 11. Customer Session Rules

Customers may:

* Create their own Customer Session.
* Read their own Customer Session.
* Update their own Customer Session.

Customers must never access another Customer Session.

Expired sessions become read-only.

---

# 12. Cart Rules

Customers own exactly one Cart.

Allowed operations:

* Create
* Read
* Update

Delete operations occur only after successful Order creation.

Customers must never access another customer's Cart.