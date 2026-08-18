---
name: competitor-analysis
description: Research and compare a software repository with current competitors using primary evidence, shared metric rubrics, and conservative scoring, then identify gaps and recommend exactly one feasible PR-sized next feature. Use for product strategy, competitive parity, roadmap prioritization, or next-feature decisions; keep the work read-only unless implementation is explicitly requested.
---

# Competitor Analysis

## Objective

Produce a current, auditable comparison of the repository's product with 5–8 maintained competing or analogous products. Convert observed gaps into 3–7 thin feature opportunities, score them, and recommend exactly one valuable, feasible feature that fits one coherent PR.

## Non-negotiable guardrails

- Inspect the repository read-only. Do not edit source, tests, documentation, generated files, or configuration; do not create an analysis artifact in the repository unless explicitly requested.
- Do not implement, commit, push, open, or create a PR. Treat a later implementation request as a separate task.
- Browse for current competitor information. Never fill current facts from memory when a direct source can be checked.
- Separate `Fact` (directly documented or observed), `Inference` (reasoned from facts), and `Opinion` (judgment or recommendation). Label those distinctions in prose or score reasons.
- Compare observable capabilities and user outcomes, not slogans, popularity, funding, or marketing adjectives. Treat every score as a reasoned estimate, not an objective measurement.
- Preserve dirty-worktree changes. Never reset, checkout, stash, reformat, or otherwise alter user work.

## Workflow

### 1. Establish the project baseline

Inspect enough repository evidence to understand the product before choosing metrics or competitors. Start with the repository's instruction files, then inspect the project-specific equivalents of:

- README files, product goals, roadmap, specs, design documents, changelogs, and recent implementation summaries;
- package manifests, build files, permissions, platform declarations, dependency policy, architecture boundaries, privacy/security rules, and offline/network constraints;
- shipped screens and workflows, domain/data models, public APIs, release configuration, and feature flags;
- unit, integration, instrumented, end-to-end, fixture, and visual-verification tests plus CI/release checks;
- recent commits and relevant diffs, while distinguishing unfinished work from shipped behavior.

Record the project name, category, target users and jobs, platform/runtime, business model when known, maturity/release state, shipped versus planned capabilities, current product goals, architecture, security/privacy constraints, and verification harness. Cite repository paths, symbols, or line anchors for material claims. Prefer executable code and passing test/evidence artifacts over aspirational documentation when they disagree. Mark anything not established as unknown.

Do not run a command that writes build output or changes dependency state merely to investigate. Read tests and harness definitions; run verification only when it is read-only and explicitly useful.

### 2. Select and research the comparison set

Browse the web and select 5–8 maintained products in total:

- Prefer direct competitors serving the same user, job, and product category on a comparable platform.
- Add an adjacent product only when necessary to expose a meaningful alternative or fill a genuine market gap. Label it `Adjacent` wherever it appears and explain why it is included.
- Require current maintenance evidence where practical: a recent official release, changelog, repository activity, current app-store listing/version, or current official documentation. Exclude abandoned or stale products unless a shortfall forces inclusion and the evidence limits say so.
- Prefer official product pages, documentation, support articles, release notes, app stores, and official repositories. Use third-party sources for discovery or corroboration, not as the sole support for a material capability claim.
- Open the source page and cite the direct page URL immediately beside every material competitor claim. Do not cite a search-results page. Record the research date and source date/version when available.

For each product, capture only capabilities that are observable in the cited source: supported workflows, platform availability, limits, privacy/data handling, export or recovery behavior, accessibility/usability evidence, and maintenance signals. Do not infer that an undocumented feature exists. Distinguish `Absent` (explicitly contradicted or not offered) from `Unverified` (not established by the available evidence).

Explain comparability limits before scoring. Note platform, audience, maturity, business-model, pricing, and distribution differences. Adjust interpretation for the target user's context, but do not change a metric's rubric from product to product.

### 3. Define project-specific metrics and rubrics

Choose 4–6 metrics after inspecting the project and comparison set. Make them concrete, observable, and relevant to the product's target user. Include all of the following:

- at least one core-capability metric, such as the quality or completeness of the product's primary job;
- at least one usability metric, such as task clarity, friction, discoverability, accessibility, or recovery from mistakes;
- at least one trust or reliability metric, such as privacy, offline behavior, data safety, correctness, stability, undo/recovery, or export integrity.

Name metrics so they are not disguised features. Define what 1/10, 5/10, and 10/10 mean for every metric in one `Metric rubrics` table. Use the same rubric for every product and the current project; use intermediate scores only when the evidence supports interpolation. Do not use a generic weighted average to hide a severe weakness.

### 4. Score every product against every metric

Create one auditable row for every product–metric pair, including the current project. Use this exact table header:

| Name of app | Metric | Metric score /10 | Reason for the score |
|---|---|---:|---|

