---
description: Review all Swift changes between the current branch and a base branch (default main) using the code-reviewer agent
agent: code-reviewer
subtask: true
---

Review the diff between the current branch (`HEAD`) and a base branch using the Haishin iOS style guidelines.

**Parameters:**
- `$1` — **Optional.** Base branch / ref to compare against. Defaults to `main` when omitted.

## Diff Semantics

Use the **three-dot** form (`<base>...HEAD`) so the review shows only commits introduced on the current branch since it diverged from the base.

Review **committed** changes only. Do NOT include unstaged or staged-but-uncommitted work.

## Required Steps

1. **Resolve the base ref.** If `$1` is empty or whitespace-only, use `main`. Otherwise use `$1` verbatim. If the ref does not exist locally, fail fast: `git rev-parse --verify --quiet <ref>`.

2. **Refuse to run on a dirty working tree** with a warning, but allow override.
   - Run `git status --porcelain`.
   - If non-empty, report: *"Your working tree has uncommitted changes. The review will only cover committed changes vs `<base>`. Continue? (y/n)"* and stop until the user answers.

3. **Enumerate changed Swift files:**
   ```
   git diff --name-only --diff-filter=ACMR <base>...HEAD -- '*.swift'
   ```
   If empty, report *"No Swift changes between `<base>` and `HEAD`. Nothing to review."* and stop.

4. **Collect the diff hunks** for each file:
   ```
   git diff --unified=10 <base>...HEAD -- <file>
   ```

5. **Load the relevant skills** based on what changed:
   - Any Swift file → `swift-style`
   - Files matching `**/ViewModel*.swift`, `**/View*.swift` → `new-feature`
   - Files in `HaishinTests/` → `swift-style`

6. **Review only the changed lines** — do not flag pre-existing issues in surrounding context.

   For each violation:
   ```
   <file_path>:<line_number>
     [<severity>] <skill-name>: <description>
   ```

   Severities:
   - **error** — clear skill violation
   - **warning** — likely convention deviation
   - **info** — style suggestion

7. **Group findings by file**, ordered by line number ascending.

8. **Summarize** with:
   - Total Swift files reviewed
   - Total findings by severity
   - Skills that were loaded
   - The git diff range used

9. **If nothing to flag**, say so explicitly.

## Out of Scope

This command does **not**:
- Modify any files
- Run tests (use `/test`)
- Review non-Swift files
- Review uncommitted changes

## Examples

- `/review-diff` → reviews `main...HEAD`
- `/review-diff develop` → reviews `develop...HEAD`
