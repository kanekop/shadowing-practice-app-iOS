import Foundation

struct PracticeSession: Identifiable, Codable {
    let id: UUID
    let practiceType: PracticeType
    let originalText: String
    let userText: String
    let score: Double
    let wordErrors: [WordError]
    let createdAt: Date
    var duration: TimeInterval?
    var audioFileURL: URL?
    
    // Additional properties for comprehensive analysis
    let totalWords: Int
    let correctWords: Int
    let wordErrorRate: Double
    
    init(
        practiceType: PracticeType,
        originalText: String,
        userText: String,
        score: Double,
        wordErrors: [WordError],
        totalWords: Int,
        correctWords: Int,
        wordErrorRate: Double,
        duration: TimeInterval? = nil,
        audioFileURL: URL? = nil
    ) {
        self.id = UUID()
        self.practiceType = practiceType
        self.originalText = originalText
        self.userText = userText
        self.score = score
        self.wordErrors = wordErrors
        self.createdAt = Date()
        self.totalWords = totalWords
        self.correctWords = correctWords
        self.wordErrorRate = wordErrorRate
        self.duration = duration
        self.audioFileURL = audioFileURL
    }
    
    enum PracticeType: String, Codable, CaseIterable {
        case reading = "音読"
        case shadowing = "シャドウィング"
        
        var systemImageName: String {
            switch self {
            case .reading:
                return "book.fill"
            case .shadowing:
                return "headphones"
            }
        }
        
        var color: String {
            switch self {
            case .reading:
                return "blue"
            case .shadowing:
                return "purple"
            }
        }
    }
    
    struct WordError: Codable, Identifiable {
        let id = UUID()
        let originalWord: String?
        let userWord: String?
        let errorType: ErrorType
        let position: Int
        
        enum ErrorType: String, Codable {
            case substitution = "置換"
            case deletion = "削除"
            case insertion = "挿入"
            
            var systemImageName: String {
                switch self {
                case .substitution:
                    return "arrow.left.arrow.right.circle.fill"
                case .deletion:
                    return "minus.circle.fill"
                case .insertion:
                    return "plus.circle.fill"
                }
            }
            
            var color: String {
                switch self {
                case .substitution:
                    return "orange"
                case .deletion:
                    return "red"
                case .insertion:
                    return "blue"
                }
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case originalWord, userWord, errorType, position
        }
    }
}

// MARK: - Computed Properties

extension PracticeSession {
    var formattedScore: String {
        return String(format: "%.0f%%", score)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: createdAt)
    }
    
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var errorSummary: String {
        let substitutions = wordErrors.filter { $0.errorType == .substitution }.count
        let deletions = wordErrors.filter { $0.errorType == .deletion }.count
        let insertions = wordErrors.filter { $0.errorType == .insertion }.count
        
        var summary: [String] = []
        if substitutions > 0 {
            summary.append("置換: \(substitutions)")
        }
        if deletions > 0 {
            summary.append("削除: \(deletions)")
        }
        if insertions > 0 {
            summary.append("挿入: \(insertions)")
        }
        
        return summary.isEmpty ? "エラーなし" : summary.joined(separator: ", ")
    }
    
    var scoreLevel: ScoreLevel {
        switch score {
        case 90...100:
            return .excellent
        case 70..<90:
            return .good
        case 50..<70:
            return .fair
        default:
            return .needsImprovement
        }
    }
    
    enum ScoreLevel {
        case excellent
        case good
        case fair
        case needsImprovement
        
        var title: String {
            switch self {
            case .excellent:
                return "素晴らしい"
            case .good:
                return "良い"
            case .fair:
                return "まあまあ"
            case .needsImprovement:
                return "要改善"
            }
        }
        
        var color: String {
            switch self {
            case .excellent:
                return "green"
            case .good:
                return "blue"
            case .fair:
                return "orange"
            case .needsImprovement:
                return "red"
            }
        }
    }
}

// MARK: - Persistence

extension PracticeSession {
    static func save(_ sessions: [PracticeSession]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(sessions)
        
        let url = getDocumentsDirectory().appendingPathComponent("practice_sessions.json")
        try data.write(to: url)
    }
    
    static func load() throws -> [PracticeSession] {
        let url = getDocumentsDirectory().appendingPathComponent("practice_sessions.json")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([PracticeSession].self, from: data)
    }
    
    private static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - Factory Method

extension PracticeSession {
    static func create(
        from comparisonResult: TextComparisonService.ComparisonResult,
        practiceType: PracticeType,
        duration: TimeInterval? = nil,
        audioFileURL: URL? = nil
    ) -> PracticeSession {
        let wordErrors = comparisonResult.wordAnalysis.compactMap { analysis -> WordError? in
            switch analysis.status {
            case .correct:
                return nil
            case .substitution:
                return WordError(
                    originalWord: analysis.originalWord,
                    userWord: analysis.recognizedWord,
                    errorType: .substitution,
                    position: analysis.position
                )
            case .deletion:
                return WordError(
                    originalWord: analysis.originalWord,
                    userWord: nil,
                    errorType: .deletion,
                    position: analysis.position
                )
            case .insertion:
                return WordError(
                    originalWord: nil,
                    userWord: analysis.recognizedWord,
                    errorType: .insertion,
                    position: analysis.position
                )
            }
        }
        
        return PracticeSession(
            practiceType: practiceType,
            originalText: comparisonResult.originalText,
            userText: comparisonResult.recognizedText,
            score: comparisonResult.accuracy,
            wordErrors: wordErrors,
            totalWords: comparisonResult.totalWords,
            correctWords: comparisonResult.correctWords,
            wordErrorRate: comparisonResult.wordErrorRate,
            duration: duration,
            audioFileURL: audioFileURL
        )
    }
}