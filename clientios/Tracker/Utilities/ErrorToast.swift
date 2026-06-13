//
//  ErrorToast.swift
//  Tracker
//
//  Bandeau d'erreur transitoire (auto-disparition) lié à un message optionnel.
//  Rend explicites les échecs d'action qui étaient jusque-là silencieux.
//

import SwiftUI

private struct ErrorToast: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.red.opacity(0.92))
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: message) {
                            try? await Task.sleep(for: .seconds(3.5))
                            self.message = nil
                        }
                }
            }
            .animation(.spring(duration: 0.3), value: message)
    }
}

extension View {
    /// Affiche un bandeau d'erreur transitoire quand `message` n'est pas nil.
    func errorToast(_ message: Binding<String?>) -> some View {
        modifier(ErrorToast(message: message))
    }
}
