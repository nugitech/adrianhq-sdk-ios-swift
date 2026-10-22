import Combine
import SwiftUI
import UIKit

/// A round chat button in the workspace colour with an unread badge. Tapping it opens the chat.
public final class AdrianLauncherButton: UIButton {
    private let badge = UILabel()
    private var observers = Set<AnyCancellable>()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    public override var intrinsicContentSize: CGSize { CGSize(width: 60, height: 60) }

    public override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        layer.shadowPath = UIBezierPath(ovalIn: bounds).cgPath
        let size = badge.intrinsicContentSize
        let width = max(22, size.width + 10)
        badge.frame = CGRect(x: bounds.width - width + 4, y: -4, width: width, height: 22)
    }

    private func setUp() {
        accessibilityLabel = "Open chat"
        setImage(UIImage(systemName: "message.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)), for: .normal)
        tintColor = .white
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        badge.backgroundColor = .systemRed
        badge.textColor = .white
        badge.font = .systemFont(ofSize: 12, weight: .bold)
        badge.textAlignment = .center
        badge.layer.cornerRadius = 11
        badge.layer.borderWidth = 2
        badge.layer.borderColor = UIColor.white.cgColor
        badge.clipsToBounds = true
        badge.isHidden = true
        addSubview(badge)

        addAction(UIAction { _ in Adrian.present() }, for: .touchUpInside)
        Task { @MainActor [weak self] in self?.observe() }
    }

    @MainActor
    private func observe() {
        Adrian.shared.$primaryColor.sink { [weak self] in self?.backgroundColor = $0 }.store(in: &observers)
        Adrian.shared.$unreadCount.sink { [weak self] count in
            guard let self else { return }
            badge.text = count > 99 ? "99+" : String(count)
            badge.isHidden = count == 0
            accessibilityValue = count == 0 ? nil : "\(count) unread"
            setNeedsLayout()
        }.store(in: &observers)
    }
}

/// SwiftUI version of `AdrianLauncherButton`.
public struct AdrianLauncher: View {
    @ObservedObject private var adrian = Adrian.shared

    public init() {}

    public var body: some View {
        Button {
            Adrian.present()
        } label: {
            Image(systemName: "message.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color(adrian.primaryColor)))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                .overlay(alignment: .topTrailing) {
                    if adrian.unreadCount > 0 {
                        Text(adrian.unreadCount > 99 ? "99+" : "\(adrian.unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(Capsule().fill(Color.red))
                            .overlay(Capsule().stroke(Color.white, lineWidth: 2))
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open chat")
        .accessibilityValue(adrian.unreadCount == 0 ? "" : "\(adrian.unreadCount) unread")
    }
}

extension View {
    /// Calls `Adrian.trackScreen(name)` each time this view appears.
    public func adrianScreen(_ name: String) -> some View {
        onAppear { Adrian.trackScreen(name) }
    }
}
