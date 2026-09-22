import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Deck list

struct DecksListView: View {
    @Environment(AppStore.self) private var appStore
    @State private var viewModel: DecksListViewModel?
    @State private var showingNewDeck = false
    @State private var showingImport = false
    @State private var showingSortSheet = false
    @State private var deckToEdit: Deck?
    @State private var deckToDelete: DeckSummary?
    @State private var exportDocument = DecklistTextDocument(text: "")
    @State private var showingExporter = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Mazos")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingImport = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .accessibilityLabel("Importar mazo")

                Button {
                    showingNewDeck = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nuevo mazo")
            }
        }
        .task {
            let vm = viewModel ?? DecksListViewModel(store: appStore.store, userId: appStore.userId)
            viewModel = vm
            await vm.load()
        }
        .sheet(isPresented: $showingNewDeck) {
            DeckEditorView(onSave: { deck in
                try? await saveNewDeck(deck)
            })
            .environment(appStore)
        }
        .sheet(isPresented: $showingImport) {
            DeckImportView(username: appStore.session.user?.displayName ?? "Jugador Demo") { deck in
                viewModel?.importDeckLocally(deck)
            }
        }
        .sheet(isPresented: $showingSortSheet) {
            if let vm = viewModel {
                DeckSortAndFilterSheet(
                    sortField: Bindable(vm).sortField,
                    sortDirection: Bindable(vm).sortDirection,
                    selectedColors: Bindable(vm).selectedColors,
                    onReset: { vm.resetFilters() }
                )
            }
        }
        .sheet(item: $deckToEdit) { deck in
            DeckEditorView(deck: deck) { updatedDeck in
                guard let viewModel else { return }
                try await viewModel.updateDeck(updatedDeck)
                await viewModel.load()
            }
            .environment(appStore)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: exportDocument.suggestedFilename
        ) { _ in }
        .alert(item: $deckToDelete) { deck in
            Alert(
                title: Text("¿Eliminar \(deck.name)?"),
                message: Text("Esta acción no se puede deshacer."),
                primaryButton: .destructive(Text("Eliminar")) {
                    Task {
                        try? await viewModel?.deleteDeck(id: deck.id)
                        await viewModel?.load()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    @MainActor
    private func content(_ viewModel: DecksListViewModel) -> some View {
        @Bindable var vm = viewModel

        return VStack(spacing: 0) {
            if let error = vm.errorMessage {
                VStack(spacing: 8) {
                    Text(error).font(.callout).foregroundStyle(.red)
                    Button("Reintentar") { Task { await vm.load() } }
                        .frame(minHeight: 44)
                }
                .padding()
            }
            if vm.isLoading && vm.decks.isEmpty {
                ProgressView("Cargando mazos…")
            } else if vm.decks.isEmpty {
                EmptyStateView(
                    title: vm.emptyStateTitle,
                    message: vm.emptyStateMessage,
                    systemImage: "rectangle.stack.badge.plus",
                    actionTitle: "Crear primer mazo",
                    action: { showingNewDeck = true }
                )
            } else if vm.filteredAndSortedDecks.isEmpty {
                EmptyStateView(
                    title: "Sin resultados",
                    message: "No hay mazos que coincidan con los filtros o búsqueda actuales.",
                    systemImage: "magnifyingglass",
                    actionTitle: "Restablecer filtros",
                    action: { vm.resetFilters() }
                )
            } else {
                VStack(spacing: 0) {
                    List {
                        if vm.isDeckSyncing {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Sincronizando importación…")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(vm.filteredAndSortedDecks) { deck in
                            NavigationLink(value: deck) {
                                DeckCardItemView(deck: deck)
                            }
                            .contextMenu {
                                Button {
                                    Task { deckToEdit = try? await vm.deck(id: deck.id) }
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }

                                Button {
                                    Task {
                                        try? await vm.duplicateDeck(id: deck.id)
                                        await vm.load()
                                    }
                                } label: {
                                    Label("Duplicar", systemImage: "plus.square.on.square")
                                }

                                Menu("Exportar") {
                                    Button {
                                        Task {
                                            UIPasteboard.general.string = try? await vm.decklistText(id: deck.id)
                                        }
                                    } label: {
                                        Label("Copiar al portapapeles", systemImage: "doc.on.doc")
                                    }

                                    Button {
                                        Task {
                                            guard let text = try? await vm.decklistText(id: deck.id) else { return }
                                            exportDocument = DecklistTextDocument(text: text, suggestedFilename: deck.name)
                                            showingExporter = true
                                        }
                                    } label: {
                                        Label("Guardar como .txt", systemImage: "doc.badge.plus")
                                    }
                                }

                                Divider()

                                Button(role: .destructive) {
                                    deckToDelete = deck
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    let deck = vm.filteredAndSortedDecks[index]
                                    try? await vm.deleteDeck(id: deck.id)
                                }
                                await vm.load()
                            }
                        }

                    }
                    .refreshable { await vm.load() }
                    .listStyle(.plain)

                    floatingSortButton(vm)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.mtgSurface)
                }
            }
        }
        .searchable(text: $vm.searchText, prompt: "Buscar mazo, comandante o formato…")
        .navigationDestination(for: DeckSummary.self) { deck in
            DeckDetailView(deckSummary: deck)
                .environment(appStore)
        }
    }

    @MainActor
    private func floatingSortButton(_ vm: DecksListViewModel) -> some View {
        @Bindable var vm = vm

        return Button {
            showingSortSheet = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))

                Text(vm.sortField.displayName)
                    .font(.subheadline.weight(.semibold))

                Image(systemName: vm.sortDirection == .ascending ? "arrow.up" : "arrow.down")
                    .font(.system(size: 11, weight: .bold))

                if !vm.selectedColors.isEmpty {
                    Text("•")
                        .font(.caption2)
                        .opacity(0.6)

                    HStack(spacing: 2) {
                        ForEach(Array(vm.selectedColors.sorted()), id: \.self) { sym in
                            ManaPill(symbol: sym, style: .small)
                        }
                    }
                }
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color.mtgAmber, Color.mtgAmberDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
        }
        .contextMenu {
            Menu("Ordenar por") {
                ForEach(DeckSortField.allCases) { field in
                    Button {
                        vm.sortField = field
                    } label: {
                        if vm.sortField == field {
                            Label(field.displayName, systemImage: "checkmark")
                        } else {
                            Text(field.displayName)
                        }
                    }
                }
            }

            Menu("Dirección") {
                ForEach(SortDirection.allCases) { dir in
                    Button {
                        vm.sortDirection = dir
                    } label: {
                        if vm.sortDirection == dir {
                            Label(dir.displayName, systemImage: "checkmark")
                        } else {
                            Text(dir.displayName)
                        }
                    }
                }
            }

            Menu("Filtrar por color") {
                ForEach(["W", "U", "B", "R", "G", "C"], id: \.self) { col in
                    Button {
                        if vm.selectedColors.contains(col) {
                            vm.selectedColors.remove(col)
                        } else {
                            vm.selectedColors.insert(col)
                        }
                    } label: {
                        let name: String = {
                            switch col {
                            case "W": return "Blanco"
                            case "U": return "Azul"
                            case "B": return "Negro"
                            case "R": return "Rojo"
                            case "G": return "Verde"
                            case "C": return "Incoloro"
                            default: return col
                            }
                        }()
                        if vm.selectedColors.contains(col) {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            }

            if vm.hasActiveFilters {
                Divider()
                Button(role: .destructive) {
                    vm.resetFilters()
                } label: {
                    Label("Restablecer filtros", systemImage: "xmark.circle")
                }
            }
        }
    }

    @MainActor
    private func saveNewDeck(_ deck: Deck) async throws {
        guard let viewModel else { return }
        guard let commander = deck.cards.first(where: { $0.isCommander }) else {
            try await viewModel.createDeck(deck: deck)
            return
        }
        let enriched = try await appStore.catalog.resolveCards(named: [commander.cardName])
        var updated = deck
        if let resolved = enriched.first {
            updated.commanderScryfallId = resolved.scryfallId
            updated.commanderImageUri = resolved.imageUri
        }
        try await viewModel.createDeck(deck: updated)
        await viewModel.load()
    }
}

private struct DecklistTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    let text: String
    let suggestedFilename: String

    init(text: String, suggestedFilename: String = "mazo") {
        self.text = text
        self.suggestedFilename = suggestedFilename
    }

    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
        suggestedFilename = "mazo"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

// MARK: - Deck card item

struct DeckCardItemView: View {
    let deck: DeckSummary

    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(deck.name)
                        .font(.headline)
                        .foregroundStyle(.mtgText)
                        .lineLimit(1)
                    Spacer()
                    Text(deck.format)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.mtgAmber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.mtgAmber.opacity(0.14), in: Capsule())
                }

                HStack {
                    if let commander = deck.commander {
                        Text(commander)
                            .font(.caption)
                            .foregroundStyle(.mtgTextSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if !deck.colors.isEmpty {
                        HStack(spacing: 2) {
                            ForEach(deck.colors, id: \.self) { sym in
                                ManaPill(symbol: sym, style: .small)
                            }
                        }
                    } else {
                        ManaPill(symbol: "C", style: .small)
                    }
                }

                HStack(spacing: 6) {
                    CompletionBar(progress: deck.completionPercentage)
                        .frame(width: 90)
                    Text(deck.completionPercentage.percentFormatted())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(
                            deck.isComplete ? Color.mtgGreen : Color.mtgAmber
                        )
                    Spacer()
                    Text("\(deck.ownedCards)/\(deck.totalCards) cartas")
                        .font(.caption)
                        .foregroundStyle(.mtgTextSecondary)
                }

                HStack {
                    if deck.missingCardsCount > 0 {
                        Text("Faltan \(deck.missingCardsCount) cartas")
                            .font(.caption2)
                            .foregroundStyle(Color.mtgRed)
                    } else {
                        Text("Completo")
                            .font(.caption2)
                            .foregroundStyle(Color.mtgGreen)
                    }

                    Spacer()

                    if deck.estimatedPrice > 0 {
                        HStack(spacing: 3) {
                            Text("Est.")
                                .font(.caption2)
                                .foregroundStyle(.mtgTextSecondary)
                            Text(deck.estimatedPrice.formattedPrice(symbol: "€"))
                                .font(.caption2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.mtgText)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var artwork: some View {
        ZStack {
            if let url = AppConfiguration.imageURL(from: deck.commanderImageUri) {
                CardImageView(url: url, placeholderText: nil)
            } else {
                CardBackPlaceholder.view
            }
        }
        .frame(width: 56, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Deck sort and filter sheet

struct DeckSortAndFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sortField: DeckSortField
    @Binding var sortDirection: SortDirection
    @Binding var selectedColors: Set<String>
    var onReset: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Criterio de ordenación") {
                    Picker("Ordenar por", selection: $sortField) {
                        ForEach(DeckSortField.allCases) { field in
                            Text(field.displayName).tag(field)
                        }
                    }

                    Picker("Dirección", selection: $sortDirection) {
                        ForEach(SortDirection.allCases) { dir in
                            Text(dir.displayName).tag(dir)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    DeckColorFilterRow(selectedColors: $selectedColors)
                } header: {
                    Text("Identidad de color")
                } footer: {
                    Text("Muestra mazos que contienen los colores seleccionados (o incoloros si se selecciona Incoloro).")
                        .font(.caption2)
                }

                if !selectedColors.isEmpty || sortField != .completion || sortDirection != .descending {
                    Section {
                        Button(role: .destructive) {
                            onReset()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Restablecer filtros y orden")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Organizar y filtrar mazos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Deck color filter row

struct DeckColorFilterRow: View {
    @Binding var selectedColors: Set<String>

    let options: [(code: String, label: String)] = [
        ("W", "Blanco"),
        ("U", "Azul"),
        ("B", "Negro"),
        ("R", "Rojo"),
        ("G", "Verde"),
        ("C", "Incoloro")
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(options, id: \.code) { opt in
                let isSelected = selectedColors.contains(opt.code)
                Button {
                    if isSelected {
                        selectedColors.remove(opt.code)
                    } else {
                        selectedColors.insert(opt.code)
                    }
                } label: {
                    HStack(spacing: 8) {
                        ManaPill(symbol: opt.code, style: .small)
                        Text(opt.label)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.mtgText)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.mtgAmber)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.mtgTextSecondary.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.mtgAmber.opacity(0.12) : Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.mtgAmber : Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("Mazos") {
    NavigationStack {
        DecksListView()
            .environment(AppStore.demo)
    }
    .preferredColorScheme(.dark)
}
