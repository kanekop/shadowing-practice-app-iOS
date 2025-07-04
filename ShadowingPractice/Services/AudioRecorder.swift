import AVFoundation
import SwiftUI
import Combine

class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession!
    private var timer: Timer?
    private let speechRecognizer = SpeechRecognizer()
    private var stopRecordingCompletion: ((URL?) -> Void)?
    
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var currentRecordingURL: URL?
    @Published var recordings: [Recording] = []
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Double = 0.0
    
    override init() {
        super.init()
        setupRecordingSession()
        loadRecordings()
    }
    
    private func setupRecordingSession() {
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            
            AVAudioApplication.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if !allowed {
                        print("Recording permission denied")
                    }
                }
            }
        } catch {
            print("Failed to set up recording session: \(error.localizedDescription)")
        }
    }
    
    func startRecording() throws {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("\(UUID().uuidString).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            currentRecordingURL = audioFilename
            isRecording = true
            recordingTime = 0
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateRecordingTime()
            }
        } catch {
            throw RecordingError.failedToStartRecording(error.localizedDescription)
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void = { _ in }) {
        stopRecordingCompletion = completion
        audioRecorder?.stop()
        isRecording = false
        
        timer?.invalidate()
        timer = nil
    }
    
    private func updateRecordingTime() {
        if let recorder = audioRecorder {
            recordingTime = recorder.currentTime
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func loadRecordings() {
        recordings = Recording.loadFromDisk()
    }
    
    func deleteRecording(_ recording: Recording) {
        do {
            try recording.deleteFromDisk()
            loadRecordings()
        } catch {
            print("Failed to delete recording: \(error.localizedDescription)")
        }
    }
    
    private func transcribeRecording(at url: URL) {
        isTranscribing = true
        transcriptionProgress = 0.0
        
        // Update UI to show transcription in progress
        DispatchQueue.main.async { [weak self] in
            if let index = self?.recordings.firstIndex(where: { $0.url == url }) {
                self?.recordings[index].isTranscribing = true
            }
        }
        
        // Monitor transcription progress
        let progressObserver = speechRecognizer.$recognitionProgress.sink { [weak self] progress in
            DispatchQueue.main.async {
                self?.transcriptionProgress = progress
            }
        }
        
        speechRecognizer.recognizeFromFile(url: url) { [weak self] result in
            DispatchQueue.main.async {
                self?.isTranscribing = false
                self?.transcriptionProgress = 0.0
                
                switch result {
                case .success(let transcription):
                    // Update recording with transcription
                    if let index = self?.recordings.firstIndex(where: { $0.url == url }) {
                        do {
                            try self?.recordings[index].saveTranscription(transcription)
                            self?.recordings[index].transcription = transcription
                            self?.recordings[index].isTranscribing = false
                            print("Transcription saved successfully")
                        } catch {
                            print("Failed to save transcription: \(error.localizedDescription)")
                        }
                    }
                    
                case .failure(let error):
                    print("Transcription failed: \(error.localizedDescription)")
                    
                    // Update recording to show transcription failed
                    if let index = self?.recordings.firstIndex(where: { $0.url == url }) {
                        self?.recordings[index].isTranscribing = false
                    }
                }
                
                // Cancel progress observer
                progressObserver.cancel()
            }
        }
    }
    
    func retranscribeRecording(_ recording: Recording) {
        transcribeRecording(at: recording.url)
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let recordingURL = flag ? currentRecordingURL : nil
        
        if !flag {
            print("Recording failed")
            currentRecordingURL = nil
        } else {
            // Start transcription after successful recording
            if let url = currentRecordingURL {
                transcribeRecording(at: url)
            }
            loadRecordings()
        }
        
        // Call completion handler with the recording URL
        stopRecordingCompletion?(recordingURL)
        stopRecordingCompletion = nil
        audioRecorder = nil
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording encode error: \(error.localizedDescription)")
        }
    }
}

enum RecordingError: LocalizedError {
    case failedToStartRecording(String)
    case recordingPermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .failedToStartRecording(let reason):
            return "Failed to start recording: \(reason)"
        case .recordingPermissionDenied:
            return "Recording permission was denied"
        }
    }
}

