import SwiftUI

// MARK: - Add card to deck sheet

/// Lets the user search Scryfall for a card and add it to the deck at any time,
/// choosing quantity and whether it goes to the mainboard or the sideboard.
struct AddCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CardSearchViewModelMine()

    let title: String
    let onAdd: (ScryfallCard, Int, Bool) async throws -> Void

    @State private var selectedCard: ScryfallCard?
    @State private var quantity = 1
    @State private var isSideboard = false
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let selectedCard {
                    confirmView(selectedCard)
                } else {
                    searchView
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if selectedCard != nil {
                        Button("Atrás") { selectedCard = nil }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if selectedCard == nil {
                        Button("Cancelar") { dismiss() }
                    }
                }
            }
        }
        .tint(.mtgAmber)
    }

    // MARK: Search

    @MainActor
    private var searchView: some View {
        List {
            if let names = viewModel.suggestions, !names.isEmpty, !viewModel.searchText.isEmpty {
                Section("Sugerencias") {
                    ForEach(names.prefix(6), id: \.self) { name in
                        Button(name) {
                            viewModel.query = name
                        }
                        .foregroundStyle(.mtgText)
                    }
                }
            }

            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }

            if !viewModel.error.isNil {
                Section {
                    Label(viewModel.error!, systemImage: "exclamationmark.triangle")
                }
            } else if !viewModel.results.isEmpty {
                Section("Resultados") {
                    ForEach(viewModel.results) { card in
                        Button {
                            selectedCard = card
                            quantity = 1
                            isSideboard = false
                        } label: {
                            HStack {
                                CardImageView(url: card.displayImageSmallUrl, placeholderText: nil, targetSize: 96)
                                    .frame(width: 34, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.mtgText)
                                    HStack {
                                        ManaCostView(cost: card.displayManaCost)
                                        Text(card.displayTypeLine ?? "")
                                            .font(.caption2)
                                            .foregroundStyle(.mtgTextSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.mtgAmber)
                            }
                        }
                    }
                }
            } else if !viewModel.searchText.isEmpty && !viewModel.isLoading {
                Section {
                    Text("Escribe al menos 2 caracteres para buscar en Scryfall.")
                        .font(.caption)
                        .foregroundStyle(.mtgTextSecondary)
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Buscar carta en Scryfall…")
        .onChange(of: viewModel.searchText) {
            viewModel.searched()
        }
        .overlay {
            if viewModel.searchText.isEmpty && viewModel.results.isEmpty {
                ContentUnavailableView {
                    Label("Buscar carta", systemImage: "magnifyingglass")
                } description: {
                    Text("Encuentra cualquier carta para añadirla al mazo.")
                }
            }
        }
    }

    // MARK: Confirm

    @MainActor
    private func confirmView(_ card: ScryfallCard) -> some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    CardImageView(url: card.displayImageUrl, placeholderText: nil)
                        .frame(width: 62, height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.name)
                            .font(.headline)
                            .foregroundStyle(.mtgText)
                        HStack(spacing: 6) {
                            ManaCostView(cost: card.displayManaCost)
                            if let typeLine = card.displayTypeLine, !typeLine.isEmpty {
                                Text(typeLine)
                                    .font(.caption2)
                                    .foregroundStyle(.mtgTextSecondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Configuración") {
                Stepper(value: $quantity, in: 1...99) {
                    LabeledContent("Cantidad", value: "\(quantity)")
                }
                Picker("Añadir a", selection: $isSideboard) {
                    Text("Mazo principal").tag(false)
                    Text("Reservas (sideboard)").tag(true)
                }
                .pickerStyle(.segmented)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.mtgRed)
                }
            }

            Section {
                Button {
                    Task {
                        isAdding = true
                        errorMessage = nil
                        defer { isAdding = false }
                        do {
                            try await onAdd(card, quantity, isSideboard)
                            dismiss()
                        } catch {
                            errorMessage = "No se pudo añadir la carta: \(error.localizedDescription)"
                        }
                    }
                } label: {
                    if isAdding {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Text("Añadir")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
                .disabled(isAdding)
                .buttonStyle(.borderedProminent)
                .tint(.mtgAmber)
            }
            .listRowBackground(Color.clear)
        }
    }
}

// MARK: - Preview

#Preview("Añadir carta") {
    AddCardSheet(title: "Añadir carta", onAdd: { _, _, _ in })
        .preferredColorScheme(.dark)
}
