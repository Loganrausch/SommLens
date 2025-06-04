//
//  ContactFormView.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//

import SwiftUI
import MessageUI

struct ContactFormView: View {
    @StateObject private var viewModel = ContactFormViewModel()
    @FocusState private var isMessageFocused: Bool

    var body: some View {
        Form {
            // ── Name ────────────────────────────────
            Section(header: Text("Your Name")) {
                TextField("Name", text: $viewModel.name)
                    .autocapitalization(.words)
            }

            // ── Message ─────────────────────────────
            Section(header: Text("Your Feedback")) {
                TextEditor(text: $viewModel.message)
                    .frame(minHeight: 150)
                    .focused($isMessageFocused)
            }

            // ── Send ───────────────────────────────
            Button("Send Feedback") {
                isMessageFocused = false
                viewModel.sendFeedback()
            }
            .alert("Validation Error",
                   isPresented: $viewModel.showValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please fill in all required fields.")
            }
            .alert("Mail Not Available",
                   isPresented: $viewModel.showMailUnavailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your device is not configured to send mail.")
            }
        }
        .navigationTitle("Contact Us")
        .sheet(isPresented: $viewModel.isShowingMailCompose) {
            MailComposeView(isShowing: $viewModel.isShowingMailCompose,
                            result: $viewModel.mailResult) { mailVC in
                viewModel.configureMail(mailVC)
            }
            .preferredColorScheme(.light)
        }
    }
}
