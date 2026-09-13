import SwiftUI

// MARK: - Collection import sheet

struct CollectionImportView: View {
    @Environment(\.dismiss) private var dismiss
    /// Receives already-parsed cards and must update the local collection immediately.
    /// Remote synchronization is deliberately handled outside this sheet.
    let onImport: ([CollectionCard]) -> Void

    @State private var text = ""
    @State private var previewCount: Int?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 240)
                        .font(.footnote.monospaced())
                } header: {
                    Text("Cartas")
                } footer: {
                    Text("Pega tu inventario en líneas:“4 Lightning Bolt (2X2) 94”. Cada línea agrega cantidad a la carta existente.")
                }

                if let previewCount {
                    Section("Vista previa") {
                        LabeledContent("Líneas", value: "\(previewCount)")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Color.mtgRed)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Importar colección")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Añadir") {
                        add()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: text) {
                previewCount = (try? parseCollectionText(text))?.count
                errorMessage = nil
            }
        }
        .tint(.mtgAmber)
    }

    @MainActor
    private func add() {
        errorMessage = nil

        do {
            let lines = try parseCollectionText(text)
            // Import immediately with local placeholders. The card data can be enriched
            // later; waiting for one network lookup per line makes large imports unusable.
            let cards: [CollectionCard] = lines.map { line in
                return CollectionCard(
                    cardScryfallId: "pending:\(normalizeCardName(line.name))",
                    cardName: line.name,
                    quantity: line.quantity,
                    setCode: line.setCode,
                    collectorNumber: line.collectorNumber
                )
            }

            onImport(cards)
            dismiss()
        } catch let error as ImportError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Error al importar: \(error.localizedDescription)"
        }
    }

}
