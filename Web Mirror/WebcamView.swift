import SwiftUI
import AVFoundation

struct WebcamView: View {
    @ObservedObject var webcamManager: WebcamManager
    @ObservedObject var micLevelManager: MicLevelManager

    private var micCheckEnabled: Bool {
        UserDefaults.standard.bool(forKey: "MicCheckEnabled")
    }

    var body: some View {
        ZStack {
            WebcamPreviewContainer(webcamManager: webcamManager)
                .aspectRatio(16/9, contentMode: .fit)
                .shadow(radius: 6)
                .padding(-22)

            if micCheckEnabled {
                VStack {
                    Spacer()
                    HStack {
                        MicLevelIndicatorView(level: micLevelManager.level)
                        Spacer()
                    }
                }
                .padding(8)
            }
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
