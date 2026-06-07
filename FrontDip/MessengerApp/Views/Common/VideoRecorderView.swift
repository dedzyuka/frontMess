//
//  VideoRecorderView.swift
//  MessengerApp
//

import SwiftUI
import AVFoundation

// MARK: - SwiftUI обёртка
struct VideoRecorderView: UIViewControllerRepresentable {
    let onRecordingFinished: (URL) -> Void
    
    func makeUIViewController(context: Context) -> VideoRecorderViewController {
        let controller = VideoRecorderViewController()
        controller.onRecordingFinished = onRecordingFinished
        return controller
    }
    
    func updateUIViewController(_ uiViewController: VideoRecorderViewController, context: Context) {}
}

// MARK: - UIViewController с камерой
class VideoRecorderViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    
    var onRecordingFinished: ((URL) -> Void)?
    
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var outputURL: URL?
    private var isRecording = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkPermissionsAndSetup()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func checkPermissionsAndSetup() {
        // Проверка камеры
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.checkPermissionsAndSetup()
                    }
                } else {
                    self.showAccessDeniedAlert()
                }
            }
            return
        default:
            showAccessDeniedAlert()
            return
        }
        
        // Проверка микрофона
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        default:
            print("⚠️ Микрофон запрещён – видео будет без звука")
        }
        
        setupCamera()
    }
    
    private func setupCamera() {
        // Создаём сессию
        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("❌ Нет камеры")
            return
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: device) else {
            print("❌ Не удалось создать видеовход")
            return
        }
        
        session.addInput(videoInput)
        
        // Аудио вход (если разрешён)
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
            session.addInput(audioInput)
        }
        
        let output = AVCaptureMovieFileOutput()
        session.addOutput(output)
        movieOutput = output
        
        // Запускаем сессию в фоновом потоке, чтобы не блокировать UI
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            DispatchQueue.main.async {
                self.session = session
                self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
                self.previewLayer?.videoGravity = .resizeAspectFill
                self.previewLayer?.frame = self.view.bounds
                if let layer = self.previewLayer {
                    self.view.layer.addSublayer(layer)
                }
                self.setupUI()
            }
        }
    }
    
    private func setupUI() {
        let button = UIButton(type: .system)
        button.setTitle("⏺ Записать", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = UIColor.red.withAlphaComponent(0.8)
        button.layer.cornerRadius = 30
        button.frame = CGRect(x: 0, y: 0, width: 140, height: 60)
        button.center = CGPoint(x: view.bounds.midX, y: view.bounds.height - 100)
        button.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        view.addSubview(button)
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Отмена", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.frame = CGRect(x: 20, y: 40, width: 80, height: 40)
        view.addSubview(cancelButton)
    }
    
    @objc private func recordButtonTapped() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    private func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString + ".mp4")
        outputURL = fileURL
        movieOutput?.startRecording(to: fileURL, recordingDelegate: self)
        isRecording = true
        
        if let button = view.subviews.first(where: { $0 is UIButton && ($0 as? UIButton)?.title(for: .normal) == "⏺ Записать" }) as? UIButton {
            button.setTitle("⏹ Остановить", for: .normal)
            button.backgroundColor = UIColor.gray.withAlphaComponent(0.8)
        }
    }
    
    private func stopRecording() {
        movieOutput?.stopRecording()
        isRecording = false
    }
    
    private func showAccessDeniedAlert() {
        let alert = UIAlertController(title: "Нет доступа к камере",
                                      message: "Разрешите доступ в настройках iPhone",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("📹 didFinishRecordingTo called, error: \(error?.localizedDescription ?? "none")")
        DispatchQueue.main.async {
            if let url = self.outputURL {
                print("📹 Calling onRecordingFinished with url: \(url)")
                self.onRecordingFinished?(url)
            } else {
                print("❌ outputURL is nil")
            }
            self.dismiss(animated: true)
        }
    }
}
