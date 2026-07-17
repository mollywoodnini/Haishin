# Agents.md

This file provides high-level project guidance. Detailed rules are delegated to skills.

## Skills

- **swift-style** — All Swift code formatting, style, and documentation conventions.
- **new-feature** — Scaffolds new MVVM features with Views/, ViewModel, and test files.
- **add-source** — Creates a new Haishin JavaScript source by live-scraping a target website. Fetches the site, analyzes HTML structure, and generates a complete source.js following the JS source contract.

## Agents

- **swift-dev** — Primary development agent for writing Swift/SwiftUI code. Loads skills proactively.
- **code-reviewer** — Read-only subagent for diff-based code reviews against project style and architecture.
- **test-writer** — Subagent for writing ViewModel unit tests following Haishin conventions.
- **source-adder** — Expert in Haishin app architecture, web scraping, and JavaScript. Fetches target websites, analyzes HTML structure, and generates complete source.js files following the Haishin JS source contract. Uses the `add-source` skill.

## Architecture

### MVVM & Logic Separation
- ViewModel is the sole coordinator for business logic.
- Views are purely declarative — no Services/Managers instantiation, no business logic.
- All calls to Services, Managers, API fetching, data filtering, and state transformation must reside in the ViewModel.

### Directory Structure
- Subviews (`*Row.swift`, `*Header.swift`, `*Cell.swift`) → `Features/<Name>/Views/`
- Main view files kept under ~100 lines; extract subviews into `Views/` folder.
- New features follow the blueprint: `FeatureName/Views/`, ViewModel, View.

## Testing
- Every ViewModel requires a corresponding test in `HaishinTests`.
- 100% coverage of public properties and methods.
- File naming: `[ViewModelName]Tests.swift`.
- Folder structure mirrors `Haishin/Features/`.

## Commands

- `/test` — Run unit tests via Fastlane (`bundle exec fastlane tests`) and parse results.
- `/review-style` — Review code against Haishin style guidelines using the `code-reviewer` agent.
- `/review-diff` — Review all Swift changes between current branch and a base branch.
- `/create-feature` — Scaffold a new MVVM feature (ViewModel + View + tests) using the `new-feature` skill.
- `/check-tests` — Verify a ViewModel has a corresponding test file with proper coverage.
- `/add-source` — Creates a new Haishin JavaScript source by live-scraping a target website. Fetches the site, analyzes HTML structure, and generates a complete source.js following the JS source contract.

## Plugins

- **require-skills** — Blocks `edit`/`write` on Swift files until the matching skill is loaded. Load `swift-style` before any Swift file; load `new-feature` before ViewModels.
- **guardrails** — Blocks access to secret/credential files and destructive bash commands. After Swift edits, reminds to verify against skills.

## Dependencies
- Swift Package Manager (SPM) only.
