import SwiftUI

// MARK: - Deck editor (create / edit)

struct DeckEditorView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss

    let initialDeck: Deck?
    let onSave: (Deck) async throws -> Void

    @State private var name: String
    @State private var format: String
    @State private var description: String
    @State private var commanderName: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let formats = ["Commander", "Modern", "Pioneer", "Standard", "Legacy", "Pauper", "Draft", "Otro"]

    init(deck: Deck? = nil, onSave: @escaping (Deck) async throws -> Void) {
        self.initialDeck = deck
        self.onSave = onSave
        _name = State(initialValue: deck?.name ?? "")
        _format = State(initialValue: deck?.format ?? "Commander")
        _description = State(initialValue: deck?.description ?? "")
        _commanderName = State(initialValue: deck?.commander)
    }

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

                    if commanderName != nil {
                        Button(role: .destructive) {
                            commanderName = nil
                        } label: {
                            Label("Quitar comandante", systemImage: "xmark.circle")
                                .font(.footnote)
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
            .navigationTitle(initialDeck != nil ? "Editar mazo" : "Nuevo mazo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(initialDeck != nil ? "Guardar" : "Crear") {
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

        var deck: Deck
        if var existing = initialDeck {
            existing.name = trimmedName
            existing.format = format
            existing.description = description.isEmpty ? nil : description
            deck = existing
        } else {
            deck = Deck(
                userId: appStore.userId,
                name: trimmedName,
                format: format,
                description: description.isEmpty ? nil : description,
                commander: nil,
                cards: []
            )
        }

        let trimmedCommander = commanderName?.trimmingCharacters(in: .whitespaces)
        if let cmdName = trimmedCommander, !cmdName.isEmpty {
            deck.commander = cmdName

            // Clear previous isCommander flags
            for i in deck.cards.indices {
                deck.cards[i].isCommander = false
            }

            let normalizedCmd = normalizeCardName(cmdName)
            if let existingIndex = deck.cards.firstIndex(where: { normalizeCardName($0.cardName) == normalizedCmd }) {
                deck.cards[existingIndex].isCommander = true
            } else {
                deck.cards.append(
                    DeckCard(
                        cardScryfallId: "pending:\(normalizedCmd)",
                        cardName: cmdName,
                        quantity: 1,
                        isCommander: true
                    )
                )
            }

            // Resolve the commander image for the deck list artwork
            if let resolved = try? await appStore.catalog.resolveCards(named: [cmdName]).first {
                deck.commanderScryfallId = resolved.scryfallId
                deck.commanderImageUri = resolved.imageUri
                if let idx = deck.cards.firstIndex(where: { normalizeCardName($0.cardName) == normalizedCmd }) {
                    deck.cards[idx].cardScryfallId = resolved.scryfallId
                    deck.cards[idx].imageUri = resolved.imageUri
                    deck.cards[idx].manaCost = resolved.manaCost
                    deck.cards[idx].typeLine = resolved.typeLine
                }
            }
        } else {
            // Commander removed or absent
            deck.commander = nil
            deck.commanderScryfallId = nil
            deck.commanderImageUri = nil
            for i in deck.cards.indices {
                deck.cards[i].isCommander = false
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
    let onImport: (Deck) -> Void

    @State private var text = ""
    @State private var deckName = ""
    @State private var format = "Commander"
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
                        importDeck()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: text) {
                preview = try? parseDecklistText(text)
                errorMessage = nil
            }
        }
        .tint(.mtgAmber)
    }

    private func importDeck() {
        errorMessage = nil
        do {
            let parsed = try parseDecklistText(text)
            guard !parsed.mainboard.isEmpty else {
                errorMessage = "El mazo no tiene cartas principales."
                return
            }

            var cards: [DeckCard] = []
            var commanderName: String?

            for entry in parsed.mainboard {
                let isCommander = format == "Commander" && isLikelyCommander(entry.name)
                if isCommander && commanderName == nil {
                    commanderName = entry.name
                }
                cards.append(
                    DeckCard(
                        cardScryfallId: "pending:\(normalizeCardName(entry.name))",
                        cardName: entry.name,
                        quantity: entry.quantity,
                        isSideboard: false,
                        isCommander: isCommander,
                        manaCost: nil,
                        typeLine: nil,
                        imageUri: nil
                    )
                )
            }
            for entry in parsed.sideboard {
                cards.append(
                    DeckCard(
                        cardScryfallId: "pending:\(normalizeCardName(entry.name))",
                        cardName: entry.name,
                        quantity: entry.quantity,
                        isSideboard: true,
                        isCommander: false,
                        manaCost: nil,
                        typeLine: nil,
                        imageUri: nil
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
                commanderScryfallId: nil,
                commanderImageUri: nil,
                cards: cards
            )
            onImport(deck)
            dismiss()

            // Enrich pending cards in the background; the local deck is already visible.
            Task {
                guard let resolved = try? await appStore.catalog.resolveCards(named: cards.map(\.cardName)) else { return }
                let byName = Dictionary(resolved.map { (normalizeCardName($0.name), $0) }, uniquingKeysWith: { first, _ in first })
                var enriched = deck
                enriched.cards = deck.cards.map { card in
                    guard let meta = byName[normalizeCardName(card.cardName)] else { return card }
                    var updated = card
                    updated.cardScryfallId = meta.scryfallId
                    updated.cardName = meta.name
                    updated.manaCost = meta.manaCost
                    updated.typeLine = meta.typeLine
                    updated.imageUri = meta.imageUri
                    return updated
                }
                if let commander = enriched.commander,
                   let meta = byName[normalizeCardName(commander)] {
                    enriched.commander = meta.name
                    enriched.commanderScryfallId = meta.scryfallId
                    enriched.commanderImageUri = meta.imageUri
                }
                onImport(enriched)
            }
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
