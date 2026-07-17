---
name: new-feature
description: "Use when the user asks to create, scaffold, add, or implement a new feature, module, screen, or view in the Haishin app. Scaffolds the full MVVM structure under Haishin/Features/<FeatureName>/ with Views/ subdirectory, main View, ViewModel, and corresponding test file in HaishinTests."
---

# New Feature Scaffolding

When the user asks to create a new feature, follow this blueprint under `Haishin/Features/`:

## Directory Structure

```
<FeatureName>/
├── Views/
│   └── <FeatureName>Row.swift      // Subview components
├── <FeatureName>View.swift          // Main View (under ~100 lines)
└── <FeatureName>ViewModel.swift     // ALL business logic
```

## Test File

Create a corresponding test file at the mirrored path in `HaishinTests`:

```
HaishinTests/Features/<FeatureName>/<FeatureName>ViewModelTests.swift
```

### Test file template

```swift
import Testing
@testable import Haishin

@Suite("<FeatureName>ViewModel Tests")
@MainActor
struct <FeatureName>ViewModelTests {

    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, ...")
    func initialization_somePropertyIsSet() {
    }
}
```

## ViewModel Requirements

- Use `@Observable` macro (not `ObservableObject` or `@Published`)
- Use `@MainActor` if updating UI
- Inject dependencies via protocol parameters — no default MainActor-isolated values
- All properties `private` by default
- Group properties under hash-bordered MARK sections

## View Requirements

- Use `@State` for local lifecycle ownership of `@Observable` instances
- Use `@Bindable` for property bindings to an existing `@Observable` instance
- Keep views purely declarative — no business logic
- Keep the main view file small; extract subviews into `Views/` folder

## Code Style

Apply all rules from the **swift-style** skill (MARK comments, alignment, logging, optional binding, spacings, etc.).
