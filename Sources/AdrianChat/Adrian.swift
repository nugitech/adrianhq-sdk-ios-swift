import Combine
import UIKit

/// What happened in the chat, for apps that want more than the published properties.
public enum AdrianEvent: Equatable {
    /// The chat finished loading and can take `identify` and `trackScreen` calls.
    case ready
    case opened
    case closed
    case unreadCountChanged(Int)
    /// A reply or proactive message arrived while the chat was closed.
    case messageReceived(AdrianMessagePreview)
    /// The workspace refused this app (for example, chat is switched off).
    case unavailable(String)
}

/// The newest message that arrived while the chat was closed, for an in-app banner.
public struct AdrianMessagePreview: Equatable {
    public let id: String
    public let author: String
    public let body: String
}

/**
 Adrian live chat for iOS.

 ```swift
 Adrian.configure(workspaceId: "ws_…")
 Adrian.identify(name: "Ada Obi", email: "ada@example.com")
 Adrian.present()
 ```

 The conversation runs in Adrian's chat widget inside a web view, so forms, action buttons,
 chat flows, files and ratings work exactly as they do on your website.
 */
@MainActor
public final class Adrian: ObservableObject {
    public static let shared = Adrian()
    public nonisolated static let defaultWidgetURL = URL(string: "https://chat.adrianhq.co")!

    /// Unread replies, including a greeting waiting to be seen. Zero while the chat is open.
    @Published public private(set) var unreadCount = 0
    /// The workspace's brand colour from Settings → Chat widget.
    @Published public private(set) var primaryColor = UIColor(red: 0x25 / 255, green: 0x54 / 255, blue: 0xEB / 255, alpha: 1)
    @Published public private(set) var isPresented = false
    @Published public private(set) var latestMessage: AdrianMessagePreview?
    /// False when the workspace turned chat off for apps; `present()` then does nothing.
    @Published public private(set) var isAvailable = true

    /// Called for every `AdrianEvent`, on the main thread.
    public var onEvent: ((AdrianEvent) -> Void)?

    struct Identity: Equatable {
        var name: String?
        var email: String?
    }

    private(set) var configuration: (workspaceId: String, widgetURL: URL, openOnProactiveMessage: Bool)?
    private(set) var chat: ChatWebView?
    private var identity: Identity?
    private var screen: String?
    private var unread = 0
    private weak var messenger: MessengerViewController?

    private init() {}

    // MARK: Setup

    /**
     Starts the chat in the background so replies can raise `unreadCount` before the user opens it.
     Call once, early (for example in `application(_:didFinishLaunchingWithOptions:)`).

     - Parameters:
       - workspaceId: Your workspace id, from Settings → Chat widget → Install.
       - widgetURL: Where the chat widget is hosted. Only change this for a self-hosted Adrian.
       - openOnProactiveMessage: Open the chat by itself when your team or a trigger starts a conversation.
     */
    public static func configure(workspaceId: String, widgetURL: URL = defaultWidgetURL, openOnProactiveMessage: Bool = false) {
        shared.configure(workspaceId: workspaceId, widgetURL: widgetURL, openOnProactiveMessage: openOnProactiveMessage)
    }

    /// Tells your team who they are talking to. Call after sign-in; values the user typed in the chat are replaced.
    public static func identify(name: String? = nil, email: String? = nil) {
        shared.identity = Identity(name: name?.nilIfBlank, email: email?.nilIfBlank)
        shared.sendIdentity()
    }

    /// Records the screen the user is on, shown to agents like a page view (`app://<bundle id>/<screen>`).
    /// Screen-based triggers from Settings → Chat widget → Triggers fire on these.
    public static func trackScreen(_ name: String) {
        guard let name = name.nilIfBlank else { return }
        shared.screen = name
        shared.sendScreen()
    }

    /// Opens the chat full screen over `viewController`, or the top-most screen when nil.
    public static func present(from viewController: UIViewController? = nil) {
        shared.present(from: viewController)
    }

    public static func dismiss() {
        shared.messenger?.dismiss(animated: true)
    }

