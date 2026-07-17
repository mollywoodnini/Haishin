---
description: Verify that a ViewModel has a corresponding test file with proper coverage
agent: code-reviewer
subtask: true
---

Verify test coverage for the ViewModel in $ARGUMENTS.

If no ViewModel is specified, ask which one to check.

## Process

1. Load the `swift-style` skill for formatting rules.
2. Reference AGENTS.md for testing requirements (100% coverage, mirroring, naming).
3. Locate the ViewModel: `Haishin/Features/<path>/<Name>ViewModel.swift`.
4. Locate the mirrored test file: `HaishinTests/Features/<path>/<Name>ViewModelTests.swift`.
5. Extract the ViewModel's public properties and methods.
6. Compare against the test file's coverage.

## Report

```
## Test Coverage Report: <ViewModelName>

### Files
- ViewModel: <path>
- Test:      <path or MISSING>

### Public Properties
| Property | Covered |
|----------|---------|

### Public Methods
| Method | Covered |
|--------|---------|

### Coverage: X / Y (Z%)

### Structural Issues

### Recommended Tests to Add
- ...
```
