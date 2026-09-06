import Combine
import SwiftUI

// MARK: - Async image loading with caching

@MainActor
final class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    private static let cache = NSCache<NSString, UIImage>()
    private var url: URL?

    func load(from url: URL?) {
        guard let url, self.url != url else { return }
        self.url = url

        if let cached = Self.cache.object(forKey: url.absoluteString as NSString) {
            image = cached
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let loadedImage = UIImage(data: data) {
                    Self.cache.setObject(loadedImage, forKey: url.absoluteString as NSString)
                    if self.url == url {
                        image = loadedImage
                    }
                }
            } catch {
                // Ignore; image stays nil.
            }
        }
    }
}

/// Displays a card image, showing an async-loading placeholder when unavailable.
struct CardImageView: View {
    let url: URL?
    let placeholderText: String?

    @StateObject private var loader = ImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(red: 0.12, green: 0.13, blue: 0.16)
                    if let placeholderText {
                        Text(placeholderText)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(4)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear { loader.load(from: url) }
    }
}