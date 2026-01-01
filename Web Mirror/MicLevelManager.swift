//
//  MicLevelManager.swift
//  Web Mirror
//
//  Created by Leonardo Munarolo on 1/1/26.
//


import AVFoundation
import Combine
import CoreGraphics
import Accelerate

final class MicLevelManager: ObservableObject {

    // Normalized level: 0.0 (silent) → 1.0 (loud)
    @Published private(set) var level: CGFloat = 0.0

    private let engine = AVAudioEngine()
    private let sessionQueue = DispatchQueue(
        label: "MicLevelManager.Queue",
        qos: .userInitiated
    )

    private var isRunning = false

    // Smoothing
    private let attack: CGFloat = 0.25   // how fast it rises
    private let decay: CGFloat = 0.90    // how slow it falls

    // MARK: - Lifecycle

    func start() {
        sessionQueue.async {
            guard !self.isRunning else { return }

            self.requestPermissionIfNeeded { granted in
                guard granted else { return }
                self.startEngine()
            }
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.isRunning else { return }

            self.engine.inputNode.removeTap(onBus: 0)
            self.engine.stop()

            self.isRunning = false

            DispatchQueue.main.async {
                self.level = 0.0
            }
        }
    }

    // MARK: - Permission

    private func requestPermissionIfNeeded(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            completion(true)

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                completion(granted)
            }

        default:
            completion(false)
        }
    }

    // MARK: - Engine

    private func startEngine() {
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) {
            [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        do {
            try engine.start()
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    // MARK: - Level Processing

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 { return }

        var rms: Float = 0.0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))

        // Convert RMS to a normalized 0–1 range
        let normalized = min(max(CGFloat(rms) * 8.0, 0.0), 1.0)

        DispatchQueue.main.async {
            let rising = normalized > self.level
            let factor = rising ? self.attack : self.decay

            self.level = self.level * factor + normalized * (1.0 - factor)
        }
        print("Mic RMS:", rms)
    }
}
