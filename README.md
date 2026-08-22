# Android Agent Harness

> A battle-tested development, execution, and evaluation harness for AI coding agents to build, verify, and maintain production-grade Android applications safely, deterministically, and with high code quality.

---

## 📖 Complete Guide & Background

For the complete setup guide, architectural rationale, and real-world case study of this harness environment, please read the article on Medium:

👉 **[Harness Engineering: How to Set Up an Android Agent Harness](https://weidianhuang.medium.com/harness-engineering-how-to-set-up-an-android-agent-harness-b7154d9e3471)**

---

## 🎯 Overview

Modern AI coding agents (such as Google Antigravity, Claude Code, OpenAI Codex, Cursor, Windsurf, and Copilot) possess strong code generation capabilities but can easily deviate into architecture violations, bloated context windows, untested edge cases, and hallucinations when unconstrained.

This repository provides an **Agent Harness** designed to:
- **Raise the Quality Floor**: Mandate strict architecture layers (Data, Domain, UI), Compose best practices, unidirectional state flow, and comprehensive test coverage (unit, integration, instrumented UI).
- **Lower the Blast Radius**: Enforce incremental vertical slices, strict stage gates, and deterministic quality checks before code lands.
- **Optimize Context Efficiency**: Use a 3-tier layered context loading protocol (L1 / L2 / L3) to keep context windows under 40% fill.
- **Separate Agent Roles**: Distinct execution modes for **Planner**, **Coder / Generator**, and **Evaluator**.

---

## 🚀 Setting Up the Harness in Your Android Project

### 1. Add as a Git Submodule

From your Android project root:

```bash
git submodule add -b main git@github.com:hwdavr/android-agent-harness.git .harness
```

### 2. Create Root Symlinks

Create symlinks at the root of your project pointing into the `.harness` submodule:

**macOS / Linux:**
```bash
ln -s .harness/.agents .agents
ln -s .harness/harness harness
```

**Windows (PowerShell as Admin):**
```powershell
New-Item -ItemType SymbolicLink -Path ".agents" -Target ".harness/.agents"
New-Item -ItemType SymbolicLink -Path "harness" -Target ".harness/harness"
```

### 3. Copy `AGENTS.md` to Project Root

Copy or adapt `.harness/AGENTS.md` to your project root so agent tools can discover it immediately:

```bash
cp .harness/AGENTS.md ./AGENTS.md
```

---

## 🧠 Context Management Protocol (L1 / L2 / L3)

To prevent LLM performance degradation and context dilution, context is loaded in strict layers:

| Layer | When to Load | Contents |
|---|---|---|
| **L1 — Always Loaded** | Every session start | `AGENTS.md` + `rules/android-architecture.md` + `rules/testing-strategy.md` |
| **L2 — Phase-Triggered** | During active workflow stage | The exact skill(s) specified in the active stage's `Load` instruction (e.g. `android-implementation`, `ui-verification`) |
| **L3 — On-Demand** | When specifically needed | Specific rules (`compose-rules.md`, `api-contract-rules.md`), `docs/knowledge/`, OpenAPI schemas |

> **Rule:** Never preload all rules and skills upfront. Only load what the active stage requires.

---

## 🔄 Workflows & Execution Pipelines

### Project-Based Development (Complex Features)
Used for multi-slice, significant features requiring systematic requirement analysis and evaluation:

1. **Planning (`.agents/workflows/harness-planning.md`)**
   - Clarifies ambiguities and generates `spec.md` and `design.md`.
   - Decomposes requirements into vertical slices in `feature_list.json` and schedules a `sprint-contract.md`.
2. **Generation (`.agents/workflows/harness-generator.md`)**
   - Implements each vertical slice incrementally (Data → Domain → UI → Tests → Quality Gates).
   - Validates each slice before advancing to the next.
3. **Evaluation (`.agents/workflows/harness-evaluation.md`)**
   - Conducts independent code, test, visual, and architectural reviews against evaluation rubrics.
4. **Fixing (`.agents/workflows/harness-fix.md`)**
   - Resolves any findings if evaluation score is below 5.0/5.

### Ad-Hoc Development (Simple Tasks & Bug Fixes)
- **`feature-delivery.md`**: Direct end-to-end implementation for simple features.
- **`bug-fixing.md`**: Reproduction test first → surgical fix → regression verification.
- **`create-ui-and-verify.md`**: Focused on pixel-perfect Composable styling against design mockups.
- **`feature-review.md`**: Pre-merge independent review checklist.

---

## 🛠️ Automated Scripts & Rule Checkers

The harness includes validation scripts located in `harness/scripts/`:

| Script | Purpose |
|---|---|
| `check-architecture-rules.sh` | Validates layer boundaries, package imports, and DTO isolation |
| `check-compose-rules.sh` | Checks Compose best practices, `testTag` presence, and statelessness |
| `check-localization-rules.sh` | Detects hardcoded strings in UI composables |
| `check-feature-lifecycle.sh` | Validates feature tracking state and artifact integrity |
| `check-visual-evidence-contract.sh` | Enforces visual screenshot verification artifacts |
| `check-test-assertions-quality.sh` | Ensures tests do not use shallow/envelope-only assertions |
| `auto-harness-generator.sh` | Headless runner for automating multi-slice generation loops |

Run any check directly from your project root:
```bash
bash harness/scripts/check-architecture-rules.sh
bash harness/scripts/check-compose-rules.sh
bash harness/scripts/check-localization-rules.sh
```

---

## 🤖 Agent Tool Compatibility

| Tool | Integration Method |
|---|---|
| **Google Antigravity IDE** | Reads `AGENTS.md` automatically; executes skills natively via IDE tools. |
| **Codex CLI / Claude Code** | Run `codex-harness-generator.sh` or prompt: `"Load context for the project"` to trigger `context-management`. |
| **Cursor / Windsurf** | Add `AGENTS.md` and `.agents/rules/` to `.cursorrules` / `.windsurfrules` or project context. |
| **GitHub Copilot Chat** | Reference `@workspace AGENTS.md` when initiating a development task. |

---

## 📚 References & Resources

- **Medium Article:** [Harness Engineering: How to Set Up an Android Agent Harness](https://weidianhuang.medium.com/harness-engineering-how-to-set-up-an-android-agent-harness-b7154d9e3471)
- **Reference Application:** [NotesTakingApp](https://github.com/weidianhuang/NotesTakingApp)
