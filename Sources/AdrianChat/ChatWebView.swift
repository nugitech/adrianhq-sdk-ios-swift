import UIKit
import WebKit

/// The chat widget in a web view, kept alive between openings so it can count replies while closed.
@MainActor
final class ChatWebView: NSObject {
    let webView: WKWebView
    private let origin: (scheme: String?, host: String?, port: Int?)
    private let onMessage: ([String: Any]) -> Void
    private var ready = false
    private var resetWhenReady = false

    init(workspaceId: String, widgetURL: URL, onMessage: @escaping ([String: Any]) -> Void) {
        self.onMessage = onMessage
        origin = (widgetURL.scheme, widgetURL.host, widgetURL.port)

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // Screen-sized while it loads off screen, so the page lays out as it will look when opened.
        webView = WKWebView(frame: UIScreen.main.bounds, configuration: configuration)
        super.init()

        configuration.userContentController.add(WeakMessageHandler(self), name: "adrian")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif

        var components = URLComponents(url: widgetURL, resolvingAgainstBaseURL: false)
        components?.path = "/"
        components?.queryItems = [URLQueryItem(name: "workspaceId", value: workspaceId), URLQueryItem(name: "sdk", value: "ios")]
        if let url = components?.url { webView.load(URLRequest(url: url)) }
    }

    /// Posts `message` to the widget the way loader.js does. Dropped until the widget says it is ready;
    /// `Adrian` re-sends the current state then.
    func send(_ message: [String: Any]) {
        guard ready else { return }
        var payload = message
        payload["source"] = "adrian-loader"
        guard let data = try? JSONSerialization.data(withJSONObject: payload), let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.postMessage(\(json), '*');", completionHandler: nil)
    }

    func reset() {
        guard ready else {
            resetWhenReady = true
            return
        }
        send(["type": "reset"])
        ready = false
    }

    fileprivate func receive(_ body: Any) {
        guard let text = body as? String, let data = text.data(using: .utf8),
              let message = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              message["source"] as? String == "adrian-widget" else { return }
        if message["type"] as? String == "ready" {
            ready = true
            if resetWhenReady {
                resetWhenReady = false
                reset()
                return
            }
        }
        onMessage(message)
    }

    private func isWidget(_ url: URL) -> Bool {
        url.scheme == origin.scheme && url.host == origin.host && url.port == origin.port
    }
}

extension ChatWebView: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.cancel) }
        let local = ["about", "blob", "data"].contains(url.scheme ?? "")
        // Embedded videos load in sub-frames; only the chat itself may use the main frame.
        if local || isWidget(url) || action.targetFrame?.isMainFrame == false {
            return decisionHandler(.allow)
        }
        decisionHandler(.cancel)
        UIApplication.shared.open(url)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { UIApplication.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        ready = false
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false
        webView.reload()
    }
}

/// WKUserContentController keeps its handlers alive; this breaks the cycle back to the web view.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: ChatWebView?

    init(_ target: ChatWebView) {
        self.target = target
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        let body = message.body
        MainActor.assumeIsolated { target?.receive(body) }
    }
}
