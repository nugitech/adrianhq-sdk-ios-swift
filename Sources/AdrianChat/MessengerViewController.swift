import Combine
import UIKit

/// Full-screen chat. The widget draws its own header with a close button; the status bar takes the brand colour.
@MainActor
final class MessengerViewController: UIViewController {
    private let chat: ChatWebView
    private let statusBar = UIView()
    private var colorObserver: AnyCancellable?

    init(chat: ChatWebView) {
        self.chat = chat
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusBar)
        NSLayoutConstraint.activate([
            statusBar.topAnchor.constraint(equalTo: view.topAnchor),
            statusBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        ])
        colorObserver = Adrian.shared.$primaryColor.sink { [weak self] color in self?.statusBar.backgroundColor = color }
        attachWebView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        attachWebView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Adrian.shared.messengerDidAppear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed || presentingViewController == nil else { return }
        chat.webView.endEditing(true)
        chat.webView.removeFromSuperview()
        Adrian.shared.messengerDidDisappear()
    }

    private func attachWebView() {
        let webView = chat.webView
        guard webView.superview !== view else { return }
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            // Follows the keyboard so the composer stays above it; the safe area bottom when it is hidden.
            webView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
    }
}
