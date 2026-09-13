import Combine
import SwiftUI
import CryptoKit
import Kingfisher

// MARK: - Dedicated background image pipeline with memory + disk cache and downsampling

actor ImagePipeline {
    static let shared = ImagePipeline()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let diskCacheURL: URL?
    private let session: URLSession

    init() {
        // Memory cache limits: 60 MB total cost, maximum 300 images
        memoryCache.totalCostLimit = 60 * 1024 * 1024
        memoryCache.countLimit = 300

        // Disk cache directory in Caches/CardImages
        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let dir = caches.appendingPathComponent("CardImages", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.diskCacheURL = dir
        } else {
            self.diskCacheURL = nil
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    /// Fast synchronous memory-cache check (called from any thread/actor)
    nonisolated func memoryCachedImage(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url as NSURL)
    }

    /// Loads, caches (disk + memory), and downsamples an image completely off the main thread.
    func image(for url: URL, maxPixelSize: Int = 240) async -> UIImage? {
        // 1. Check memory cache
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }

        // 2. Check disk cache
        let filename = diskKey(for: url)
        if let diskDir = diskCacheURL {
            let fileURL = diskDir.appendingPathComponent(filename)
            if let data = try? Data(contentsOf: fileURL),
               let decoded = downsample(data: data, maxPixelSize: maxPixelSize) {
                let cost = Int(decoded.size.width * decoded.size.height * 4)
                memoryCache.setObject(decoded, forKey: url as NSURL, cost: cost)
                return decoded
            }
        }

        // 3. Network fetch
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }

            // Save raw data to disk in background
            if let diskDir = diskCacheURL {
                let fileURL = diskDir.appendingPathComponent(filename)
                try? data.write(to: fileURL, options: .atomic)
            }

            // Downsample and decode off the main thread
            guard let decoded = downsample(data: data, maxPixelSize: maxPixelSize) else {
                return nil
            }

            let cost = Int(decoded.size.width * decoded.size.height * 4)
            memoryCache.setObject(decoded, forKey: url as NSURL, cost: cost)
            return decoded
        } catch {
            return nil
        }
    }

    private func diskKey(for url: URL) -> String {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined() + ".img"
    }

    private func downsample(data: Data, maxPixelSize: Int) -> UIImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return UIImage(data: data)
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Observable ImageLoader for SwiftUI views

@MainActor
final class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false

    private var url: URL?
    private var loadTask: Task<Void, Never>?

    func load(from url: URL?, targetSize: Int = 240) {
        guard let url else {
            image = nil
            isLoading = false
            return
        }

        if self.url == url && image != nil {
            return
        }

        self.url = url
        loadTask?.cancel()

        // Synchronous memory check: instant render if already cached
        if let cached = ImagePipeline.shared.memoryCachedImage(for: url) {
            self.image = cached
            self.isLoading = false
            return
        }

        isLoading = true
        loadTask = Task { [weak self] in
            let loaded = await ImagePipeline.shared.image(for: url, maxPixelSize: targetSize)
            guard !Task.isCancelled else { return }
            guard let self, self.url == url else { return }
            self.image = loaded
            self.isLoading = false
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
}

// MARK: - CardImageView

/// Displays a card image with async off-main-thread downsampling, cancellation on disappear,
/// and responsive placeholder support.
struct CardImageView: View {
    let url: URL?
    let placeholderText: String?
    var targetSize: Int = 240

    var body: some View {
        let reachableURL = AppConfiguration.reachableImageURL(url)
        ZStack {
            if let url = reachableURL {
                KFImage.url(url)
                    .placeholder { placeholder }
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: targetSize, height: targetSize)))
                    .cacheOriginalImage()
                    .cancelOnDisappear(true)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
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
