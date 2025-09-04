import SwiftUI
import SafariServices

struct PrivacyPolicyView: View {
    let url: URL

    var body: some View {
        SafariView(url: url)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Политика")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
