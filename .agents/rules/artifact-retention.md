# Artifact Retention

Harness runs produce raw output (Gradle, adb and agent logs, APK copies, recordings, captures) on every
attempt. Keep it only while it can still be cited, reused or reviewed; keep the written record for good.
`harness/scripts/prune-harness-artifacts.py` applies this rule. It is a dry run unless given `--apply`.

## Always kept

- The written record of every workspace: Markdown, JSON and YAML files, design exports, and anything git tracks.
- Every file in a workspace whose Harness Feature Tracker status is not `Complete`. `To be reviewed`,
  `To be fixed` and `To be human reviewed` still need their evidence, and receipt reuse
  (`check-evidence-receipt.sh`) depends on it.
- Any `.qa-artifacts/` run that an open workspace names, in its Markdown, JSON, YAML, text or log files.
- The newest 5 runs in `.qa-artifacts/` and the newest 5 in `.qa-artifacts/android-instrumented/`.
- Anything changed in the last 14 days.

## Pruned

- Untracked raw output (`*.log`, `*.apk`, `*.aab`, `*.mp4`, `*.webm`, `*.ndjson`, `*.hprof`, `*.trace`,
  `*.logcat`) inside a `Complete` workspace. Its summary keeps the commands, exit codes and results that
  the logs backed.
- `.qa-artifacts/` runs that are older than 14 days, outside the newest 5, and named by no open workspace.
- The scheduler log (`~/Library/Logs/com.<slug>.harness-generator.log`), rotated in place above 5 MB
  with 3 older copies kept.

## When it runs

- `auto-harness-generator.sh` runs `--apply` after it takes the harness lock, on every scheduler tick, and
  rotates the log named by `HARNESS_GENERATOR_LOG`. A prune failure is reported but never blocks a session.
- The Clean Exit stage of `single-lane-generator` and `sliced-lane-generator` runs it with `--apply`
  after the session handoff is written.
- `feature-review` and `harness-evaluation` run it with `--apply` as their last step, after the tracker update.
- Run it by hand any time: `python3 harness/scripts/prune-harness-artifacts.py` previews, `--apply` prunes.

## Rules for agents

- Cite evidence by a path inside the workspace or by the full `.qa-artifacts/<run>` path, so the prune
  script sees the reference.
- Record the result that matters (command, exit code, pass counts, failing test) in the summary. Never
  rely on a raw log surviving after the tracker row reaches `Complete`.
- Never delete evidence by hand to free space, and never prune a workspace that is not `Complete`.
- Do not change the defaults to make a gate pass. Pass `--keep-runs` or `--min-age-days` only when the
  user asks.
