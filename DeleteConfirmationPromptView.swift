//
//  DeleteConfirmationPromptView.swift
//  Lumi Light
//
//  Created by Matt Krussow on 5/30/25.
//

import Foundation
import SwiftUI

struct DeleteConfirmationPromptView: View {
    var sessionTitle: String
    var onConfirmDelete: () -> Void
    var onCancel: () -> Void
    
    private let nasalizationFont = "Nasalization-Regular"

    init(sessionTitle: String, onConfirmDelete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.sessionTitle = sessionTitle
        self.onConfirmDelete = onConfirmDelete
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Spacer()
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2.weight(.light))
                        .foregroundColor(.gray.opacity(0.8))
                }
            }

            Text("Delete Chat?")
                .font(.custom(nasalizationFont, size: 20))
                .foregroundColor(Color.sl_textPrimary)
                .padding(.top, 5)

            Text("Are you sure you want to delete \"\(sessionTitle)\"?\nThis action cannot be undone.")
                .font(.custom(nasalizationFont, size: 14))
                .foregroundColor(Color.sl_textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 10)

            HStack(spacing: 15) {
                Button("Cancel") {
                    onCancel()
                }
                .font(.custom(nasalizationFont, size: 16))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.sl_bgPrimary.opacity(0.7)) // Themed secondary button
                .foregroundColor(Color.sl_textPrimary)
                .cornerRadius(10)

                Button("Delete") {
                    onConfirmDelete()
                }
                .font(.custom(nasalizationFont, size: 16))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.red) // Standard destructive color
                .foregroundColor(Color.white) // Text on red
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(EdgeInsets(top: 15, leading: 20, bottom: 20, trailing: 20))
        .background(.thinMaterial)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
        .frame(maxWidth: 320)
    }
}
