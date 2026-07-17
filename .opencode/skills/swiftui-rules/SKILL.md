---
name: swiftui-rules
description: "Use when writing or reviewing SwiftUI code. Covers spacing constants, Swift Observation (@Observable/@State/@Bindable), SwiftUI view splitting (invalidation boundaries, 4 isolators), and @MainActor-ViewModel patterns."
---

## SwiftUI Rules

You MUST follow these rules when writing or modifying SwiftUI code in this project.

### Spacings

Use predefined spacing constants from `CGFloat+Additions.swift`:
- `.spacingXS`, `.spacingS`, `.spacingM`, `.spacingL`, `.spacingXL`

NEVER use raw CGFloat values for spacing.

### Swift Observation Guidelines

When generating SwiftUI code, strictly follow the Swift 5.9+ Observation framework:

1. **Model Declaration**: Use `@Observable` macro on classes. Do not use `ObservableObject` or `@Published`.
2. **View State**: Use `@State` for local lifecycle ownership of `@Observable` instances. Use `@Bindable` for local property bindings to an existing `@Observable` instance.

```swift
@Observable
class FeatureViewModel {
    var title = "Hello"
}

struct FeatureView: View {
    @State private var viewModel = FeatureViewModel()
    
    var body: some View {
        TextField("Edit", text: $viewModel.title)
    }
}
```

### SwiftUI View Splitting (Invalidation Boundaries)

Each separate `View` struct creates its own invalidation boundary — SwiftUI can skip re-evaluating its `body` when its inputs are unchanged. Computed properties (`private var section: some View`) and `@ViewBuilder` functions do NOT create new boundaries; they re-run whenever the parent body runs. In practice, most subviews don't need their own boundary — the re-evaluation cost is negligible. The 4 isolators below define the specific cases where it matters.

**Default: Prefer `@ViewBuilder` computed properties / local helper functions.**
**Upgrade to a dedicated `View` struct only when one of the 4 isolators applies.**

#### Default — @ViewBuilder computed property or helper function

Start here. A `@ViewBuilder` computed property or function keeps the code local, readable, and avoids unnecessary type proliferation. This is the right default until you need one of the isolators below.

```swift
// CORRECT — default approach for most cases
struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        VStack {
            headerSection
            statsSection
            recentActivitySection
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        if viewModel.isLoggedIn {
            UserAvatarView(user: viewModel.user)
            Text("Welcome back, \(viewModel.user.name)")
        } else {
            LoginPromptView()
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        HStack(spacing: .spacingM) {
            StatCard(label: "Steps", value: "\(viewModel.steps)")
            StatCard(label: "Calories", value: "\(viewModel.calories)")
        }
    }

    @ViewBuilder
    private var recentActivitySection: some View {
        ForEach(viewModel.recentActivities.prefix(5)) { activity in
            ActivityRow(activity: activity)
        }
    }
}
```

#### When to extract a struct — The 4 Isolators

Only extract to a dedicated `View` struct when the section meets **one or more** of these criteria:

**1. Local State Isolation (The State Rule)**
If the subview needs its own localized `@State` that the rest of the screen doesn't care about, extract a struct. Keeping local state in the parent forces the entire parent body to re-evaluate on every toggle.

```swift
// WRONG — expand/collapse state in parent pollutes its invalidation boundary
struct DashboardView: View {
    @State private var isDetailsExpanded = false

    var body: some View {
        VStack {
            if isDetailsExpanded {
                DetailExpandedView()
            }
            Button("Toggle") { isDetailsExpanded.toggle() }
        }
    }
}
```

```swift
// CORRECT — local state lives in its own boundary
private struct ExpandableDetailCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack {
            if isExpanded {
                DetailExpandedView()
            }
            Button("Toggle") { isExpanded.toggle() }
        }
    }
}
```

**2. Lazy Container Rows (The Scroll Rule)**
If the UI block is a row or cell inside a `List`, `LazyVStack`, `LazyHStack`, or `LazyVGrid`, extract a struct. SwiftUI's lazy loading, cell recycling, animations, and swipe-to-delete rely on explicit view identity. Inline computed properties in lazy containers cause buggy scroll animations and redundant layout passes.

```swift
// WRONG — inline in lazy container breaks identity
List(viewModel.items, id: \.id) { item in
    itemRow(item)
}

@ViewBuilder
func itemRow(_ item: Item) -> some View {
    HStack { Text(item.name); Spacer(); Text(item.value) }
}
```

```swift
// CORRECT — dedicated struct for lazy container rows
List(viewModel.items, id: \.id) { item in
    ItemRow(item: item)
}

private struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack { Text(item.name); Spacer(); Text(item.value) }
    }
}
```

**3. Reusability (The Shared Code Rule)**
If the exact same UI component is used in more than one parent view, extract a struct. Self-explanatory DRY practice. If it's only used on this one screen, a `@ViewBuilder` computed property in the same file is perfectly fine.

**4. Complex Layout / Compiler Relief (The Scale Rule)**
If the parent view's body is getting massive — slowing the Swift compiler, or tracking 20+ `@Observable` properties — extract structs to prune dependency footprints. A child struct that only reads `viewModel.status` won't trigger the parent's complex layout code when unrelated state changes. This also keeps files human-readable.

```swift
// WORTH EXTRACTING — prunes parent's dependency footprint
private struct StatusBadge: View {
    let status: ConnectionStatus

    var body: some View {
        Label(status.displayName, systemImage: status.icon)
            .foregroundColor(status.color)
    }
}
```

#### DO: Pass narrow inputs (not the whole store)

Whether using a computed property or a struct, pass only what the subview reads. This minimises invalidation surface area.

```swift
// CORRECT — narrow inputs
AdventureCompletionCard(
    selectedRoute: selectedRoute,
    distanceWalked: store.walkSession.distanceWalked,
    newlyUnlockedMilestones: store.walkSession.newlyUnlockedMilestones
)
```

#### Decision Flow

```
Want to split a large view?
         │
         ▼
Does it meet any of the 4 isolators?
  1. Local State Isolation
  2. Lazy Container Row
  3. Reusability (used in 2+ parents)
  4. Complex Layout / Slow Compiler
         │                  │
       YES                  NO
         ▼                  ▼
   Struct (View)     @ViewBuilder
                     computed property
```

#### Checklist for reviews

1. Default to `@ViewBuilder` computed properties — only extract a struct for an isolator reason.
2. **Local State Rule:** Does this section manage its own `@State`? → extract.
3. **Scroll Rule:** Is this a row inside `List` / `LazyVStack` / `LazyVGrid`? → extract.
4. **Reusability Rule:** Used in 2+ parent views? → extract.
5. **Scale Rule:** Is the parent body massive or slow to compile? → extract.
6. Always pass the narrowest possible inputs (`Bool`, `String`, `enum`, model) — never the whole store unless every field is consumed.
7. Don't use custom `.applyIf` modifiers that wrap conditionals — prefer `modifier(value ? a : b)`.

### Avoid MainActor-Isolated Default Parameters

Do not use default parameters in init that involve MainActor-isolated types. This causes compiler warnings.

```swift
// WRONG - Triggers warning
@MainActor
@Observable
final class VideoListViewModel {
    init(service: DataService = .shared) { ... }
}

// CORRECT - Explicit dependency injection
@MainActor
@Observable
final class VideoListViewModel {
    init(service: DataService) { ... }
}
```
