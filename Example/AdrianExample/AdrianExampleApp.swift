import AdrianChat
import SwiftUI

@main
struct AdrianExampleApp: App {
    init() {
        // Settings → Chat widget → Install in Adrian. The environment overrides are for local testing.
        let env = ProcessInfo.processInfo.environment
        Adrian.configure(
            workspaceId: env["ADRIAN_WORKSPACE_ID"] ?? "ws_your_workspace_id",
            widgetURL: env["ADRIAN_WIDGET_URL"].flatMap(URL.init(string:)) ?? Adrian.defaultWidgetURL
        )
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
