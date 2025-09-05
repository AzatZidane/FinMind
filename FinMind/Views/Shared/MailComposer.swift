import SwiftUI
import MessageUI

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
        vc.setSubject(subject)
        vc.setToRecipients(recipients)
        if let body { vc.setMessageBody(body, isHTML: false) }
        for a in attachments {
            vc.addAttachmentData(a.data, mimeType: a.mimeType, fileName: a.fileName)
        }
        vc.mailComposeDelegate = context.coordinator
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