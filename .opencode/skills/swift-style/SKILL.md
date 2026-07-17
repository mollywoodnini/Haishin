---
name: swift-style
description: "Use when writing or reviewing Swift code. Covers all Haishin formatting, style, and documentation conventions: MARK comments, vertical alignment, line length, constants, spacings, logging, Swift Observation, and Swift 6 concurrency."
---

## Swift Code Style Guidelines

You MUST follow these formatting rules when writing or modifying Swift code in this project.

### MARK Comments

Always use this specific format for MARK comments. Each MARK block must be wrapped in a border of 81 hash characters (#):

```swift
//#################################################################################
// MARK: - <Title>
//#################################################################################
```

**Vertical Spacing Rules:**
1. **First Marker:** Exactly ONE newline between type declaration and first section marker
2. **Subsequent Markers:** Exactly TWO newlines before every following section marker
3. **After Marker:** Only ONE newline after each section marker

```swift
class MyService {
    // Exactly one newline here
    //#################################################################################
    // MARK: - Properties
    //#################################################################################
    
    let id: UUID


    // Exactly two newlines here
    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################
}
```

Outside of types, markers should have TWO newlines before they start.

### Function & Initializer Wrapping

**Single Line Rule:** If 2 or fewer parameters, keep on single line.

**Explicit Init Rule:** When calling an initializer with 0–2 arguments, use the implicit `.init(...)` or type-name form on one line.

**Multi-line Rule:** If 3+ parameters, explode the argument list — opening `(` at end of the first line, one argument per line, closing `)` on its own line. Do not vertically align to the opening parenthesis.

```swift
// CORRECT - 1-2 Parameters: Single Line
let response = HTTPURLResponse(url: url, statusCode: 200)

// CORRECT - 3+ Parameters: Exploded
let example = HTTPURLResponse(
    url: url,
    statusCode: statusCode,
    httpVersion: nil,
    headerFields: responseHeaders
)

// WRONG - Vertically aligned
let example = HTTPURLResponse(url: url,
                              statusCode: statusCode,
                              httpVersion: nil,
                              headerFields: responseHeaders)
```

### Switch Case Alignment

Subsequent patterns must vertically align with the first pattern:

```swift
// CORRECT
case .checkInNotPossible,
     .restrictedBoardingPass:
    return .spacingM

// WRONG
case .checkInNotPossible,
         .restrictedBoardingPass:
    return .spacingM
```

### Line Length & Wrapping

- **Trigger:** Lines exceeding 100 characters must be wrapped.
- **Style:** Explode the argument list — opening `(` at end of the first line, one argument per line, closing `)` on its own line (see **Function & Initializer Wrapping**). Do not vertically align to the opening parenthesis.

```swift
// CORRECT
public init(
    cookieStorage: HTTPCookieStorageProtocol = HTTPCookieStorage.shared,
    sessionProvider: NetworkSessionProvider? = nil,
    reachability: ReachabilityProtocol = Reachability.shared
)

// WRONG - too long
public init(cookieStorage: HTTPCookieStorageProtocol = HTTPCookieStorage.shared, sessionProvider: NetworkSessionProvider? = nil, reachability: ReachabilityProtocol = Reachability.shared)

// WRONG - vertically aligned to the opening parenthesis
public init(cookieStorage: HTTPCookieStorageProtocol = HTTPCookieStorage.shared,
            sessionProvider: NetworkSessionProvider? = nil,
            reachability: ReachabilityProtocol = Reachability.shared)
```

### Preprocessor Directive Indentation

`#if`, `#else`, `#endif` should be at the SAME indentation level as surrounding code, NOT at column 0:

```swift
// CORRECT
func configure() {
    setupUI()
    #if DEBUG
    enableDebugMode()
    #endif
    finalizeSetup()
}

// WRONG
func configure() {
    setupUI()
#if DEBUG
    enableDebugMode()
#endif
    finalizeSetup()
}
```

### Constants & Magic Numbers

NEVER use magic numbers directly in code. Always store constants in a private enum at the top of type declarations:

```swift
struct Example {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private enum Constants {
        static let animationDuration: TimeInterval = 0.3
        static let maxRetryCount: Int = 3
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################
    
    // ... logic follows
}
```

**Magic Number Examples:**

```swift
// WRONG - Magic numbers in code
if delay >= 15 { ... }
let timeout: TimeInterval = 30.0
for _ in 0..<3 { retry() }

// CORRECT - Named constants
if delay >= Constants.delayThresholdMinutes { ... }
let timeout: TimeInterval = Constants.requestTimeout
for _ in 0..<Constants.maxRetryCount { retry() }
```

**Exceptions:** `0`, `1`, `-1` are acceptable when their meaning is obvious (e.g., array indices, incrementing).

### Spacings

Use predefined spacing constants from `CGFloat+Additions.swift`:
- `.spacingXS`, `.spacingS`, `.spacingM`, `.spacingL`, `.spacingXL`

NEVER use raw CGFloat values for spacing.

### Optional Binding Shorthand (Swift 5.7+)

Use the shorthand syntax for optional binding when the unwrapped variable name matches the optional:

```swift
// WRONG - Redundant variable name
if let remainingTime = remainingTime { ... }
guard let viewModel = viewModel else { return }

// CORRECT - Shorthand syntax
if let remainingTime { ... }
guard let viewModel else { return }
```

**Note:** Use the full syntax only when you need a different variable name:

```swift
// CORRECT - Different name needed
if let unwrappedTime = optionalTime { ... }
```

### Implicit Return (SE-0255)

Omit the `return` keyword whenever the body is a **single expression** (Swift 5.1+). This applies to computed properties, functions, closures, getters, and subscripts.

```swift
// CORRECT - Implicit return
var fullName: String { "\(givenName) \(familyName)" }

func reversed() -> String { String(name.reversed()) }

list.filter { $0 > 5 }.map { $0 * 2 }

// WRONG - Redundant return
var fullName: String { return "\(givenName) \(familyName)" }

func reversed() -> String { return String(name.reversed()) }
```

### Extract Complex Expressions

When inline expressions become too long or reduce readability, extract them into computed properties or local variables.

```swift
// WRONG - Inline complex expression makes line too long
TextFieldView(text: birthDateTextBinding,
              placeholder: "Enter date",
              mode: .button(trailingIcon: viewConfiguration.contactData?.birthDate != nil ? .clear : .icon(Image(systemName: "calendar")),
                            action: { showDatePicker() }))

// CORRECT - Extracted to computed property
private var birthDateTrailingIcon: TextFieldView.TrailingButtonIcon {
    viewConfiguration.contactData?.birthDate != nil ? .clear : .icon(Image(systemName: "calendar"))
}

TextFieldView(text: birthDateTextBinding,
              placeholder: "Enter date",
              mode: .button(trailingIcon: birthDateTrailingIcon,
                            action: { showDatePicker() }))
```

**When to extract:**
- Ternary expressions with long conditions or values
- Expressions that exceed the line length limit (~100 characters)
- Logic that would benefit from a descriptive name
- Values reused in multiple places

**Extraction options:**
1. **Computed property** - when the value depends on instance state
2. **Local variable** - when used only within a single function/scope
3. **Constants struct** - for static values

### Access Control (Encapsulation)

Private by Default: All properties must be declared as private unless external access is strictly required. Always favor the most restrictive access level possible.

### Doc Comments — Public API Only

Use `///` doc comments **only** on declarations that form the public API of their module. This includes `public`, `open`, and implicit `internal` declarations (absence of access modifier is NOT a reason to skip docs).

- `public` and `open` — always documented.
- `internal` (no explicit modifier) — must be documented when they form a meaningful surface consumers rely on (e.g. ViewModel properties/methods, model types).
- `fileprivate` and `private` — NEVER use `///`. Use `//` comments for clarification if needed.

```swift
// CORRECT - public API documented
/// Fetches the video details.
public func fetchDetails(...) async throws -> VideoDetails { ... }

// CORRECT - implicit internal is still public API
struct AddTripModel {
    /// The booking reference entered by the user.
    let bookingReference: String
}

// CORRECT - private helper, no doc comment
private func resolveType(_ type: MediaType) -> MediaType { ... }
```

### Logging

Always use the project's `Log` wrapper instead of `print()`. Defined in `Haishin/Core/Extensions/Logger+Categories.swift`.

```swift
// CORRECT
Log.debug(.playback, "Loading video...")
Log.error(.network, "Request failed: \(error)")

// WRONG
print("Loading video...")
```

**Available Levels:** `.debug`, `.info`, `.notice`, `.warning`, `.error`, `.fault`
**Available Categories:** `.general`, `.network`, `.sources`, `.downloads`, `.playback`, `.sync`

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


### Property Grouping

Group properties logically under the corresponding MARK Properties section. AnyCancellable sets or Combine-related properties must be placed at the end of the properties section.

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

### Task Cancellation

When creating `Task` instances that observe streams (e.g., `AsyncSequence`, `for await` loops), always store the task reference and cancel it when the owning object is deallocated.

```swift
// WRONG - Untracked task; never cancelled
func startObserving() {
    Task {
        for await value in someAsyncStream() {
            handleValue(value)
        }
    }
}

// CORRECT - Tracked and cancellable
private var observationTask: Task<Void, Never>?

func startObserving() {
    observationTask = Task {
        for await value in someAsyncStream() {
            handleValue(value)
        }
    }
}

func stopObserving() {
    observationTask?.cancel()
    observationTask = nil
}
```

### No Unused Code

Only add code that is actively used. Do not add methods, properties, or types that are not called anywhere. Exception: code used exclusively in tests.

### Safe Collection Access

Prefer `.first` over direct array index access to avoid crashes on empty collections.

```swift
// CORRECT - Safe access
let firstItem = items.first
guard let firstItem = items.first else { return }

// WRONG - Can crash on empty collection
let firstItem = items[0]
```

### Async/Await over Combine

Prefer Swift's native `async`/`await` over Combine for new code. Use Combine only when interfacing with existing Combine-based APIs.

```swift
// CORRECT - async/await
func fetchUser() async throws -> User {
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

// AVOID for new code
func fetchUser() -> AnyPublisher<User, Error> {
    URLSession.shared.dataTaskPublisher(for: url)
        .map(\.data)
        .decode(type: User.self, decoder: JSONDecoder())
        .eraseToAnyPublisher()
}
```

### Swift 6 Concurrency & Sendability

- Avoid passing `[AnyHashable: Any]` or types containing `Any` across Task boundaries.
- When handling Notifications, extract specific Sendable values (`String`, `Int`, `Data`) into local variables before creating a Task.
- Explicitly cast `userInfo` values to known Sendable types before capturing in a closure.
