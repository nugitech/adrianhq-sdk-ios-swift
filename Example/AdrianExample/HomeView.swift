import AdrianChat
import SwiftUI

struct HomeView: View {
    @ObservedObject private var adrian = Adrian.shared
    @State private var signedIn = false

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Good afternoon")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(signedIn ? "Ada Obi" : "Welcome")
                            .font(.largeTitle.bold())

                        Tile(icon: "creditcard", title: "Pay a bill", detail: "Taxes, levies and fees")
                        Tile(icon: "doc.text.magnifyingglass", title: "Verify a receipt", detail: "Check a payment reference")
                        Tile(icon: "clock.arrow.circlepath", title: "History", detail: "Your last 12 payments")

                        Button {
                            Adrian.present()
                        } label: {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                Text("Help & support")
                                Spacer()
                                if adrian.unreadCount > 0 {
                                    Text("\(adrian.unreadCount) new")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.red))
                                }
                                Image(systemName: "chevron.right").foregroundColor(.secondary)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator)))
                        }
                        .buttonStyle(.plain)

                        Button(signedIn ? "Sign out" : "Sign in as Ada") {
                            if signedIn {
                                Adrian.reset()
                            } else {
                                Adrian.identify(name: "Ada Obi", email: "ada@example.com")
                            }
                            signedIn.toggle()
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                }

                AdrianLauncher()
                    .padding(20)
            }
            .navigationTitle("Acme")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .adrianScreen("Home")
    }
}

private struct Tile: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator)))
    }
}
