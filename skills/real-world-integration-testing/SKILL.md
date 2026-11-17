---
name: real-world-integration-testing
description: Use when writing integration tests, implementing features with TDD, testing API endpoints, verifying bug fixes, or reviewing test suites where mocks risk creating false-positive green builds across TypeScript, Rust, Python, or Go.
---

# Real-World Integration Testing Protocol

A rigorous, multi-language operational standard for integration and contract testing. Eliminates "fake green" test suites by enforcing real dependency wiring, wire-level third-party interception, triple-layer contract assertions, and uncommitted local sabotage checks across TypeScript, Rust, Python, and Go.

---

## 0. Core Testing Invariants

1. **Zero Internal Mocks**: Never mock or spy on internal classes, repositories, services, domain models, or serialization middleware. If code belongs to the application boundary, it must run for real. Mocking internal boundaries tests your assumptions rather than your implementation.
2. **Transport/Wire-Level Interception for External 3rd-Party APIs**: External third-party APIs (Stripe, Twilio, OpenAI, GitHub, webhooks) must only be intercepted at the network/wire transport layer (e.g. WireMock, MSW, nock). Internal HTTP client classes, SDK methods, and transport protocols must never be monkey-patched.
3. **Triple-Layer Contract & State Verification**: Every integration test must assert three distinct layers:
   - *Layer 1 (Transport/Status)*: Correct HTTP status, CLI exit code, or message ACK.
   - *Layer 2 (Contract Payload)*: Complete response body schema, field types, and deterministic business values (never just `toBeDefined()` or existence checks).
   - *Layer 3 (Persisted State)*: Querying the database, cache, or event log to prove state was durably persisted.
4. **Dialect Fidelity & Automated Transaction Isolation**:
   - Always run tests against the real production database engine (PostgreSQL, MySQL) via Testcontainers or local test containers.
   - Strictly ban in-memory dialect substitutes (e.g., SQLite masquerading as PostgreSQL)—they conceal foreign key discrepancies, transaction semantics, and dialect-specific locking.
   - Isolate tests using automated transaction rollbacks (`BEGIN ... ROLLBACK`, `sqlx::test`) or isolated ephemeral schemas per test suite.
5. **Deterministic Time & Asynchrony**:
   - Zero arbitrary sleep delays (`sleep(1000)`, `thread::sleep`). Use virtual mock clocks (`vi.useFakeTimers()`, `tokio::time::pause`, `freezegun`) or condition-based polling with timeouts.
   - Fully await every promise, future, and asynchronous dispatch before making assertions.

---

## 1. Boundary Taxonomy: Real vs. Wire-Intercepted

| Boundary Component | Strategy | Recommended Tooling | Invariant Rule |
| :--- | :--- | :--- | :--- |
| **Relational / Document DB** | **Real Database** | Testcontainers, `sqlx::test` (Rust), local Postgres container | **NEVER MOCK.** Wrap in rolling transaction or truncate tables. |
| **Cache & Key-Value Stores** | **Real Instance** | Redis Testcontainer, local Redis instance | **NEVER MOCK.** Flush namespace between test runs. |
| **Internal Domain Services** | **Real Code** | Direct dependency injection / modular composition | **NEVER MOCK.** Exercise actual domain business logic. |
| **Routing & Middleware** | **Real Entry Point** | Supertest (TS), `tower::ServiceExt` / `reqwest` (Rust), `httpx` (Py) | **NEVER MOCK.** Auth, validation, and error handlers must execute. |
| **Paid 3rd-Party SaaS / APIs** | **Wire Mock Server** | `wiremock` (Rust), `msw` / `nock` (TS), `responses` (Py) | **MOCK AT WIRE LEVEL ONLY.** Application HTTP client must execute. |
| **System Clocks / Wall Time** | **Virtual Clock** | `vi.useFakeTimers()`, `tokio::time::pause()`, `freezegun` | Control deterministically; ban arbitrary sleeps. |

---

## 2. Concrete Multi-Stack Patterns