    /// Call when the user signs out: the next chat starts as a new visitor with no history.
    public static func reset() {
        shared.identity = nil
        shared.screen = nil
        shared.latestMessage = nil
        shared.setUnread(0)
        shared.chat?.reset()
    }

    // MARK: Internals

    private func configure(workspaceId: String, widgetURL: URL, openOnProactiveMessage: Bool) {
        let workspaceId = workspaceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !workspaceId.isEmpty else {
            print("[Adrian] configure(workspaceId:) needs your workspace id")
            return
        }
        if let current = configuration, current.workspaceId == workspaceId, current.widgetURL == widgetURL {
            configuration?.openOnProactiveMessage = openOnProactiveMessage
            return
        }
        configuration = (workspaceId, widgetURL, openOnProactiveMessage)
        isAvailable = true
        chat = ChatWebView(workspaceId: workspaceId, widgetURL: widgetURL) { [weak self] message in
            self?.handle(message)
        }
    }

    private func present(from viewController: UIViewController?) {
        guard let chat else {
            print("[Adrian] Call Adrian.configure(workspaceId:) before present()")
            return
        }
        guard isAvailable, messenger == nil, let host = viewController ?? Self.topViewController() else { return }
        let controller = MessengerViewController(chat: chat)
        messenger = controller
        host.present(controller, animated: true)
    }

    func messengerDidAppear() {
        isPresented = true
        latestMessage = nil
        setUnread(0)
        chat?.send(["type": "open"])
        emit(.opened)
    }

    func messengerDidDisappear() {
        isPresented = false
        chat?.send(["type": "closed"])
        emit(.closed)
    }

    private func sendIdentity() {
        guard let identity else { return }
        var message: [String: Any] = ["type": "identify"]
        if let name = identity.name { message["name"] = name }
        if let email = identity.email { message["email"] = email }
        chat?.send(message)
    }

    private func sendScreen() {
        guard let screen else { return }
        let bundle = Bundle.main.bundleIdentifier ?? "app"
        let slug = screen.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        chat?.send(["type": "page", "page": ["url": "app://\(bundle)/\(slug.isEmpty ? "screen" : slug)", "title": screen, "referrer": ""]])
    }

    private func setUnread(_ count: Int) {
        unread = count
        let shown = isPresented ? 0 : max(count, latestMessage == nil ? 0 : 1)
        guard shown != unreadCount else { return }
        unreadCount = shown
        emit(.unreadCountChanged(shown))
    }

    private func emit(_ event: AdrianEvent) {
        onEvent?(event)
    }

    private func handle(_ message: [String: Any]) {
        switch message["type"] as? String {
        case "ready":
            chat?.send(["type": isPresented ? "open" : "closed"])
            sendIdentity()
            sendScreen()
            emit(.ready)
        case "close":
            Self.dismiss()
        case "open":
            guard !isPresented else { return }
            if configuration?.openOnProactiveMessage == true { present(from: nil) } else { setUnread(max(unread, 1)) }
        case "unread":
            setUnread((message["count"] as? NSNumber)?.intValue ?? 0)
        case "teaser":
            if let teaser = message["teaser"] as? [String: Any], let id = teaser["id"] as? String, let body = teaser["body"] as? String, !isPresented {
                let preview = AdrianMessagePreview(id: id, author: teaser["author"] as? String ?? "", body: body)
                latestMessage = preview
                emit(.messageReceived(preview))
            } else {
                latestMessage = nil
            }
            setUnread(unread)
        case "settings":
            if let appearance = message["appearance"] as? [String: Any], let hex = appearance["primaryColor"] as? String, let color = UIColor(hex: hex) {
                primaryColor = color
            }
        case "disabled":
            let reason = message["message"] as? String ?? "Chat is not enabled for this app."
            print("[Adrian] \(reason)")
            isAvailable = false
            Self.dismiss()
            emit(.unavailable(reason))
        case "link":
            if let raw = message["url"] as? String, let url = URL(string: raw) { UIApplication.shared.open(url) }
        default:
            break
        }
    }

    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var value: UInt64 = 0
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, Scanner(string: digits).scanHexInt64(&value) else { return nil }
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255, blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}
