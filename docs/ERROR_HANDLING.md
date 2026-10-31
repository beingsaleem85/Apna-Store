# APNA STORE — ERROR HANDLING & APPLICATION FAILURES ARCHITECTURE

> **Phase:** 3 — Data Models, Error Handling, and Service Boundaries  
> **Status:** Active Standard Specification  

---

## 1. FAILURE HIERARCHY

All application errors are encapsulated within a strongly-typed failure hierarchy extending [`Failure`](file:///c:/Users/X%20COMPUTER/Desktop/apna%20store/lib/core/errors/failures.dart):

```
Failure (abstract base)
 ├── AuthenticationFailure
 ├── AuthorizationFailure
 ├── ValidationFailure
 ├── NetworkFailure
 ├── DatabaseFailure
 ├── PaymentFailure
 ├── ConfigurationFailure
 ├── NotFoundFailure
 ├── ConflictFailure
 └── UnknownFailure
```

---

## 2. EXCEPTION MAPPING RULES

The [`FailureMapper`](file:///c:/Users/X%20COMPUTER/Desktop/apna%20store/lib/core/errors/failures.dart) utility handles conversion of raw runtime exceptions:

1. **`AuthException`** -> `AuthenticationFailure` (exposes user-safe message and status code).
2. **`PostgrestException`** -> `DatabaseFailure` (exposes PostgREST error message and database error code).
3. **`SocketException` / Connection Failures** -> `NetworkFailure` (flagged as `isRetryable = true`).
4. **`FormatException` / `TypeError`** -> `ValidationFailure`.
5. **Uncaught Exceptions** -> `UnknownFailure` (generic safe message for production).

---

## 3. SECURITY & SENSITIVE DATA RESTRICTIONS

1. **Zero Credential Exposure:** Passwords, Supabase service-role keys, and secret access tokens must **NEVER** be included in failure messages, debug logs, or error strings.
2. **Production User Messaging:** Production users are shown user-friendly, non-technical error messages. Detailed stack traces are logged via `debugPrint` in `kDebugMode` only.
3. **Zero Silent Failures:** Empty catch blocks (`catch (_) {}`) are prohibited in service and repository paths. All database operations throw or propagate a typed `Failure`.