### Pattern A: API & Database Integration

#### ❌ Anti-Pattern: Tautological Mock Repository (TypeScript)
```typescript
// ❌ WRONG: Testing mock assumptions. If SQL is broken, this still passes green!
it('registers a user', async () => {
  const mockRepo = { create: vi.fn().mockResolvedValue({ id: '123', email: 'test@example.com' }) };
  const service = new UserService(mockRepo);
  
  const result = await service.register({ email: 'test@example.com' });
  
  expect(mockRepo.create).toHaveBeenCalledWith({ email: 'test@example.com' });
  expect(result.id).toBe('123'); // Hollow assertion
});
```

#### ✅ Production Pattern: Real End-to-End Route & DB Test (TypeScript)
```typescript
// ✅ CORRECT: Real HTTP route, real database via Testcontainer, triple-layer assertion
it('registers user, returns 201 contract, and persists in database', async () => {
  const payload = { email: 'user@example.com', name: 'Alice' };

  // Layer 1 & 2: Transport & Contract Payload
  const response = await supertest(app)
    .post('/api/users')
    .send(payload)
    .expect(201);

  expect(response.body).toMatchObject({
    id: expect.stringMatching(/^[0-9a-f-]{36}$/),
    email: 'user@example.com',
    name: 'Alice',
    createdAt: expect.any(String),
  });

  // Layer 3: Persisted State Verification
  const userInDb = await db.user.findUnique({ where: { id: response.body.id } });
  expect(userInDb).not.toBeNull();
  expect(userInDb?.email).toBe('user@example.com');
});
```

#### ✅ Production Pattern: Real Router & DB Test with Rollback (Rust)
```rust
// ✅ CORRECT: Real axum router, real PostgreSQL with automated transaction rollback
#[sqlx::test]
async fn test_create_order_persists_and_returns_contract(pool: PgPool) {
    let app = create_router(pool.clone());
    let payload = json!({ "user_id": 101, "amount_cents": 5000 });

    // Layer 1 & 2: Real router execution & contract verification
    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/orders")
                .header("Content-Type", "application/json")
                .body(Body::from(serde_json::to_vec(&payload).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::CREATED);
    let body_bytes = to_bytes(response.into_body(), usize::MAX).await.unwrap();
    let order: OrderResponse = serde_json::from_slice(&body_bytes).unwrap();
    assert_eq!(order.amount_cents, 5000);

    // Layer 3: Verify durable side effect in PostgreSQL
    let row = sqlx::query!("SELECT status FROM orders WHERE id = $1", order.id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(row.status, "PENDING");
}
```

---

### Pattern B: External 3rd-Party APIs

#### ❌ Anti-Pattern: Monkey-Patching Client SDK
```typescript
// ❌ WRONG: Monkey-patching axios/Stripe skips serializers, auth headers, and timeout handling
vi.spyOn(axios, 'post').mockResolvedValue({ data: { id: 'ch_123', paid: true } });
```

#### ✅ Production Pattern: Wire-Level Interception with MSW (TypeScript)
```typescript
// ✅ CORRECT: Intercepts network transport; real HTTP client, headers, and retries run
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';

const server = setupServer(
  http.post('https://api.stripe.com/v1/charges', async ({ request }) => {
    // Validate authorization header sent by your real client
    if (!request.headers.get('authorization')?.startsWith('Bearer sk_test_')) {
      return new HttpResponse(null, { status: 401 });
    }
    return HttpResponse.json({ id: 'ch_test_999', status: 'succeeded' }, { status: 200 });
  })
);

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

#### ✅ Production Pattern: Wire-Level Mocking with WireMock (Rust)
```rust
// ✅ CORRECT: Real HTTP client dispatches to a local mock HTTP server
use wiremock::matchers::{header, method, path};
use wiremock::{Mock, MockServer, ResponseTemplate};

