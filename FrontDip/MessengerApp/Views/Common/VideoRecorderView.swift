import SwiftUI
import UIKit
import AVFoundation

struct VideoRecorderView: UIViewControllerRepresentable {
    let onRecordingFinished: (URL) -> Void

    func makeUIViewController(context: Context) -> VideoRecorderViewController {
        let controller = VideoRecorderViewController()
        controller.onRecordingFinished = onRecordingFinished
        controller.modalPresentationStyle = .overFullScreen
        return controller
    }

    func updateUIViewController(_ uiViewController: VideoRecorderViewController, context: Context) {}
}

final class VideoRecorderViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    var onRecordingFinished: ((URL) -> Void)?

    private let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentVideoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var currentCameraPosition: AVCaptureDevice.Position = .front
    private var outputURL: URL?
    private var isRecording = false
    private var timer: Timer?
    private var secondsElapsed = 0

    private let backgroundView = UIView()
    private let previewContainer = UIView()
    private let ringView = UIView()
    private let topGradient = CAGradientLayer()

    private let closeButton = UIButton(type: .system)
    private let flipButton = UIButton(type: .system)
    private let timerBadge = UIView()
    private let timerDot = UIView()
    private let timerLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let shutterOuter = UIView()
    private let shutterInner = UIView()
    private let shutterButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        checkPermissionsAndSetup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        previewLayer?.frame = previewContainer.bounds
        previewContainer.layer.cornerRadius = previewContainer.bounds.width / 2
        ringView.layer.cornerRadius = ringView.bounds.width / 2
        shutterOuter.layer.cornerRadius = shutterOuter.bounds.width / 2
        shutterInner.layer.cornerRadius = shutterInner.bounds.width / 2

        topGradient.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 180)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        if session.isRunning {
            session.stopRunning()
        }
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func setupUI() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.backgroundColor = .black
        view.addSubview(backgroundView)

        topGradient.colors = [
            UIColor.black.withAlphaComponent(0.58).cgColor,
            UIColor.clear.cgColor
        ]
        view.layer.addSublayer(topGradient)

        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.backgroundColor = UIColor(white: 0.14, alpha: 1)
        previewContainer.clipsToBounds = true
        view.addSubview(previewContainer)

        ringView.translatesAutoresizingMaskIntoConstraints = false
        ringView.layer.borderWidth = 4
        ringView.layer.borderColor = UIColor.white.withAlphaComponent(0.92).cgColor
        ringView.backgroundColor = .clear
        view.addSubview(ringView)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.34)
        closeButton.layer.cornerRadius = 22
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        flipButton.translatesAutoresizingMaskIntoConstraints = false
        flipButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera"), for: .normal)
        flipButton.tintColor = .white
        flipButton.backgroundColor = UIColor.black.withAlphaComponent(0.34)
        flipButton.layer.cornerRadius = 22
        flipButton.addTarget(self, action: #selector(flipTapped), for: .touchUpInside)
        view.addSubview(flipButton)

        timerBadge.translatesAutoresizingMaskIntoConstraints = false
        timerBadge.backgroundColor = UIColor.black.withAlphaComponent(0.38)
        timerBadge.layer.cornerRadius = 18
        view.addSubview(timerBadge)

        timerDot.translatesAutoresizingMaskIntoConstraints = false
        timerDot.backgroundColor = .systemRed
        timerDot.layer.cornerRadius = 5
        timerBadge.addSubview(timerDot)

        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerLabel.text = "00:00"
        timerLabel.textColor = .white
        timerLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        timerBadge.addSubview(timerLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Видеосообщение"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = ""
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.68)
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textAlignment = .center
        view.addSubview(subtitleLabel)

        shutterOuter.translatesAutoresizingMaskIntoConstraints = false
        shutterOuter.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        shutterOuter.layer.borderWidth = 2
        shutterOuter.layer.borderColor = UIColor.white.withAlphaComponent(0.78).cgColor
        view.addSubview(shutterOuter)

        shutterInner.translatesAutoresizingMaskIntoConstraints = false
        shutterInner.backgroundColor = .white
        shutterOuter.addSubview(shutterInner)

        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = .clear
        shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        shutterOuter.addSubview(shutterButton)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            flipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            flipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            flipButton.widthAnchor.constraint(equalToConstant: 44),
            flipButton.heightAnchor.constraint(equalToConstant: 44),

            timerBadge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timerBadge.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            timerBadge.heightAnchor.constraint(equalToConstant: 36),
            timerBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 92),

            timerDot.leadingAnchor.constraint(equalTo: timerBadge.leadingAnchor, constant: 12),
            timerDot.centerYAnchor.constraint(equalTo: timerBadge.centerYAnchor),
            timerDot.widthAnchor.constraint(equalToConstant: 10),
            timerDot.heightAnchor.constraint(equalToConstant: 10),

            timerLabel.leadingAnchor.constraint(equalTo: timerDot.trailingAnchor, constant: 8),
            timerLabel.trailingAnchor.constraint(equalTo: timerBadge.trailingAnchor, constant: -12),
            timerLabel.centerYAnchor.constraint(equalTo: timerBadge.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: timerBadge.bottomAnchor, constant: 26),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            previewContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            previewContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -12),
            previewContainer.widthAnchor.constraint(equalToConstant: 290),
            previewContainer.heightAnchor.constraint(equalToConstant: 290),

            ringView.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            ringView.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            ringView.widthAnchor.constraint(equalTo: previewContainer.widthAnchor, constant: 10),
            ringView.heightAnchor.constraint(equalTo: previewContainer.heightAnchor, constant: 10),

            shutterOuter.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterOuter.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -34),
            shutterOuter.widthAnchor.constraint(equalToConstant: 92),
            shutterOuter.heightAnchor.constraint(equalToConstant: 92),

            shutterInner.centerXAnchor.constraint(equalTo: shutterOuter.centerXAnchor),
            shutterInner.centerYAnchor.constraint(equalTo: shutterOuter.centerYAnchor),
            shutterInner.widthAnchor.constraint(equalToConstant: 72),
            shutterInner.heightAnchor.constraint(equalToConstant: 72),

            shutterButton.leadingAnchor.constraint(equalTo: shutterOuter.leadingAnchor),
            shutterButton.trailingAnchor.constraint(equalTo: shutterOuter.trailingAnchor),
            shutterButton.topAnchor.constraint(equalTo: shutterOuter.topAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: shutterOuter.bottomAnchor)
        ])
    }

    private func checkPermissionsAndSetup() {
        let group = DispatchGroup()
        var videoAllowed = false
        var audioAllowed = false

        group.enter()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            videoAllowed = true
            group.leave()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                videoAllowed = granted
                group.leave()
            }
        default:
            group.leave()
        }

        group.enter()
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            audioAllowed = true
            group.leave()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                audioAllowed = granted
                group.leave()
            }
        default:
            group.leave()
        }

        group.notify(queue: .main) {
            guard videoAllowed, audioAllowed else {
                self.presentPermissionAlert()
                return
            }
            self.setupCameraSession()
        }
    }

    private func setupCameraSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard
            let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
            let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
        else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
            currentVideoInput = videoInput
        }

        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(micInput) {
            session.addInput(micInput)
            audioInput = micInput
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = previewContainer.bounds

        previewLayer?.removeFromSuperlayer()
        previewLayer = preview
        previewContainer.layer.insertSublayer(preview, at: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    @objc private func closeTapped() {
        if isRecording {
            stopRecording()
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func flipTapped() {
        guard !isRecording else { return }
        currentCameraPosition = currentCameraPosition == .front ? .back : .front
        setupCameraSession()
    }

    @objc private func shutterTapped() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        guard !movieOutput.isRecording else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        outputURL = url

        if let connection = movieOutput.connection(with: .video), connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .auto
        }

        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        secondsElapsed = 0
        timerLabel.text = "00:00"

        UIView.animate(withDuration: 0.18) {
            self.shutterInner.backgroundColor = .systemRed
            self.shutterInner.layer.cornerRadius = 16
            self.shutterInner.transform = CGAffineTransform(scaleX: 0.62, y: 0.62)
            self.ringView.layer.borderColor = UIColor.systemRed.cgColor
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.secondsElapsed += 1
            let m = self.secondsElapsed / 60
            let s = self.secondsElapsed % 60
            self.timerLabel.text = String(format: "%02d:%02d", m, s)

            if self.secondsElapsed >= 60 {
                self.stopRecording()
            }
        }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
        isRecording = false
        timer?.invalidate()
        timer = nil

        UIView.animate(withDuration: 0.18) {
            self.shutterInner.backgroundColor = .white
            self.shutterInner.layer.cornerRadius = self.shutterInner.bounds.width / 2
            self.shutterInner.transform = .identity
            self.ringView.layer.borderColor = UIColor.white.withAlphaComponent(0.92).cgColor
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        guard error == nil else {
            dismiss(animated: true)
            return
        }

        dismiss(animated: true) { [weak self] in
            self?.onRecordingFinished?(outputFileURL)
        }
    }

    private func presentPermissionAlert() {
        let alert = UIAlertController(
            title: "Нет доступа к камере или микрофону",
            message: "Разреши доступ к камере и микрофону в настройках iPhone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}
