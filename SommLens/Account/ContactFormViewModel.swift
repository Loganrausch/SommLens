//
//  ContactFormViewModel.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//

import Foundation
import MessageUI

@MainActor
class ContactFormViewModel: ObservableObject {
    // Inputs
    @Published var name: String = ""
    @Published var message: String = ""

    // UI state
    @Published var isShowingMailCompose = false
    @Published var mailResult: Result<MFMailComposeResult, Error>?
    @Published var showValidationError  = false
    @Published var showMailUnavailableAlert = false

    // Validation
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !message.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func sendFeedback() {
        guard isFormValid else { showValidationError = true; return }

        if MFMailComposeViewController.canSendMail() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isShowingMailCompose = true
            }
        } else {
            showMailUnavailableAlert = true
        }
    }

    func configureMail(_ vc: MFMailComposeViewController) {
        vc.setSubject("Feedback from \(name)")
        vc.setToRecipients(["support@sommlens.app"])
        vc.setMessageBody(message, isHTML: false)
    }
}
