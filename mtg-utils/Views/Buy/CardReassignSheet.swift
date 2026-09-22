import SwiftUI

// MARK: - Card Reassignment Sheet

struct CardReassignSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: PriorityItem
    let onReassign: (String, String, String, Int) async -> Void

    @State private var selectedOption: DeckReassignOption?
    @State private var isReassigning = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    if let imageUri = item.imageUri, let url = URL(string: imageUri) {
                        CardImageView(url: url, placeholderText: nil, targetSize: 150)
                            .frame(width: 48, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.cardName)
                            .font(.headline)
                            .foregroundStyle(Color.mtgText)
                        ManaCostView(cost: item.manaCost)
                        Text(item.typeLine ?? "")
                            .font(.caption)
                            .foregroundStyle(Color.mtgTextSecondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.mtgSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("Selecciona de qué mazo transferir copias para completar el mazo de destino:")
                    .font(.subheadline)
                    .foregroundStyle(Color.mtgTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                List(item.reassignOptions) { option in
                    Button {
                        selectedOption = option
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Desde:")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.mtgTextSecondary)
                                    Text(option.sourceDeckName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.mtgText)
                                    Text("(\(Int(option.sourceDeckCompletion))% comp.)")
                                        .font(.caption2)
                                        .foregroundStyle(Color.mtgTextSecondary)
                                }

                                HStack {
                                    Image(systemName: "arrow.down.right")
                                        .font(.caption)
                                        .foregroundStyle(Color.mtgAmber)
                                    Text("Hacia:")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.mtgTextSecondary)
                                    Text(option.targetDeckName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.mtgText)
                                    Text("(\(Int(option.targetDeckCompletion))% comp.)")
                                        .font(.caption2)
                                        .foregroundStyle(Color.mtgTextSecondary)
                                }
                            }

                            Spacer()

                            if selectedOption?.id == option.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.mtgAmber)
                                    .font(.title3)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.insetGrouped)
            }
            .padding()
            .navigationTitle("Reasignar carta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reasignar") {
                        guard let opt = selectedOption else { return }
                        isReassigning = true
                        Task {
                            await onReassign(opt.sourceDeckId, opt.targetDeckId, item.cardScryfallId, 1)
                            isReassigning = false
                            dismiss()
                        }
                    }
                    .disabled(selectedOption == nil || isReassigning)
                }
            }
        }
    }
}
