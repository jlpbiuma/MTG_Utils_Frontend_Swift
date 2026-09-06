import SwiftUI

// MARK: - Collection import sheet

struct CollectionImportView: View {
    @Environment(\.dismiss) private var dismiss
    let onImport: ([CollectionCard]) async throws -> Void

    @State private var text = ""
    @State private var isImporting = false
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
                        Task { await add() }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isImporting)
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
    private func add() async {
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        do {
            let lines = try parseCollectionText(text)
            let names = lines.map(\.name)

            // Try to resolve metadata live; fall back to pending placeholders.
            let resolved = (try? await searchResolve(names)) ?? [:]

            let cards: [CollectionCard] = lines.map { line in
                let meta = resolved[normalizeCardName(line.name)]
                return CollectionCard(
                    cardScryfallId: meta?.scryfallId ?? "pending:\(normalizeCardName(line.name))",
                    cardName: meta?.name ?? line.name,
                    quantity: line.quantity,
                    setCode: line.setCode ?? meta?.set,
                    collectorNumber: line.collectorNumber ?? meta?.collectorNumber,
                    manaCost: meta?.manaCost,
                    typeLine: meta?.typeLine,
                    imageUri: meta?.imageUri
                )
            }

            try await onImport(cards)
            dismiss()
        } catch let error as ImportError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Error al importar: \(error.localizedDescription)"
        }
    }

    private func searchResolve(_ names: [String]) async -> [String: ResolvedCardData]? {
        let client = ScryfallClient.shared
        let resolved = try? await client.resolveCards(named: names)
        guard let resolved else { return nil }
        return Dictionary(resolved.map { (normalizeCardName($0.name), $0) }, uniquingKeysWith: { first, _ in first })
    }
}