#[tokio::test]
async fn test_payment_service_handles_charge_success() {
    let mock_server = MockServer::start().await;

    Mock::given(method("POST"))
        .and(path("/v1/charges"))
        .and(header("Authorization", "Bearer sk_test_key"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({
            "id": "ch_mock_1",
            "status": "succeeded"
        })))
        .mount(&mock_server)
        .await;

    let client = PaymentClient::new(mock_server.uri(), "sk_test_key");
    let result = client.charge(5000, "usd").await.unwrap();

    assert_eq!(result.charge_id, "ch_mock_1");
    assert!(result.is_successful());
}
```

---

## 3. The 4-Step Local Sabotage Sanity Protocol

To ensure a passing test suite is truly sensitive to regressions and not a false positive:

```
[ Step 1: Baseline Green ] ──> [ Step 2: Atomic Local Sabotage ] ──> [ Step 3: Assert Exact Failure ] ──> [ Step 4: Atomic Local Revert ]
```

1. **Step 1: Baseline Green**
   - Run the integration test suite against unmodified code and verify 100% green pass.
2. **Step 2: Atomic Local Sabotage (Strictly Local / In-Memory)**
   - Introduce a single deliberate bug into the production business logic in your working copy:
     - Invert a conditional (`if user.is_active` -> `if !user.is_active`).
     - Comment out the database write or event emission.
     - Hardcode an erroneous return status or payload value.
   - **CRITICAL**: Never stage, commit, or push sabotage code to git.
3. **Step 3: Assert Exact Failure**
   - Run the target integration test.
   - Confirm that the test **FAILS** and that the failure occurs on the **exact expected assertion** (e.g. `expected 201 but got 403` or `database query returned 0 rows`).
   - If the test still passes, your test is hollow—refactor assertions immediately.
4. **Step 4: Atomic Local Revert**
   - Immediately revert the local edit:
     ```bash
     git checkout -- path/to/mutated_file
     ```
   - Re-run the test suite to verify it returns to 100% green.

---

## 4. Red Flags & Anti-Rationalization Matrix

| Agent Rationalization | Engineering Reality & Mandatory Invariant |
| :--- | :--- |
| *"Spinning up a real database is too slow; I'll mock the repo."* | **Forbidden.** Mocking the repository eliminates the primary source of bugs: query syntax, schema constraints, serialization, and connection pooling. Use Testcontainers or connection pooling rollbacks. |
| *"In-memory SQLite is basically the same as PostgreSQL."* | **Forbidden.** SQLite does not enforce identical constraint behaviors, JSON indexing, concurrent transactions, or schema migrations. Match production dialect. |
| *"Checking status 200 is sufficient; payload checks are tedious."* | **Forbidden.** A 200 response with `{ error: "Internal crash" }` or empty `{}` passes a status-only check. Must assert complete response schema and field values. |
| *"I'll just mock the external SDK module with a spy."* | **Forbidden.** Spying on SDK classes masks authentication header changes, payload serialization bugs, and error handling. Mock at the HTTP wire level. |
| *"The test passed on the first run; no need to do the sabotage check."* | **Forbidden.** Tests that pass on the first attempt without TDD RED phase often assert nothing. Run an atomic local sabotage to prove failure sensitivity. |
| *"I'll commit the mutation test to save my progress."* | **Forbidden.** Sabotage checks are ephemeral and uncommitted. Never commit or push broken code to any branch. |

---

## 5. Gotchas & Defensive Practices

- **Self-Mocking Regressions**: Testing `expect(mockService.send).toHaveBeenCalled()` guarantees only that a function was invoked, not that the correct wire payload reached a consumer or that state changed. Always assert observable state or response contracts.
- **Silent Asynchronous Passes**: Unawaited promises in TypeScript or unpolled futures in Rust/Python can finish after the test runner exits, masking failures. Configure test runners to fail on unhandled promise rejections (`--unhandled-rejections=strict`).
- **Test Pollution & Leaked State**: Shared database tables across parallel test suites cause intermittent flaky runs. Always isolate test runs by tenant ID, isolated schema, or transactional rollback.
