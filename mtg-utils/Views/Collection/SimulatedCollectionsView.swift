import SwiftUI

// MARK: - Simulated Collections View (Colecciones Simuladas)

struct SimulatedCollectionsView: View {
    @Environment(AppStore.self) private var appStore

    @State private var collections: [SimulatedCollectionSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var showingCreateSheet = false
    @State private var selectedCollection: SimulatedCollectionSummary?
    @State private var analysisDetail: SimulatedCollectionAnalysisResponse?
    @State private var isLoadingDetail = false

    var body: some View {
        Group {
            if isLoading && collections.isEmpty {
                ProgressView("Cargando colecciones simuladas…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let selected = selectedCollection {
                collectionDetailView(selected)
            } else {
                collectionsListView
            }
        }
        .task { await loadCollections() }
        .sheet(isPresented: $showingCreateSheet) {
            CreateSimulatedCollectionSheet { name, description, rawText in
                await handleCreate(name: name, description: description, rawText: rawText)
            }
        }
    }

    // MARK: - Collections List View

    private var collectionsListView: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "flask.fill")
                            .font(.title2)
                            .foregroundStyle(Color.mtgAmber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Simulador de Compras y Lotes")
                                .font(.headline)
                                .foregroundStyle(Color.mtgText)
                            Text("Analiza qué cartas te sirven antes de comprar un lote, caja o colección ajena.")
                                .font(.caption)
                                .foregroundStyle(Color.mtgTextSecondary)
                        }
                    }

