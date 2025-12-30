import SwiftUI
import AVFoundation

struct WebcamView: View {
    @ObservedObject var webcamManager: WebcamManager

    var body: some View {
        ZStack {
            Color.clear // Transparent background
            WebcamPreviewContainer(webcamManager: webcamManager)
                .aspectRatio(16/9, contentMode: .fit)
                .shadow(radius: 6) // Optional for a subtle pop
                .padding(-22)
        }
    }
}

struct WebcamPreviewContainer: NSViewRepresentable {
    @ObservedObject var webcamManager: WebcamManager

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let session = webcamManager.session else {
                print("❌ No active camera session")
                return
            }

            if let previewLayer = nsView.layer as? AVCaptureVideoPreviewLayer {
                previewLayer.session = session
                print("🔄 Updated preview layer with active session")
            } else {
                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = nsView.bounds

                if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = true
                    print("✅ Mirrored video enabled")
                } else {
                    print("⚠️ Video mirroring not supported")
                }

                nsView.layer = previewLayer
                print("✅ Preview layer assigned")
            }
        }
    }
}
