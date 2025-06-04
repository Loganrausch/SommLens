//
//  MailComposeView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//

import SwiftUI
import MessageUI

struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    @Binding var isShowing: Bool
    @Binding var result: Result<MFMailComposeResult, Error>?
    var configure: (MFMailComposeViewController) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        configure(vc)
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) { }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        init(_ parent: MailComposeView) { self.parent = parent }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            if let error { parent.result = .failure(error) }
            else { parent.result = .success(result) }
            parent.isShowing = false
            parent.dismiss()
        }
    }
}
