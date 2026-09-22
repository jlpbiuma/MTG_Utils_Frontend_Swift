import SwiftUI
import Charts

// MARK: - Collection Value Chart (SwiftUI Charts)

struct CollectionValueChartView: View {
    @Environment(AppStore.self) private var appStore

    @State private var historyResponse: CollectionValueHistoryResponse?
    @State private var selectedDays = 30
    @State private var isLoading = true

    private let dayOptions = [30, 90, 365]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Evolución del Valor")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.mtgTextSecondary)

                    if let resp = historyResponse {
                        Text(resp.currentValue.formattedPrice(symbol: resp.currencySymbol))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.mtgAmber)
                    } else {
                        Text("—")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.mtgAmber)
                    }
                }

                Spacer()

                // Period Picker
                Picker("Período", selection: $selectedDays) {
                    ForEach(dayOptions, id: \.self) { days in
                        Text("\(days)d").tag(days)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .onChange(of: selectedDays) { _, _ in
                    Task { await loadHistory() }
                }
            }

            if isLoading && historyResponse == nil {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 120)
            } else if let points = historyResponse?.points, !points.isEmpty {
                Chart {
                    ForEach(points) { pt in
                        AreaMark(
                            x: .value("Fecha", pt.date),
                            y: .value("Valor", pt.totalValue)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.mtgAmber.opacity(0.3), Color.mtgAmber.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Fecha", pt.date),
                            y: .value("Valor", pt.totalValue)
                        )
                        .foregroundStyle(Color.mtgAmber)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel {
                            if let doubleVal = value.as(Double.self) {
                                Text("\(Int(doubleVal))\(historyResponse?.currencySymbol ?? "€")")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.mtgTextSecondary)
                            }
                        }
                    }
                }
                .frame(height: 120)
            } else {
                Text("Historial de valoración aún no disponible.")
                    .font(.caption)
                    .foregroundStyle(Color.mtgTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 60)
            }
        }
        .padding()
        .background(Color.mtgSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task { await loadHistory() }
    }

    private func loadHistory() async {
        isLoading = true
        do {
            historyResponse = try await appStore.client.collectionValueHistory(
                provider: appStore.settings.priceProvider,
                days: selectedDays,
                userId: appStore.userId,
                accessToken: appStore.accessToken
            )
        } catch {
            // Silently fallback if no historical data yet
            historyResponse = nil
        }
        isLoading = false
    }
}
