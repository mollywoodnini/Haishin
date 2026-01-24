# Agents.md

This file provides guidance to OpenCode when working with code in this repository.

## Architecture

### MVVM Pattern (Current)
The app uses MVVM architecture for SwiftUI compatibility.

## Dependency Management

Swift Package Manager (SPM) only.

## Testing Requirements
Every new ViewModel must be accompanied by a corresponding Unit Test file.

Rules:
Coverage: 100% of public properties and methods in the ViewModel must be covered by unit tests.

Target: All tests must be added to the MiruTests target.

Location Mirroring: The folder structure in MiruTests must mirror the main project structure.

Naming Convention: The test file must be named [ViewModelName]Tests.swift.

### File Path Mapping Example

Source File: Miru/Explore/ExploreViewModel.swift
Test File Target: Miru/Explore/ExploreViewModelTests.swift

### Example Test Structure

```swift
import Testing
@testable import Miru

@Suite("ExploreViewModel Tests")
final class ExploreViewModelTests {

    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, title is set")
    func onInitialization_titleIsSet() {
        
    }
}
```

## Code Style

### Swift Formatting: Function & Initializer Calls
Follow these specific rules for object creation and function calls:

* Single Line Rule: If an initializer or function has 2 or fewer parameters, keep it on a single line. If the line is getting too long, for example because of many default 
* Multi-line Indentation: If there are more than 2 parameters, break the lines such that:
    * The first parameter stays on the same line as the opening parenthesis.
    * All subsequent parameters are vertically aligned with the first parameter.
    * The closing parenthesis follows the last parameter on the same line.

❌ Discouraged (Standard Indentation):
```swift
let example = HTTPURLResponse(
    url: url,
    statusCode: statusCode,
    httpVersion: nil,
    headerFields: responseHeaders
)
```

✅ Required (Vertical Alignment):
```swift
// 1-2 Parameters: Single Line
let response = HTTPURLResponse(url: url, statusCode: 200)

// 3+ Parameters: Vertically aligned after the parenthesis
let example = HTTPURLResponse(url: url,
                              statusCode: statusCode,
                              httpVersion: nil,
                              headerFields: responseHeaders)
```

### Line Length & Wrapping Rules

To maintain readability, especially when using default parameter values or long types, follow these wrapping rules:

* Length Trigger: If a single-line declaration exceeds 100 characters, or if the parameters make the line visually "dense" (common with default values like HTTPCookieStorage.shared), it must be wrapped.
* Wrapping Style: Use the same vertical alignment rule as object creation. The first parameter stays on the opening line, and subsequent parameters align vertically under it.
* Default Values: When parameters include default values, treat each as a full line-break candidate to prevent the signature from disappearing off the right side of the screen.

❌ Discouraged (Too Long/Single Line):
```swift
public init(cookieStorage: HTTPCookieStorageProtocol = HTTPCookieStorage.shared, sessionProvider: NetworkSessionProvider? = nil)
````

✅ Required (Wrapped for Length):
```swift
public init(cookieStorage: HTTPCookieStorageProtocol = HTTPCookieStorage.shared,
            sessionProvider: NetworkSessionProvider? = nil)
````


### MARK Comments
Always use the following specific format for structuring Swift files with MARK comments. Each MARK block must be wrapped in a border made of 81 hash characters (#) above and below:

```swift
//#################################################################################
// MARK: - <Title>
//#################################################################################
```
When organizing code within types (classes, structs, actors, enums, etc.), follow these vertical spacing rules for the hash-bordered MARK blocks:

1. **First Marker:** There must be exactly **one newline** between the type declaration and the first section marker.
2. **Subsequent Markers:** There must be exactly **two newlines** before every following section marker to provide better visual separation.
3. And after each section marker there is only **one newline**.

Outside of these types, the markers should have **two newlines** before they start.

#### Example:
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


//#################################################################################
// MARK: - Private Constants
//#################################################################################

private struct Constants {
  static let anotherConstant: CGFloat = 1.0
}
```

### Constants
Constants should always be stored in own structs at the top of the type declaration:

```swift
struct Example {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let animationDuration: TimeInterval = 0.3
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################
    
    // ... logic follows
}
```

### Spacings
Instead of using spacings as pure CGFloats please refer to CGFloat+Additions.swift as we do have our own spacings defined like for example:
```swift
.spacingXS
```

### Access Control (Encapsulation)
Private by Default: All properties must be declared as private unless external access is strictly required.

Minimal Exposure: Always favor the most restrictive access level possible to maintain clean encapsulation.

### Initialization and Documentation
Explicit Initializers: If properties do not have default values, you must provide an explicit init.

Documentation: Every init must be documented using Swift's Triple-Slash (///) documentation format.

Every public property, method, init, etc. should be documented.
Private properties, method, init, etc. should NOT be documented.

Parameter Descriptions: Use the - Parameter name: Description syntax to explain every argument within the initializer.

Dependency Injection: Prefer injecting protocols (e.g., ServiceProtocol) with default implementations in the initializer to facilitate easier testing.

### Property Grouping
Group properties logically under the corresponding MARK Properties section.

Ensure that AnyCancellable sets or Combine-related properties are placed at the end of the properties section.

### Swift Observation Guidelines
When generating SwiftUI code, strictly follow the Swift 5.9+ Observation framework:

1. **Model Declaration**: 
   - Use the `@Observable` macro on classes.
   - Do not use `ObservableObject` or `@Published`.
   
2. **View State**:
   - Use `@State` for local lifecycle ownership of `@Observable` instances.
   - Use `@Bindable` for local property bindings to an existing `@Observable` instance.
   
3. **Example**:
   ```swift
   @Observable
   class FeatureViewModel {
       var title = "Hello"
   }

   struct FeatureView: View {
       @State private var viewModel = FeatureViewModel()
       
       var body: some View {
           TextField("Edit", text: $viewModel.title) // Requires @Bindable if used here
       }
   }
