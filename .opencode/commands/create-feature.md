---
description: Scaffold a complete MVVM feature (ViewModel + View + tests) following Haishin conventions
agent: swift-dev
---

Scaffold a new MVVM feature named `$1` under `Haishin/Features/`.

**Parameters:**
- `$1` — **Required.** Feature name in `<Feature>` form (e.g. `Player`, `Downloads`). Do **not** include the `ViewModel`/`View` suffix.

## Path Resolution

| Variable | Value |
|----------|-------|
| `SOURCE_DIR` | `Haishin/Features/$1/` |
| `TEST_DIR` | `HaishinTests/Features/$1/` |

## Required Steps

1. **Load the `new-feature` skill** — it defines the blueprint and templates verbatim.

2. **If `$1` is empty**, ask: *"What is the feature name?"* and stop until the user answers.

3. **Verify nothing conflicts** at the target paths. If any files already exist, list them and ask whether to overwrite.

4. **Generate exactly these files** following the `new-feature` skill templates:

   ```
   <SOURCE_DIR>
   ├── Views/                          # subview components directory (populated as needed)
   ├── <Feature>View.swift              # Main View (under ~100 lines, purely declarative)
   └── <Feature>ViewModel.swift         # ALL business logic, @Observable, @MainActor
   ```

5. **Generate the mirrored test file** at `<TEST_DIR><Feature>ViewModelTests.swift` using the `new-feature` skill's test template. Include coverage for all public properties and methods.

6. **Self-verify** every generated file against the `swift-style` and `new-feature` skills before responding.

## Examples

- `/create-feature Player` → scaffolds `Haishin/Features/Player/PlayerView.swift`, `PlayerViewModel.swift`, `Views/`
- `/create-feature Downloads` → scaffolds `Haishin/Features/Downloads/DownloadsView.swift`, `DownloadsViewModel.swift`, `Views/`

## Out of Scope

This command does **not**:
- Register any navigation or routing entries
- Add Localization keys
- Generate additional subviews beyond the scaffold
