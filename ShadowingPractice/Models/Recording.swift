import Foundation
import AVFoundation

struct Recording: Identifiable, Codable {
    let id: UUID
    let url: URL
    let createdAt: Date
    private(set) var duration: TimeInterval
    var transcription: String?
    var isTranscribing: Bool = false
    
    init(url: URL, createdAt: Date, duration: TimeInterval? = nil, transcription: String? = nil) {
        self.id = UUID()
        self.url = url
        self.createdAt = createdAt
        self.transcription = transcription
        
        // Calculate duration if not provided
        if let duration = duration {
            self.duration = duration
        } else {
            self.duration = Recording.calculateDuration(from: url)
        }
    }
    
    var title: String {
        // Use transcription's first few words if available
        if let transcription = transcription, !transcription.isEmpty {
            let words = transcription.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .prefix(5)
                .joined(separator: " ")
            
            if !words.isEmpty {
                return words.count > 30 ? String(words.prefix(30)) + "..." : words
            }
        }
        
        // Otherwise use filename without extension
        return url.deletingPathExtension().lastPathComponent
    }
    
    var fileName: String {
        url.lastPathComponent
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: createdAt)
    }
    
    private static func calculateDuration(from url: URL) -> TimeInterval {
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            return audioPlayer.duration
        } catch {
            print("Failed to calculate duration for \(url.lastPathComponent): \(error)")
            return 0
        }
    }
    
    mutating func updateDuration() {
        self.duration = Recording.calculateDuration(from: url)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, url, createdAt, duration, transcription
    }
}

extension Recording {
    static func loadFromDisk() -> [Recording] {
        var recordings: [Recording] = []
        let fileManager = FileManager.default
        let documentsDirectory = getDocumentsDirectory()
        
        do {
            let urls = try fileManager.contentsOfDirectory(at: documentsDirectory,
                                                          includingPropertiesForKeys: [.creationDateKey],
                                                          options: .skipsHiddenFiles)
            
            for url in urls {
                if url.pathExtension == "m4a" {
                    let creationDate = try url.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date()
                    
                    // Check if transcription exists
                    let transcriptionURL = url.deletingPathExtension().appendingPathExtension("txt")
                    var transcription: String? = nil
                    if fileManager.fileExists(atPath: transcriptionURL.path) {
                        transcription = try? String(contentsOf: transcriptionURL, encoding: .utf8)
                    }
                    
                    let recording = Recording(url: url, createdAt: creationDate, transcription: transcription)
                    recordings.append(recording)
                }
            }
            
            recordings.sort(by: { $0.createdAt > $1.createdAt })
        } catch {
            print("Failed to load recordings: \(error.localizedDescription)")
        }
        
        return recordings
    }
    
    func saveTranscription(_ text: String) throws {
        let transcriptionURL = url.deletingPathExtension().appendingPathExtension("txt")
        try text.write(to: transcriptionURL, atomically: true, encoding: .utf8)
    }
    
    func deleteFromDisk() throws {
        let fileManager = FileManager.default
        
        // Delete audio file
        try fileManager.removeItem(at: url)
        
        // Delete transcription file if exists
        let transcriptionURL = url.deletingPathExtension().appendingPathExtension("txt")
        if fileManager.fileExists(atPath: transcriptionURL.path) {
            try fileManager.removeItem(at: transcriptionURL)
        }
    }
    
    private static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}