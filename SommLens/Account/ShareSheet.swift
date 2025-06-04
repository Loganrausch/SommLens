//
//  ShareSheet.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//

import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems,
                                 applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) { }
}
