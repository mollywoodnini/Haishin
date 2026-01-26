# Haishin

A free anime streaming application for iOS and iPadOS.

## Features

- [x] No ads
- [x] JavaScript-based source system
- [x] Online streaming through external sources
- [x] Downloads for offline viewing
- [x] AniList integration for browsing and tracking
- [x] Watch progress tracking
- [x] Light and dark mode support
- [x] iCloud sync
- [o] Subscription notifications

## Requirements

- iOS 26.1+ / iPadOS 26.1+
- Xcode 26.1+
- Swift 5.9+

## Building

1. Clone the repository
   ```bash
   git clone https://github.com/user/Haishin.git
   cd Haishin
   ```

2. Open the project in Xcode
   ```bash
   open Haishin.xcodeproj
   ```

3. Build and run on your device or simulator

## Architecture

Haishin follows the MVVM (Model-View-ViewModel) architecture pattern:

- **Views**: SwiftUI views that are purely declarative
- **ViewModels**: Handle all business logic, services, and state management
- **Services**: Provide data access and external integrations (AniList, Sources, Downloads)

## Contributing

Contributions are welcome! Please ensure your code follows the project's coding guidelines defined in `AGENTS.md`.

Contributors must agree to the project [CLA](CLA.md). This grants the maintainer the ability to distribute Haishin via TestFlight/App Store, while others must obtain explicit permission to distribute compiled versions.

## License

This project is licensed under [GPLv3](LICENSE), but distribution of compiled binaries is restricted. See the [CLA](CLA.md) for details.