Name the current-project rows exactly `Current project — <project name>`. Give a numeric 1–10 score for every row using the shared rubric. Keep reasons concise but auditable: state the observed fact, identify an inference if used, and attach a direct citation for each material competitor claim. Cite current-project evidence with a repository path/link and test or implementation anchor when possible.

When a capability is unverified, score conservatively at the lowest level supported by evidence, prefix the reason with `Unverified`, and say what was not established. Do not present an unverified capability as absent. If evidence is incomplete for all products, disclose that limitation rather than pretending the score is precise.

### 5. Convert gaps into feature opportunities

Compare the current project with the scorecard and evidence, then define 3–7 concrete opportunities. Make each opportunity a thin vertical slice with one user outcome, one coherent change boundary, and a repeatable verification path. Avoid bundles such as “improve the editor” or “add AI”; name the smallest user-visible capability that addresses the gap.

Score every opportunity using exactly these fields:

- `ROI /10`: expected user value, reach, gap severity, strategic differentiation, and leverage against the stated product goal;
- `Complexity to create a PR /10`: scope and integration risk of one coherent PR, where 1 is easiest and 10 is broadest or most uncertain;
- `Confidence to create it and pass harness /10`: confidence based on existing architecture, dependencies, fixtures, test seams, platform constraints, and observable acceptance criteria.

Use the exact feature-table header below and no additional score columns:

| Feature | Description | ROI /10 | Reasons for ROI | Complexity to create a PR /10 | Confidence to create it and pass harness /10 |
|---|---|---:|---|---:|---:|

Include in each description the user outcome, the evidence-backed gap it addresses, and a short boundary or harness hint. Keep the reasons for ROI separate from complexity and confidence. Do not treat a high ROI score as permission to recommend work that violates the repository's architecture, security, privacy, dependency, platform, localization, or testing rules.

### 6. Recommend exactly one next feature

Select one opportunity only. Prefer the best balance of user value, strategic importance, PR-sized complexity, harness confidence, and compatibility with the repository's constraints. Resolve ties explicitly in the reasoning, but do not present a second recommendation or a ranked shortlist in the final section.

Describe the selected feature's:

- smallest useful implementation boundary: the in-scope user flow and the specific layers/components/data changes required; explicitly exclude follow-on polish and adjacent features;
- verification harness: deterministic fixtures or scenarios, unit/integration/instrumented/visual tests as appropriate, acceptance assertions, and the relevant existing commands or gates;
- primary risk: the most likely correctness, privacy, platform, performance, adoption, or evidence risk and one mitigation or containment strategy.

Keep the boundary compatible with the discovered architecture. For example, honor a repository's offline or no-network boundary, permission policy, dependency budget, data ownership, UI-state rules, accessibility requirements, localization rules, test tags, and coverage gates when those rules exist.

## Evidence discipline

Use direct Markdown links such as `[official export documentation](https://example.com/page)` beside the claim they support. A single citation may support several adjacent facts only when the page clearly covers all of them. Cite release/version dates for maintenance claims. Do not cite a competitor's home page for a specific capability unless that capability is actually documented there.

Use local source evidence for the current project and web evidence for competitors. Make it clear when a statement is a documented fact, an inference from several facts, or an opinion. In score reasons, say `Not found` only as a search result, never as proof of absence; say `Absent` only when a reliable source explicitly supports absence.

## Required output contract

Start the response with these three lines, before any heading:

```text
Project category: <category>
Research date: <YYYY-MM-DD>
Competitor-selection method: <how the 5–8 products were selected, including direct/adjacent labels and maintenance evidence>
```

Then use this order:

1. Brief project baseline and comparability notes, including target users, platform, maturity, business-model differences, and relevant constraints.
2. A `Metric rubrics` table with exactly these columns:

   `Metric | 1/10 | 5/10 | 10/10`

3. An auditable scorecard with exactly these columns:

   `Name of app | Metric | Metric score /10 | Reason for the score`

   Include one row per product-metric pair and include `Current project — <project name>`.
4. An `Evidence limits` note that lists stale, inaccessible, paywalled, platform-mismatched, undocumented, or otherwise unverified evidence and explains how it affected scoring.
5. A feature-opportunities table with exactly these columns:

   `Feature | Description | ROI /10 | Reasons for ROI | Complexity to create a PR /10 | Confidence to create it and pass harness /10`

   Include 3–7 opportunities.
6. A final `Proposed next feature` section containing exactly one recommendation, followed by its smallest useful implementation boundary, verification harness, and primary risk.

End the response with this exact sentence, replacing the placeholder with the recommended feature name and adding nothing after it:

`Would you like me to create a PR for **<feature>**?`

Do not append a sources appendix, second recommendation, implementation steps, commit instructions, or a PR after that sentence.
