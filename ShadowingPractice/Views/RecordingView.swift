import SwiftUI
import AVFoundation
import Combine

struct RecordingView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var isPulsing = false
    @State private var selectedRecording: Recording?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playingRecordingId: UUID?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                recordingSection
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                recordingsList
            }
            .navigationTitle("録音")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
    
    private var recordingSection: some View {
        VStack(spacing: 30) {
            Text(timeString(from: audioRecorder.recordingTime))
                .font(.system(size: 48, weight: .thin, design: .monospaced))
                .foregroundColor(.primary)
            
            recordButton
            
            if audioRecorder.isTranscribing {
                VStack(spacing: 8) {
                    ProgressView(value: audioRecorder.transcriptionProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text("文字起こし処理中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
            }
        }
        .padding(.horizontal)
    }
    
    private var recordButton: some View {
        Button(action: toggleRecording) {
            ZStack {
                Circle()
                    .fill(audioRecorder.isRecording ? Color.red : Color.red.opacity(0.8))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isPulsing ? 1.1 : 1.0)
                    .shadow(color: audioRecorder.isRecording ? Color.red.opacity(0.6) : Color.clear,
                            radius: isPulsing ? 15 : 0)
                
                Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
        }
        .onReceive(audioRecorder.$isRecording) { isRecording in
            if isRecording {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPulsing = false
                }
            }
        }
    }
    
    private var recordingsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if audioRecorder.recordings.isEmpty {
                    emptyStateView
                } else {
                    ForEach(audioRecorder.recordings) { recording in
                        RecordingRow(
                            recording: recording,
                            isPlaying: playingRecordingId == recording.id,
                            onPlay: { playRecording(recording) },
                            onDelete: { deleteRecording(recording) },
                            onRetranscribe: { audioRecorder.retranscribeRecording(recording) }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("録音がありません")
                .font(.title3)
                .foregroundColor(.gray)
            
            Text("上のボタンをタップして録音を開始")
                .font(.footnote)
                .foregroundColor(.gray.opacity(0.8))
        }
        .padding(.top, 60)
    }
    
    private func toggleRecording() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
        } else {
            do {
                try audioRecorder.startRecording()
            } catch {
                print("Failed to start recording: \(error)")
            }
        }
    }
    
    private func playRecording(_ recording: Recording) {
        if playingRecordingId == recording.id {
            audioPlayer?.stop()
            playingRecordingId = nil
        } else {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: recording.url)
                audioPlayer?.delegate = makeCoordinator()
                audioPlayer?.play()
                playingRecordingId = recording.id
            } catch {
                print("Failed to play recording: \(error)")
            }
        }
    }
    
    private func deleteRecording(_ recording: Recording) {
        if playingRecordingId == recording.id {
            audioPlayer?.stop()
            playingRecordingId = nil
        }
        audioRecorder.deleteRecording(recording)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVAudioPlayerDelegate {
        let parent: RecordingView
        
        init(_ parent: RecordingView) {
            self.parent = parent
        }
        
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            parent.playingRecordingId = nil
        }
    }
}

struct RecordingRow: View {
    let recording: Recording
    let isPlaying: Bool
    let onPlay: () -> Void
    let onDelete: () -> Void
    let onRetranscribe: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(dateString(from: recording.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
                
                Button(action: onRetranscribe) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                }
                .opacity(recording.isTranscribing ? 0.5 : 1.0)
                .disabled(recording.isTranscribing)
                
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.red)
                }
            }
            
            if recording.isTranscribing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("文字起こし中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let transcription = recording.transcription {
                VStack(alignment: .leading, spacing: 4) {
                    Text("文字起こし:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(transcription)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingView()
    }
}