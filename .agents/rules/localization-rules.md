# Localization Rules

## Purpose
Rules for handling all user-visible text in this project.

> **Enforcement Matrix** — each rule below is tagged as Scripted 🤖 / Evaluator 🧠 / Human 👁️  
> in [`localization-rules-enforcement-matrix.md`](../../harness/rules-matrix/localization-rules-enforcement-matrix.md).  
> Scripted checks run via [`check-localization-rules.sh`](../../harness/scripts/check-localization-rules.sh) on Unix/Git Bash or [`check-localization-rules.cmd`](../../harness/scripts/check-localization-rules.cmd) on Windows.

---

## String Resources Are Mandatory

All user-visible text must use `stringResource()`. Hardcoded strings in Composables are not allowed.

```kotlin
// ✅
Text(stringResource(R.string.note_detail_save_button))

// ❌
Text("Save")
```

---

## Where to Define Strings

All strings are defined in:
```
app/src/main/res/values/strings.xml
```

---

## Naming Convention

Use descriptive, prefixed keys:

Pattern: `<screen>_<component>_<type>`

```xml
<!-- ✅ -->
<string name="note_detail_title_label">Note</string>
<string name="home_empty_state_message">No notes yet</string>
<string name="folders_create_button_label">New Folder</string>

<!-- ❌ -->
<string name="title">Note</string>
<string name="button1">New Folder</string>
```

---

## Plural Strings

Use `plurals` for count-dependent strings:

```xml
<plurals name="notes_count">
    <item quantity="one">%d note</item>
    <item quantity="other">%d notes</item>
</plurals>
```

Access with:
```kotlin
pluralStringResource(R.plurals.notes_count, count, count)
```

---

## Dynamic Content

For strings with dynamic values, use format arguments:

```xml
<string name="note_shared_by_label">Shared by %s</string>
```

```kotlin
stringResource(R.string.note_shared_by_label, ownerName)
```

---

## Content Descriptions

Provide content descriptions for all non-text interactive elements (icons, image buttons) to support accessibility:

```kotlin
IconButton(onClick = onDeleteClick) {
    Icon(
        imageVector = Icons.Default.Delete,
        contentDescription = stringResource(R.string.note_delete_icon_description)
    )
}
```
