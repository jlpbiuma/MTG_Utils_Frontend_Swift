import SwiftUI

// MARK: - Deck editor (create / edit)

struct DeckEditorView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss

    let onSave: (Deck) async throws -> Void

    @State private var name = ""
    @State private var format = "Commander"
    @State private var description = ""
    @State private var commanderName: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let formats = ["Commander", "Modern", "Pioneer", "Standard", "Legacy", "Pauper", "Draft", "Otro"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Información") {
                    TextField("Nombre del mazo", text: $name)
                    Picker("Formato", selection: $format) {
                        ForEach(formats, id: \.self) { Text($0) }
                    }
                    TextField("Descripción", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Comandante (Opcional)") {
                    NavigationLink {
                        CardSearchPickerView(
                            title: "Comandante",
                            onPick: { card in
                                commanderName = card.name
                                nameFieldIfEmpty(card.name)
                            }
                        )
                    } label: {
                        HStack {
                            Text(commanderName ?? "Buscar comandante")
                                .foregroundStyle(commanderName == nil ? Color.mtgTextSecondary : Color.mtgText)
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.mtgTextSecondary)
                        }
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
            .navigationTitle("Nuevo mazo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .tint(.mtgAmber)
    }

    @MainActor
    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        var cards: [DeckCard] = []
        if let commanderName {
            cards.append(
                DeckCard(
                    cardScryfallId: "pending:\(normalizeCardName(commanderName))",
                    cardName: commanderName,
                    quantity: 1,
                    isCommander: true
                )
            )
        }

        var deck = Deck(
            userId: appStore.userId,
            name: trimmedName,
            format: format,
            description: description.isEmpty ? nil : description,
            commander: commanderName,
            cards: cards
        )

        if let commanderName {
            // Resolve the commander image for the deck list artwork.
            if let resolved = try? await appStore.catalog.resolveCards(named: [commanderName]).first {
                deck.commanderScryfallId = resolved.scryfallId
                deck.commanderImageUri = resolved.imageUri
                if let idx = deck.cards.firstIndex(where: { $0.isCommander }) {
                    deck.cards[idx].cardScryfallId = resolved.scryfallId
                    deck.cards[idx].imageUri = resolved.imageUri
                    deck.cards[idx].manaCost = resolved.manaCost
                    deck.cards[idx].typeLine = resolved.typeLine
                }
            }
        }

        do {
            try await onSave(deck)
            dismiss()
        } catch {
            errorMessage = "No se pudo guardar el mazo: \(error.localizedDescription)"
        }
    }

    private func nameFieldIfEmpty(_ commander: String) {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            name = commander
        }
    }
}

// MARK: - Import a deck from text

struct DeckImportView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss

    let username: String

    @State private var text = ""
    @State private var deckName = ""
    @State private var format = "Commander"
    @State private var isImporting = false
    @State private var preview: ParsedDecklist?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre del mazo") {
                    TextField("Nombre", text: $deckName)
                }

                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                        .font(.footnote.monospaced())
                } header: {
                    Text("Lista de cartas")
                } footer: {
                    Text("Pega una lista de Moxfield, Arena o texto plano. Ejemplo: “1 Atraxa, Praetors' Voice (2XM) 198”. Usa “SB:” o la línea “Sideboard” para reservas.")
                }

                if let preview {
                    Section("Vista previa") {
                        LabeledContent("Total mazo", value: "\(preview.totalCards) cartas")
                        LabeledContent("Líneas", value: "\(preview.totalLines)")
                        LabeledContent("Reservas", value: "\(preview.sideboard.reduce(0) { $0 + $1.quantity })")
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
            .navigationTitle("Importar mazo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importar") {
                        Task {
                            await importDeck()
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isImporting)
                }
            }
            .onChange(of: text) {
                preview = try? parseDecklistText(text)
                errorMessage = nil
            }
        }
        .tint(.mtgAmber)
    }

    @MainActor
    private func importDeck() async {
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        do {
            let parsed = try parseDecklistText(text)
            guard !parsed.mainboard.isEmpty else {
                errorMessage = "El mazo no tiene cartas principales."
                return
            }

            let names = (parsed.mainboard + parsed.sideboard).map(\.name)
            let resolved = try await appStore.catalog.resolveCards(named: names)
            let resolvedByName = Dictionary(resolved.map { (normalizeCardName($0.name), $0) }, uniquingKeysWith: { first, _ in first })

            var cards: [DeckCard] = []
            var commanderName: String?

            for entry in parsed.mainboard {
                let meta = resolvedByName[normalizeCardName(entry.name)]
                let isCommander = format == "Commander" && isLikelyCommander(entry.name)
                if isCommander && commanderName == nil {
                    commanderName = meta?.name ?? entry.name
                }
                cards.append(
                    DeckCard(
                        cardScryfallId: meta?.scryfallId ?? "pending:\(normalizeCardName(entry.name))",
                        cardName: meta?.name ?? entry.name,
                        quantity: entry.quantity,
                        isSideboard: false,
                        isCommander: isCommander,
                        manaCost: meta?.manaCost,
                        typeLine: meta?.typeLine,
                        imageUri: meta?.imageUri
                    )
                )
            }
            for entry in parsed.sideboard {
                let meta = resolvedByName[normalizeCardName(entry.name)]
                cards.append(
                    DeckCard(
                        cardScryfallId: meta?.scryfallId ?? "pending:\(normalizeCardName(entry.name))",
                        cardName: meta?.name ?? entry.name,
                        quantity: entry.quantity,
                        isSideboard: true,
                        isCommander: false,
                        manaCost: meta?.manaCost,
                        typeLine: meta?.typeLine,
                        imageUri: meta?.imageUri
                    )
                )
            }

            let name = deckName.trimmingCharacters(in: .whitespaces).isEmpty || deckName.isEmpty
                ? "Mazo importado"
                : deckName.trimmingCharacters(in: .whitespaces)

            let deck = Deck(
                userId: appStore.userId,
                name: name,
                format: format,
                commander: commanderName,
                commanderScryfallId: commanderName.flatMap { resolvedByName[normalizeCardName($0)]?.scryfallId },
                commanderImageUri: commanderName.flatMap { resolvedByName[normalizeCardName($0)]?.imageUri },
                cards: cards
            )

            var allDecks = try await appStore.store.allDecks()
            allDecks.append(deck)
            try await appStore.store.saveDecks(allDecks)
            dismiss()
        } catch let error as ImportError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Error al importar: \(error.localizedDescription)"
        }
    }

    /// In Commander imports the first legendary creature line is treated as the commander.
    private func isLikelyCommander(_ entryName: String) -> Bool {
        let known = ["Chulane, Teller of Tales", "Atraxa, Praetors' Voice"]
        return known.contains(where: { $0.caseInsensitiveCompare(entryName) == .orderedSame })
    }
}