import SwiftUI

private enum ImageCacheManager {
    static let cache: URLCache = {
        let memoryCapacity = 50 * 1024 * 1024 // 50 MB
        let diskCapacity = 100 * 1024 * 1024 // 100 MB
        return URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, directory: nil)
    }()
    
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()
}

struct PersistentAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        SwiftUI.Group {
            switch phase {
            case .empty:
                placeholder()
            case .success(let image):
                content(image)
            case .failure:
                placeholder()
            @unknown default:
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url else {
            phase = .empty
            return
        }
        
        let request = URLRequest(url: url)
        
        // Check cache first
        if let cachedResponse = ImageCacheManager.cache.cachedResponse(for: request),
           let uiImage = UIImage(data: cachedResponse.data) {
            phase = .success(Image(uiImage: uiImage))
            return
        }
        
        do {
            let (data, response) = try await ImageCacheManager.session.data(for: request)
            
            if let uiImage = UIImage(data: data) {
                let image = Image(uiImage: uiImage)
                phase = .success(image)
                
                // Ensure it's stored in cache
                let cached = CachedURLResponse(response: response, data: data)
                ImageCacheManager.cache.storeCachedResponse(cached, for: request)
            } else {
                phase = .failure(NSError(domain: "ImageError", code: 0))
            }
        } catch {
            phase = .failure(error)
        }
    }
}
