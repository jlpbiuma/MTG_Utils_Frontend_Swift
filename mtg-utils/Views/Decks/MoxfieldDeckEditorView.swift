import SwiftUI

// MARK: - Moxfield / Plain Text Deck Editor View

struct MoxfieldDeckEditorView: View {
    let cards: [DeckCardWithOwnership]
    let onSaveText: (String) async -> Void

    @State private var deckText: String = ""
    @State private var isSaving = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Editor en Formato Texto (Moxfield / MTG)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mtgText)
                Spacer()
                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copiado" : "Copiar")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mtgAmber)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            TextEditor(text: $deckText)
                .font(.system(.subheadline, design: .monospaced))
                .padding(8)
                .background(Color.mtgSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)

            Button {
                isSaving = true
                Task {
                    await onSaveText(deckText)
                    isSaving = false
                }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Actualizar Mazo desde Texto")
                    }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.mtgAmber)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .task {
            generateText()
        }
    }

    private func generateText() {
        let commanders = cards.filter { $0.isCommander }
        let mainboard = cards.filter { !$0.isCommander && !$0.isSideboard }
        let sideboard = cards.filter { $0.isSideboard }

        var lines: [String] = []

        if !commanders.isEmpty {
            lines.append("// Comandante")
            for c in commanders {
                lines.append("\(c.quantity) \(c.cardName)")
            }
            lines.append("")
        }

        lines.append("// Principal")
        for c in mainboard {
            lines.append("\(c.quantity) \(c.cardName)")
        }

        if !sideboard.isEmpty {
            lines.append("")
            lines.append("// Banquillo (Sideboard)")
            for c in sideboard {
                lines.append("\(c.quantity) \(c.cardName)")
            }
        }

        deckText = lines.joined(separator: "\n")
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = deckText
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}