                    Button {
                        showingCreateSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Nueva Simulación de Lote")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.mtgAmber)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }

            Section("Colecciones Simuladas Guardadas (\(collections.count))") {
                if collections.isEmpty {
                    Text("Aún no tienes colecciones simuladas. Pulsa arriba para analizar un lote.")
                        .font(.subheadline)
                        .foregroundStyle(Color.mtgTextSecondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(collections) { col in
                        Button {
                            selectedCollection = col
                            Task { await loadAnalysis(id: col.id) }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(col.name)
                                        .font(.headline)
                                        .foregroundStyle(Color.mtgText)
                                    Spacer()
                                    Text(col.totalEconomicValue.formattedPrice(symbol: "€"))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.mtgAmber)
                                }

                                if let desc = col.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(Color.mtgTextSecondary)
                                        .lineLimit(2)
                                }

                                HStack(spacing: 12) {
                                    Label("\(col.totalCards) cartas", systemImage: "square.stack.3d.up")
                                    Label("\(col.benefitedDecksCount) mazos beneficiados", systemImage: "sparkles")
                                        .foregroundStyle(Color.mtgGreen)
                                }
                                .font(.caption2)
                                .foregroundStyle(Color.mtgTextSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await handleDelete(id: col.id) }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Collection Detail / Analysis View

    private func collectionDetailView(_ summary: SimulatedCollectionSummary) -> some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Button {
                    selectedCollection = nil
                    analysisDetail = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Volver a simuladas")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.mtgAmber)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.mtgSurface)

            if isLoadingDetail {
                ProgressView("Analizando impacto en tus mazos…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail = analysisDetail {
                List {
                    // KPIs
                    Section("Resumen del Lote") {
                        KPIStripView(stats: [
                            KPIStat(
                                id: "useful",
                                label: "Cartas útiles",
                                value: "\(detail.usefulCardsCount)",
                                systemImage: "checkmark.seal.fill",
                                tint: .mtgGreen
                            ),
                            KPIStat(
                                id: "sellable",
                                label: "Valor vendible",
                                value: detail.sellableValue.formattedPrice(symbol: detail.currencySymbol),
                                systemImage: "eurosign.circle",
                                tint: .mtgAmber
                            ),
                            KPIStat(
                                id: "decks",
                                label: "Mazos mejorados",
                                value: "\(detail.benefitedDecksCount)",
                                systemImage: "sparkles",
                                tint: .mtgAmber
                            )
                        ])
                    }

                    // Cards breakdown
                    Section("Cartas del Lote (\(detail.cards.count))") {
                        ForEach(detail.cards) { card in
                            simulatedCardRow(card: card, currencySymbol: detail.currencySymbol)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func simulatedCardRow(card: SimulatedCardAnalysisItem, currencySymbol: String) -> some View {
        HStack(spacing: 12) {
            if let uri = card.imageUri, let url = URL(string: uri) {
                CardImageView(url: url, placeholderText: nil, targetSize: 120)
                    .frame(width: 40, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(card.cardName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mtgText)

                    if card.usefulCopies > 0 {
                        Text("ÚTIL")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.mtgGreen.opacity(0.2))
                            .foregroundStyle(Color.mtgGreen)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    ManaCostView(cost: card.manaCost)
                    Text("\(card.quantity)x")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.mtgTextSecondary)
                    if card.candidateDeckCount > 0 {
                        Text("Sirve en \(card.candidateDeckCount) \(card.candidateDeckCount == 1 ? "mazo" : "mazos")")
                            .font(.caption2)
                            .foregroundStyle(Color.mtgGreen)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(card.totalPrice.formattedPrice(symbol: currencySymbol))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.mtgAmber)
                if card.sellableCopies > 0 {
                    Text("\(card.sellableCopies) vendibles")
                        .font(.caption2)
                        .foregroundStyle(Color.mtgTextSecondary)
                }
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Actions

    private func loadCollections() async {
        isLoading = true
        errorMessage = nil
        do {
            collections = try await appStore.client.simulatedCollections(
                provider: appStore.settings.priceProvider,
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadAnalysis(id: String) async {
        isLoadingDetail = true
        do {
            // Fetch analysis through client
            let summaries = try await appStore.client.simulatedCollections(
                provider: appStore.settings.priceProvider,
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
            if let found = summaries.first(where: { $0.id == id }) {
                // Fetch full analysis
                struct AnalysisEnvelope: Decodable {
                    let id: String?
                    let name: String
                    let description: String?
                    let totalEconomicValue: Double
                    let economicValueExcludingOwned: Double
                    let sellableValue: Double
                    let sellableCardsCount: Int
                    let currencySymbol: String
                    let globalNetGain: Double
                    let totalCards: Int
                    let uniqueCards: Int
                    let usefulCardsCount: Int
                    let alreadyOwnedCardsCount: Int
                    let benefitedDecksCount: Int
                    let cards: [SimulatedCardAnalysisItem]
                }
                // Call GET /api/simulated-collections/{id}
                let resp: SimulatedCollectionAnalysisResponse = try await appStore.client.executeSimulatedCollectionDetail(
                    id: id,
                    provider: appStore.settings.priceProvider,
                    userId: appStore.userId,
                    accessToken: appStore.accessToken
                )
                analysisDetail = resp
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingDetail = false
    }

    private func handleCreate(name: String, description: String?, rawText: String) async {
        do {
            let created = try await appStore.client.createSimulatedCollection(
                name: name,
                description: description,
                rawText: rawText,
                provider: appStore.settings.priceProvider,
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
            await loadCollections()
            if let id = created.id, let summary = collections.first(where: { $0.id == id }) {
                selectedCollection = summary
                analysisDetail = created
            }
        } catch {
            errorMessage = "Error al crear simulación: \(error.localizedDescription)"
        }
    }

    private func handleDelete(id: String) async {
        do {
            _ = try await appStore.client.deleteSimulatedCollection(
                collectionId: id,
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
            await loadCollections()
        } catch {
            errorMessage = "Error al eliminar: \(error.localizedDescription)"
        }
    }
}

// MARK: - Create Simulated Collection Sheet

struct CreateSimulatedCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (String, String?, String) async -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var rawText = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos de la simulación") {
                    TextField("Nombre, p. ej. Caja de colección de Pedro", text: $name)
                    TextField("Descripción o notas (opcional)", text: $description)
                }

                Section("Lista de cartas") {
                    Text("Pega el listado en formato texto (p. ej. 1 Sol Ring, 2 Birds of Paradise):")
                        .font(.caption)
                        .foregroundStyle(Color.mtgTextSecondary)

                    TextEditor(text: $rawText)
                        .frame(minHeight: 180)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle("Nueva Simulación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Analizar Lote") {
                        isSubmitting = true
                        Task {
                            await onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines), description.isEmpty ? nil : description, rawText)
                            isSubmitting = false
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
        }
    }
}
