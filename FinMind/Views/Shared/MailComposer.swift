import SwiftUI

#if canImport(MessageUI) && !targetEnvironment(macCatalyst)
import MessageUI

/// iOS-реализация через MFMailComposeViewController
struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let recipients: [String]
    let body: String?
    let attachments: [Attachment]

    struct Attachment {
        let data: Data
        let mimeType: String
        let fileName: String
    }

    @Environment(\.dismiss) private var dismiss

    static func canSendMail() -> Bool {
        MFMailComposeViewController.canSendMail()
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setSubject(subject)
        vc.setToRecipients(recipients)
        if let body { vc.setMessageBody(body, isHTML: false) }
        for a in attachments {
            vc.addAttachmentData(a.data, mimeType: a.mimeType, fileName: a.fileName)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: { dismiss() }) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            onFinish()
        }
    }
}

#else
/// Заглушка для Mac Catalyst / Designed for iPad:
/// открываем системную Почту через mailto: и закрываем sheet.
/// Вложения в mailto: не поддерживаются — будут проигнорированы.
struct MailComposerView: View {
    let subject: String
    let recipients: [String]
    let body: String?
    let attachments: [Attachment] = [] // не используются в этой ветке

    struct Attachment {
        let data: Data
        let mimeType: String
        let fileName: String
    }

    @Environment(\.dismiss) private var dismiss

    static func canSendMail() -> Bool { true }

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                openMailto()
                // Закроем sheet сразу после открытия Почты
                DispatchQueue.main.async { dismiss() }
            }
    }

    private func openMailto() {
        let to = recipients.joined(separator: ",")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let subj = (subject)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bod  = (body ?? "")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = "mailto:\(to)?subject=\(subj)&body=\(bod)"
        guard let url = URL(string: urlStr) else { return }

        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }
}
#endif
