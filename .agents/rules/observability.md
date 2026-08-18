# Runtime Observability Rules

## Log Format

All log calls must use `android.util.Log` with a consistent tag prefixed with the application's root log tag:

```kotlin
private const val TAG = "<AppName>/<ClassName>" // e.g. "MyApp/HomeScreen"
Log.d(TAG, "message")
```

- Use the `<AppName>/` prefix (or project-configured log tag) on every tag — this is mandatory for logcat filtering.
- Never log PII (email, user ID, user-generated sensitive content) at any level.

---

## Log Levels

| Level | When to use | Example |
|-------|-------------|---------|
| `DEBUG` | Development-time detail — stripped in release | Parsed response body, ViewModel state snapshot |
| `INFO` | Significant lifecycle events | Screen opened, user action confirmed |
| `WARN` | Recoverable anomaly — worth investigating | Cache miss, retry attempt, empty API response |
| `ERROR` | Non-recoverable failure — always investigate | Exception caught, API 5xx, DB write failed |

---

## What to Check When Debugging

**API / Network**
- Tag: `<AppName>/ApiClient` or OkHttp interceptor output
- Look for: HTTP status code, request URL, response body (truncated), retry count
- Common signals: `401` → token expired · `404` → wrong endpoint · `timeout` → connectivity

**Room / Database**
- Tag: `<AppName>/Dao` or Room query logs (enable via `RoomDatabase.Builder.setQueryCallback`)
- Look for: SQL statement executed, row count returned, transaction open/close
- Common signals: `0 rows` → query mismatch · `SQLiteConstraintException` → unique/FK violation

**ViewModel / State**
- Tag: `<AppName>/<ViewModel name>`
- Look for: `UiState` transitions, `StateFlow` emissions, coroutine launch/cancel
- Common signals: state stuck in `Loading` → upstream flow never emits · `Error` state → check cause message

**Navigation**
- Tag: `<AppName>/Navigation`
- Look for: route name, argument values, back-stack depth
- Common signals: `IllegalArgumentException` → wrong argument type · blank screen → missing `startDestination`

**Hilt / DI**
- No runtime tag — failures surface at app startup as `RuntimeException`
- Look for: `MissingBinding`, `ComponentProcessingException` in build output, not logcat

**Repository / Cache**
- Tag: `<AppName>/Repository`
- Look for: cache hit/miss, data-source selected (local vs remote), sync trigger
- Common signals: stale data → cache not invalidated · repeated network calls → no cache write

---

## Filtering Logcat

```bash
# All app logs
adb logcat -s "<AppName>/*"

# Errors only
adb logcat "*:E" -s "<AppName>/*"

# API traffic only
adb logcat -s "<AppName>/ApiClient" "OkHttp"
```
