import SwiftUI

struct ZoomableImageView: View {
    let imageURL: URL
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZoomableScrollView {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                    } else if phase.error != nil {
                        Text("Не удалось загрузить изображение")
                    } else {
                        ProgressView()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 4.0
        scrollView.minimumZoomScale = 1.0
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        
        let hostedView = UIHostingController(rootView: content).view!
        hostedView.translatesAutoresizingMaskIntoConstraints = true
        hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostedView.frame = scrollView.bounds
        scrollView.addSubview(hostedView)
        
        context.coordinator.hostingView = hostedView
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if let hostingView = context.coordinator.hostingView {
            hostingView.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var hostingView: UIView?
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingView
        }
    }
}
