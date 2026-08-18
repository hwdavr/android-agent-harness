---
name: shared-json-scenarios
description: Use this skill when defining or consuming cross-platform test scenarios shared by Android and iOS.
---

# Shared JSON scenarios skill

Use this skill when defining or consuming cross-platform test scenarios shared by Android and iOS.

## Purpose
A shared JSON scenario is the contract for:
- API mocking
- expected.domain behavior when validating repository/use case/domain outputs
- expected.ui behavior when validating ViewModel-driven UI state

## Recommended shape
Each scenario may contain:
- id
- description
- apiMocks
- expected.domain
- expected.ui
- tags

### Example shape
`sharedContracts/test-scenarios/bill_list_overdue_001.json`
```
{
  "id": "bill_list_overdue_001",
  "apiMocks": [
    {
      "method": "GET",
      "path": "/bills",
      "status": 200,
      "response": {
        "bills": [
          {
            "id": "bill_001",
            "title": "Water Bill",
            "status": "OVERDUE",
            "amount": 88.0
          }
        ]
      }
    }
  ],
  "expected": {
    "domain": {
      "billCount": 1,
      "bills": [
        {
          "id": "bill_001",
          "status": "OVERDUE",
          "payAllowed": true
        }
      ]
    },
    "ui": {
      "screen": "bill_list",
      "itemCount": 1,
      "items": [
        {
          "id": "bill_001",
          "title": "Water Bill",
          "statusLabel": "OVERDUE",
          "payEnabled": true
        }
      ]
    }
  }
}
```

## Rule by layer
- each API should have at least one integration test
- if an API is used by a ViewModel function, create an integration test backed by a shared JSON scenario and assert the ViewModel-exposed `UiState` against `expected.ui`
- if an API is used only by domain/repository/use case logic without directly changing UI state, create an integration test backed by a shared JSON scenario and assert `expected.domain`
- instrumented UI tests may also consume `expected.ui` when Android runtime behavior must be verified
- a shared scenario may contain both `expected.domain` and `expected.ui`, but each test should assert the layer it owns
- do not force every UI detail into the shared contract
- keep expectations logical, not pixel-perfect

## Good shared fields
- itemCount
- statusLabel
- actionEnabled
- selectedId
- destinationScreen
- emptyStateVisible

## Avoid in shared contract
- exact color values
- exact spacing
- platform-specific widget classes
- fragile UI hierarchy assumptions


