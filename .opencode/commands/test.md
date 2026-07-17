---
description: Run unit tests via Fastlane
agent: build
---

Run the project's test suite using Fastlane.

!`bundle exec fastlane tests`

## After running:

1. **Parse test results** from `fastlane/test_output/`:
   - Number of tests run, passed, failed
   - Test duration

2. **For failures:**
   - Show the failing test name
   - Show the assertion that failed
   - Show the file:line location
   - Suggest potential fixes
