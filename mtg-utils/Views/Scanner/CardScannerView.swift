import AVFoundation
import SwiftUI

// MARK: - Camera card scanner

struct CardScannerView: View {
    @State private var viewModel: CardScannerViewModel
    @State private var showPermissionAlert = false

    init(appStore: AppStore) {
        _viewModel = State(initialValue: CardScannerViewModel(appStore: appStore))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.phase {
            case .detected(let scanned):
                detectedContent(scanned)
            case .adding:
                loadingContent("Guardando en tu colección…")
            case .recognizing:
                ZStack {
                    scannerContent(showShutter: false)
                    loadingContent("Identificando carta…")
                        .padding(24)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                }
            case .requestingPermission:
                loadingContent("Comprobando permiso de cámara…")
            case .permissionDenied:
                permissionDeniedContent
            case .error(let message):
                errorContent(message)
            case .idle, .scanning:
                scannerContent(showShutter: true)
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .alert("Permiso de cámara", isPresented: $showPermissionAlert) {
            Button("Abrir Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("MTG Utils necesita acceso a la cámara para escanear cartas. Puedes activarlo en Ajustes > Privacidad > Cámara.")
        }
    }

    // MARK: - Live scanning UI

    private func scannerContent(showShutter: Bool) -> some View {
        ZStack {
            CameraPreview(session: viewModel.previewSession)
                .ignoresSafeArea()

            VStack {
                Spacer()

                Text("Encuadra la carta y pulsa el disparador")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(.black.opacity(0.55), in: Capsule())

                Spacer()

                scanGuide
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showShutter {
                    Button {
                        viewModel.captureAndScan()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 72, height: 72)
                            Circle()
                                .strokeBorder(.white.opacity(0.9), lineWidth: 4)
                                .frame(width: 84, height: 84)
                        }
                    }
                    .accessibilityLabel("Escanear carta")
                    .padding(.bottom, 36)
                }
            }
        }
    }

    private var scanGuide: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.mtgAmber.opacity(0.9), lineWidth: 3)
                .frame(width: 260, height: 360)
                .shadow(color: .black.opacity(0.6), radius: 8)
        }
    }

    // MARK: - Detected card UI

    private func detectedContent(_ scanned: ScannedCard) -> some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                CardImageView(url: scanned.imageUrl, placeholderText: scanned.name, targetSize: 320)
                    .frame(width: 196, height: 274)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.6), radius: 12, y: 6)
                if let typeLine = scanned.typeLine {
                    Text(typeLine)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(4)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                        .padding(.bottom, 8)
                        .frame(maxWidth: 196, maxHeight: 274, alignment: .bottom)
                }
            }

            VStack(spacing: 6) {
                Text(scanned.name)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                if let setCode = scanned.setCode {
                    Text("\(setCode.uppercased()) \(scanned.collectorNumber ?? "")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                if let trend = scanned.match.printing?.priceCardmarketTrend {
                    Text(String(format: "Trend %.2f €", trend))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.mtgAmber)
                }
            }

            Stepper(value: $viewModel.quantity, in: 1...99, step: 1) {
                Text("Cantidad: \(viewModel.quantity)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: 280)

            VStack(spacing: 10) {
                Button {
                    Task { await viewModel.addToCollection() }
                } label: {
                    Label("Añadir a colección", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mtgAmber)

                Button {
                    viewModel.resumeScanning()
                } label: {
                    Label("Escanear otra carta", systemImage: "viewfinder")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .padding(.vertical, 24)
    }

    // MARK: - Auxiliary states

    private func loadingContent(_ message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.mtgAmber)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var permissionDeniedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(.mtgAmber)
            Text("Sin acceso a la cámara")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Activa la cámara para poder escanear cartas.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
            Button("Abrir Ajustes") {
                showPermissionAlert = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.mtgAmber)
        }
        .padding(24)
        .multilineTextAlignment(.center)
    }

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.mtgAmber)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button("Reintentar") {
                viewModel.retry()
            }
            .buttonStyle(.borderedProminent)
            .tint(.mtgAmber)
        }
        .padding(24)
    }

}

#Preview {
    CardScannerView(appStore: .demo)
        .environment(AppStore.demo)
        .preferredColorScheme(.dark)
}
