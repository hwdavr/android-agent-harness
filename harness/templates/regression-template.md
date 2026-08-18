# Regression Template

Use this template when documenting a bug fix regression test in the relevant stage or in `knowledge/past-bugs/`.

---

## Bug Reference

**Title**: `<short title>`  
**Date fixed**: `<date>`  
**Severity**: critical / high / medium / low  
**Affected version**: `<app version or "unknown">`

---

## Symptom

> What the user or developer observed. Describe the visible behavior, not the cause.

---

## Root Cause

```
Root cause:
The bug happens because <specific code/data/state issue>, triggered when <condition>,
causing <wrong behavior>.
```

---

## Regression Test

| Test Class | Type | Scenario | Fails Before Fix | Passes After Fix |
|------------|------|----------|-----------------|-----------------|
| `<Class>Test.kt` | Unit / Integration | `<scenario>` | ✅ | ✅ |

### Test description

```kotlin
@Test
fun `<describes what the bug was>`() {
    // Setup: reproduce the condition that triggered the bug
    // Assert: the wrong behavior no longer occurs
}
```

---

## Edge Cases Covered

- [ ] Null / missing data
- [ ] Partial response
- [ ] Unknown enum value
- [ ] Concurrent request
- [ ] Retry after failure
- [ ] Old app / old backend version

---

## Fix Summary

**Files changed**:
- `path/to/File.kt` — `<what changed>`

**Change type**: defensive null check / state correction / mapper fix / business logic fix / other

---

## Prevention

> What was added to prevent recurrence: test, rule, lint check, documentation.
