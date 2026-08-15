# 9. Flutter Testing Strategy

The Flutter Customer PWA should be tested at multiple layers.

---

## Unit Tests

Verify:

* Domain Entities
* Use Cases
* Business Rules
* Repository Contracts

Unit tests should not require Flutter widgets or Firebase.

---

## Repository Tests

Verify:

* Firestore integration
* DTO mapping
* Serialization
* Error translation

Firebase Emulator should be preferred over production services.

---

## BLoC Tests

Verify:

* Event handling
* State transitions
* Error handling
* Business workflows

Each public BLoC should have corresponding tests.

---

## Widget Tests

Verify:

* Rendering
* User interactions
* Navigation
* Error presentation

Widget tests should validate user behavior rather than implementation details.

---

# 10. Angular Testing Strategy

The Angular Administration Dashboard should follow the same layered testing approach.

---

## Unit Tests

Verify:

* Use Cases
* Domain Entities
* Repository Contracts
* Business Rules

Business logic should remain independent of Angular Components.

---

## Repository Tests

Verify:

* Firestore integration
* DTO mapping
* Error translation

Repository implementations should be tested against the Firebase Emulator whenever practical.

---

## Signal Store Tests

Verify:

* State updates
* Computed values
* Error handling
* Business workflows

Each Feature Store should have corresponding tests.

---

## Component Tests

Verify:

* Rendering
* User interactions
* Navigation
* Form validation

Component tests should focus on observable behavior.

---

# 11. Cloud Functions Testing

Cloud Functions contain business-critical logic and require comprehensive testing.

---

## Unit Tests

Verify:

* Validators
* Services
* Business rules
* Error handling

Dependencies should be mocked where appropriate.

---

## Integration Tests

Verify:

* Firestore transactions
* Repository operations
* Trigger execution
* Callable Functions

Firebase Emulator Suite should be used whenever possible.

---

## Scheduled Function Tests

Verify:

* Session Cleanup
* Analytics Aggregation
* Background processing

Time-dependent behavior should be controlled using test doubles or mock timers.

---

# 12. Firestore Emulator Testing

The Firebase Emulator Suite should be the default environment for backend integration testing.

Benefits include:

* No production data
* Fast execution
* Repeatable results
* Safe destructive testing

The Emulator should be used to validate:

* Security Rules
* Firestore queries
* Cloud Functions
* Transactions

---

# 13. Integration Testing

Integration Tests verify interactions between multiple system components.

Examples include:

* Flutter → Cloud Functions
* Angular → Firestore
* Cloud Functions → Firestore
* Firestore → Trigger Functions

Integration Tests should validate complete business operations rather than individual methods.

---

# 14. End-to-End Testing

End-to-End Tests verify complete business workflows from the user's perspective.

Critical workflows include:

---

## Customer Ordering

```text
Scan QR Code
        ↓
Browse Menu
        ↓
Add Items to Cart
        ↓
Submit Order
        ↓
Track Order
        ↓
Receive Food
```

---

## Kitchen Workflow

```text
Receive Order
        ↓
Accept Order
        ↓
Prepare Order
        ↓
Mark Ready
        ↓
Mark Served
```

---

## Restaurant Management

```text
Login
        ↓
Manage Menu
        ↓
Publish Menu
        ↓
Verify Customer Availability
```

Only business-critical workflows should be covered by End-to-End tests.

---

# 15. Regression Testing

Regression Tests ensure previously working functionality continues to operate after changes.

Regression testing should focus on:

* Order lifecycle
* Session lifecycle
* Menu management
* Staff authorization
* Security Rules

Critical business workflows should always be included.

---

# 16. Security Testing

Security-related testing should verify:

* Authentication
* Authorization
* Tenant isolation
* Firestore Security Rules
* Cloud Function validation

Negative test cases should be included.

Examples:

* Unauthorized access
* Cross-tenant access
* Invalid Customer Session
* Invalid Order update

Security testing should confirm that invalid operations are rejected.