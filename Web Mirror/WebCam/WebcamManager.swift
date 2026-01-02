import AVFoundation

final class WebcamManager: NSObject, ObservableObject {

    @Published private(set) var session: AVCaptureSession?

    private let sessionQueue = DispatchQueue(
        label: "WebcamManager.SessionQueue",
        qos: .userInitiated
    )
    private var input: AVCaptureDeviceInput?
    private var isSessionRunning = false

    private(set) var availableDevices: [AVCaptureDevice] = []
    private var selectedDeviceID: String?

    override init() {
        super.init()
        refreshDevices()
        loadSavedCamera()
    }

    // MARK: - Device Discovery

    func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .externalUnknown
            ],
            mediaType: .video,
            position: .unspecified
        )

        availableDevices = discovery.devices
    }

    // MARK: - Camera Selection

    func selectCamera(with id: String) {
        guard selectedDeviceID != id else { return }

        selectedDeviceID = id
        UserDefaults.standard.set(id, forKey: "SelectedCameraID")

        if isSessionRunning {
            stopSession()
            startSession()
        }
    }

    private func loadSavedCamera() {
        selectedDeviceID = UserDefaults.standard.string(forKey: "SelectedCameraID")
    }

    private func currentDevice() -> AVCaptureDevice? {
        refreshDevices()

        if let id = selectedDeviceID,
           let device = availableDevices.first(where: { $0.uniqueID == id }) {
            return device
        }

        return availableDevices.first
    }

    // MARK: - Session Lifecycle

    func startSession() {
        sessionQueue.async {
            guard !self.isSessionRunning,
                  let device = self.currentDevice() else { return }

            self.isSessionRunning = true

            let session = AVCaptureSession()
            session.sessionPreset = .high

            do {
                let input = try AVCaptureDeviceInput(device: device)

                guard session.canAddInput(input) else {
                    self.isSessionRunning = false
                    return
                }

                session.addInput(input)

                DispatchQueue.main.async {
                    self.input = input
                    self.session = session
                    session.startRunning()
                }
            } catch {
                self.isSessionRunning = false
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.isSessionRunning else { return }

            self.isSessionRunning = false

            DispatchQueue.main.async {
                self.session?.stopRunning()
                self.session = nil
                self.input = nil
            }
        }
    }
}
