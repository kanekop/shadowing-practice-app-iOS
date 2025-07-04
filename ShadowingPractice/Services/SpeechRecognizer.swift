import Speech
import SwiftUI
import AVFoundation

class SpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isRecognizing = false
    @Published var recognizedText = ""
    @Published var recognitionProgress: Double = 0.0
    @Published var currentLanguage: RecognitionLanguage = .english
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    enum RecognitionLanguage: String, CaseIterable {
        case japanese = "ja-JP"
        case english = "en-US"
        
        var displayName: String {
            switch self {
            case .japanese:
                return "日本語"
            case .english:
                return "English"
            }
        }
    }
    
    override init() {
        // Always use English locale
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        currentLanguage = .english
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                self?.authorizationStatus = authStatus
                if authStatus != .authorized {
                    print("Speech recognition authorization denied")
                }
            }
        }
    }
    
    func setLanguage(_ language: RecognitionLanguage) {
        // Language switching is disabled - always uses English
        return
    }
    
    func recognizeFromFile(url: URL, completion: @escaping (Result<String, SpeechRecognitionError>) -> Void) {
        guard authorizationStatus == .authorized else {
            completion(.failure(.notAuthorized))
            return
        }
        
        // Always use English locale
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            completion(.failure(.recognizerNotAvailable))
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        
        recognitionProgress = 0.0
        recognizedText = ""
        
        recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.recognitionProgress = 0.0
                    completion(.failure(.recognitionFailed(error.localizedDescription)))
                }
                return
            }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.recognizedText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self.recognitionProgress = 1.0
                        completion(.success(self.recognizedText))
                    } else {
                        let segments = result.bestTranscription.segments
                        if !segments.isEmpty {
                            let lastSegment = segments.last!
                            let progress = lastSegment.timestamp + lastSegment.duration
                            self.recognitionProgress = min(progress / 60.0, 0.9)
                        }
                    }
                }
            }
        }
    }
    
    func startRealtimeRecognition(completion: @escaping (Result<String, SpeechRecognitionError>) -> Void) throws {
        guard authorizationStatus == .authorized else {
            completion(.failure(.notAuthorized))
            return
        }
        
        // Always use English locale
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            completion(.failure(.recognizerNotAvailable))
            return
        }
        
        stopRealtimeRecognition()
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.nilRecognitionRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        
        recognizedText = ""
        isRecognizing = true
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                DispatchQueue.main.async {
                    self.recognizedText = result.bestTranscription.formattedString
                    isFinal = result.isFinal
                }
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self.isRecognizing = false
                    
                    if let error = error {
                        completion(.failure(.recognitionFailed(error.localizedDescription)))
                    } else {
                        completion(.success(self.recognizedText))
                    }
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    func stopRealtimeRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
            
            audioEngine.inputNode.removeTap(onBus: 0)
            
            recognitionRequest = nil
            recognitionTask = nil
            isRecognizing = false
        }
    }
}

enum SpeechRecognitionError: LocalizedError {
    case notAuthorized
    case recognizerNotAvailable
    case nilRecognitionRequest
    case recognitionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not authorized"
        case .recognizerNotAvailable:
            return "Speech recognizer is not available"
        case .nilRecognitionRequest:
            return "Recognition request could not be created"
        case .recognitionFailed(let reason):
            return "Recognition failed: \(reason)"
        }
    }
}