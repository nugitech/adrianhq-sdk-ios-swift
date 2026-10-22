## 0.1.0

First release.

- `Adrian.configure`, `identify`, `trackScreen`, `present`, `dismiss` and `reset`.
- Full-screen messenger in the workspace's brand colour, with forms, action buttons, chat flows, file uploads and ratings.
- `AdrianLauncher` (SwiftUI) and `AdrianLauncherButton` (UIKit) with an unread badge.
- `Adrian.shared` as an `ObservableObject` with `unreadCount`, `primaryColor`, `latestMessage`, `isPresented` and `isAvailable`, plus `onEvent`.
- `.adrianScreen(_:)` view modifier to report SwiftUI screens.
- Links, help center articles and downloads open outside the app.
- Privacy manifest declaring the data the chat collects.
