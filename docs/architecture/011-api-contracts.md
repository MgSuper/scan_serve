# ScanServe API Contracts

**Version:** 1.0
**Status:** Draft
**Last Updated:** July 2026

---

# 1. Purpose

This document defines the backend contracts used by the ScanServe platform.

It specifies how client applications communicate with backend services.

The objectives are to:

* Define backend capabilities.
* Standardize request and response structures.
* Ensure consistent validation.
* Establish error handling conventions.
* Enable parallel frontend and backend development.

This document represents the implementation contract between client applications and trusted backend services.

---

# 2. Scope

This document defines:

* Callable Cloud Functions
* Firestore read contracts
* Firestore write contracts
* Real-time listener contracts
* Scheduled backend operations
* Request models
* Response models
* Validation rules
* Error responses

This document intentionally excludes:

* Firestore schema
* Security Rules
* Client implementation
* Internal Cloud Function implementation

---

# 3. API Design Principles

Every backend contract should follow these principles.

---

## 3.1 Business-Oriented

Contracts represent business operations rather than database operations.

Good:

```
submitOrder()
```

Avoid:

```
createOrderDocument()
```

---

## 3.2 Backend Validation

Every request must be validated by trusted backend components.

Client validation exists only to improve user experience.

---

## 3.3 Predictable Responses

Every operation returns a predictable response structure.

---

## 3.4 Idempotency

Business operations should be idempotent whenever practical.

Repeated requests should not produce duplicate business effects.

---

## 3.5 Explicit Errors

Every failure returns a structured error.

Unexpected failures should never expose internal implementation details.

---

# 4. Contract Categories

Backend contracts are grouped into the following categories.

## Customer Contracts

* Start Dining Session
* Submit Order
* Call Waiter

---

## Restaurant Contracts

* Update Order Status
* Publish Menu
* Manage Tables
* Manage Staff

---

## Platform Contracts

* Session Cleanup
* Notification Dispatch
* Analytics Collection

---

# 5. Standard Request Structure

Every callable backend operation follows the same request pattern.

```json
{
  "requestId": "...",
  "payload": { },
  "clientVersion": "...",
  "timestamp": "..."
}
```

---

## Request Fields

| Field | Required | Description |
|--------|----------|-------------|
| requestId | ✓ | Unique request identifier. |
| payload | ✓ | Business request payload. |
| clientVersion | | Application version. |
| timestamp | ✓ | Client request timestamp. |

---

# 6. Standard Response Structure

Successful responses follow the same structure.

```json
{
  "success": true,
  "data": { },
  "serverTimestamp": "...",
  "requestId": "..."
}
```

---

## Response Fields

| Field | Description |
|--------|-------------|
| success | Operation status. |
| data | Response payload. |
| serverTimestamp | Backend processing time. |
| requestId | Original request identifier. |

---

# 7. Standard Error Structure

Every backend error follows the same format.

```json
{
  "success": false,
  "error": {
    "code": "...",
    "message": "...",
    "details": { }
  }
}
```

---

## Error Fields

| Field | Description |
|--------|-------------|
| code | Stable application error code. |
| message | Human-readable message. |
| details | Optional additional information. |

---

# 8. Error Codes

Standard application error codes include:

| Code | Description |
|------|-------------|
| INVALID_REQUEST | Request payload is invalid. |
| UNAUTHENTICATED | Authentication required. |
| UNAUTHORIZED | Permission denied. |
| NOT_FOUND | Requested resource not found. |
| VALIDATION_FAILED | Business validation failed. |
| RESOURCE_CONFLICT | Business conflict detected. |
| INTERNAL_ERROR | Unexpected server error. |

---

# 9. Authentication

Customer operations use Customer Sessions.

Staff operations require Firebase Authentication.

Every backend request validates:

* Identity
* Restaurant ownership
* Permissions
* Business rules

---

# 10. Backend Contracts

The following sections define each backend capability.

Customer Contracts:

* Start Dining Session
* Submit Order
* Call Waiter

Restaurant Contracts:

* Update Order Status
* Publish Menu
* Manage Tables
* Manage Staff

Platform Contracts:

* Session Cleanup
* Notification Dispatch

Each contract specifies:

* Purpose
* Trigger
* Authorization
* Request
* Response
* Validation
* Failure Cases

---

# 11. Related Documents

| Document | Relationship |
|----------|--------------|
| 006 Firestore Data Model | Defines stored data |
| 007 Security Model | Defines authorization |
| 008 Event Flow | Defines event execution |
| 009 Client Architecture | Defines client integration |