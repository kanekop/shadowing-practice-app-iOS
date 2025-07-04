import SwiftUI
import AVFoundation
import Combine

struct PracticeView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var practiceMode: PracticeMode = .reading
    @State private var isRecording = false
    @State private var isPracticing = false
    @State private var showResults = false
    @State private var practiceResult: PracticeResult?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingSample = false
    @State private var recordingTimer: Timer?
    @State private var elapsedTime: TimeInterval = 0
    
    private let textComparisonService = TextComparisonService()
    
    enum PracticeMode: String, CaseIterable {
        case reading = "音読モード"
        case shadowing = "シャドウィングモード"
        
        var description: String {
            switch self {
            case .reading:
                return "テキストを見ながら音読練習"
            case .shadowing:
                return "音声を聞きながらシャドウィング練習"
            }
        }
    }
    
    let sampleText = "The quick brown fox jumps over the lazy dog. This is a sample text for English pronunciation practice. Practice makes perfect, so keep trying your best!"
    
    let sampleAudioURL: URL? = Bundle.main.url(forResource: "sample", withExtension: "mp3")
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Practice Mode Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("練習モード")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Picker("Practice Mode", selection: $practiceMode) {
                        ForEach(PracticeMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text(practiceMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                
                // Sample Text Display
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("お手本テキスト")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if practiceMode == .shadowing && sampleAudioURL != nil {
                            Button(action: toggleSampleAudio) {
                                HStack(spacing: 6) {
                                    Image(systemName: isPlayingSample ? "stop.circle.fill" : "play.circle.fill")
                                    Text(isPlayingSample ? "停止" : "再生")
                                        .font(.subheadline)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Text(sampleText)
                        .font(.body)
                        .lineSpacing(8)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                
                // Recording Controls
                VStack(spacing: 20) {
                    if isPracticing {
                        Text(timeString(from: elapsedTime))
                            .font(.system(size: 36, weight: .thin, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .fill(isPracticing ? Color.red : Color.blue)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: isPracticing ? "stop.fill" : "mic.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                    }
                    .scaleEffect(isPracticing ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isPracticing)
                    
                    Text(isPracticing ? "録音中..." : "録音開始")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Practice Results
                if showResults, let result = practiceResult {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("練習結果")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(result.score)%")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor(for: result.score))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("認識されたテキスト:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(result.recognizedText)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            
                            if let comparisonResult = result.comparisonResult {
                                HStack(spacing: 16) {
                                    Label("\(comparisonResult.correctWords)", systemImage: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    
                                    if comparisonResult.substitutions > 0 {
                                        Label("\(comparisonResult.substitutions)", systemImage: "arrow.left.arrow.right.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                    
                                    if comparisonResult.deletions > 0 {
                                        Label("\(comparisonResult.deletions)", systemImage: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    
                                    if comparisonResult.insertions > 0 {
                                        Label("\(comparisonResult.insertions)", systemImage: "plus.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .font(.caption)
                            }
                        }
                        
                        if !result.feedback.isEmpty {
                            Text(result.feedback)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        
                        Button(action: resetPractice) {
                            Text("もう一度練習")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("シャドウィング練習")
        .navigationBarTitleDisplayMode(.large)
        .onDisappear {
            stopAllAudio()
        }
    }
    
    private func toggleRecording() {
        if isPracticing {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        do {
            try audioRecorder.startRecording()
            isPracticing = true
            showResults = false
            elapsedTime = 0
            
            // Start timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                elapsedTime += 0.1
            }
            
            // If shadowing mode, play sample audio
            if practiceMode == .shadowing {
                playSampleAudio()
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func stopRecording() {
        audioRecorder.stopRecording()
        isPracticing = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Stop sample audio if playing
        if isPlayingSample {
            audioPlayer?.stop()
            isPlayingSample = false
        }
        
        // Analyze the recording
        if let recordingURL = audioRecorder.currentRecordingURL {
            analyzeRecording(url: recordingURL)
        }
    }
    
    private func analyzeRecording(url: URL) {
        speechRecognizer.recognizeFromFile(url: url) { result in
            
            switch result {
            case .success(let recognizedText):
                let comparisonResult = textComparisonService.compare(
                    original: sampleText,
                    recognized: recognizedText
                )
                let feedback = textComparisonService.getDetailedFeedback(for: comparisonResult)
                
                // Create and save practice session
                let practiceSession = PracticeSession.create(
                    from: comparisonResult,
                    practiceType: practiceMode == .reading ? .reading : .shadowing,
                    duration: elapsedTime,
                    audioFileURL: url
                )
                
                savePracticeSession(practiceSession)
                
                DispatchQueue.main.async {
                    practiceResult = PracticeResult(
                        recognizedText: recognizedText,
                        score: Int(comparisonResult.accuracy),
                        feedback: feedback,
                        comparisonResult: comparisonResult
                    )
                    showResults = true
                }
                
            case .failure(let error):
                print("Recognition failed: \(error)")
                DispatchQueue.main.async {
                    practiceResult = PracticeResult(
                        recognizedText: "音声認識に失敗しました",
                        score: 0,
                        feedback: "もう一度お試しください",
                        comparisonResult: nil
                    )
                    showResults = true
                }
            }
        }
    }
    
    
    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 90...100:
            return .green
        case 70..<90:
            return .blue
        case 50..<70:
            return .orange
        default:
            return .red
        }
    }
    
    private func toggleSampleAudio() {
        if isPlayingSample {
            audioPlayer?.stop()
            isPlayingSample = false
        } else {
            playSampleAudio()
        }
    }
    
    private func playSampleAudio() {
        guard let url = sampleAudioURL else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = makeCoordinator()
            audioPlayer?.play()
            isPlayingSample = true
        } catch {
            print("Failed to play sample audio: \(error)")
        }
    }
    
    private func stopAllAudio() {
        audioPlayer?.stop()
        isPlayingSample = false
        if isPracticing {
            stopRecording()
        }
    }
    
    private func resetPractice() {
        showResults = false
        practiceResult = nil
        elapsedTime = 0
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func savePracticeSession(_ session: PracticeSession) {
        do {
            var sessions = (try? PracticeSession.load()) ?? []
            sessions.append(session)
            try PracticeSession.save(sessions)
            print("Practice session saved successfully")
        } catch {
            print("Failed to save practice session: \(error)")
        }
    }
    
    class Coordinator: NSObject, AVAudioPlayerDelegate {
        let parent: PracticeView
        
        init(_ parent: PracticeView) {
            self.parent = parent
        }
        
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            parent.isPlayingSample = false
        }
    }
}

struct PracticeResult {
    let recognizedText: String
    let score: Int
    let feedback: String
    let comparisonResult: TextComparisonService.ComparisonResult?
}

struct PracticeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PracticeView()
        }
    }
}