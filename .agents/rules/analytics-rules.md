# Analytics Rules

## Purpose
Rules for adding analytics and observability to features in this project.

---

## When to Add Analytics

For each feature, assess whether the following are needed:
- Screen view / impression events
- User action events (tap, swipe, submit)
- Business funnel tracking (step started, step completed, step abandoned)
- Error events (API failure, validation failure)
- API latency tracking
- Crash breadcrumbs

If none apply, state "analytics: none" in the implementation plan.

---

## Where to Fire Events

Fire analytics events from the **ViewModel**, not from Composables.

```kotlin
// ✅ In ViewModel
fun onSaveClick() {
    analytics.track(NoteEvent.SaveClicked)
    // ...
}

// ❌ In Composable
Button(onClick = {
    analytics.track(NoteEvent.SaveClicked) // wrong layer
    onSaveClick()
})
```

---

## What NOT to Log

Never log:
- Auth tokens or session cookies
- Passwords or secrets
- Full note content or user-generated content (unless explicitly product-approved)
- PII (name, email, phone) unless required by product and privacy policy
- Payment card data

If in doubt, do not log it.

---

## Event Naming

Follow the existing event naming convention in the codebase.

General pattern: `<Object>_<Action>` or `<Screen>_<Action>`

Examples:
```
note_save_clicked
note_delete_confirmed
home_screen_viewed
folder_created
share_invite_sent
```

---

## Error Observability

API errors and unexpected states should be logged for debugging.

Rules:
- Log at `error` level for unexpected failures
- Log at `debug` level for expected states (empty list, no network)
- Keep technical detail in logs, not in UI state
- Never expose raw backend error payloads to the user
