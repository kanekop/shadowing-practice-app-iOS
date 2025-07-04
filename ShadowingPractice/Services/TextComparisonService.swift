import Foundation

class TextComparisonService {
    
    // MARK: - Models
    
    struct ComparisonResult {
        let originalText: String
        let recognizedText: String
        let wordErrorRate: Double
        let accuracy: Double
        let wordAnalysis: [WordAnalysis]
        let totalWords: Int
        let correctWords: Int
        let substitutions: Int
        let deletions: Int
        let insertions: Int
    }
    
    struct WordAnalysis {
        let originalWord: String?
        let recognizedWord: String?
        let position: Int
        let status: WordStatus
        
        enum WordStatus {
            case correct
            case substitution
            case deletion
            case insertion
        }
    }
    
    // MARK: - Public Methods
    
    func compare(original: String, recognized: String) -> ComparisonResult {
        let originalWords = preprocessText(original)
        let recognizedWords = preprocessText(recognized)
        
        // Calculate Levenshtein distance and track operations
        let (distance, operations) = levenshteinDistance(originalWords, recognizedWords)
        
        // Calculate WER (Word Error Rate)
        let wer = originalWords.isEmpty ? 0.0 : Double(distance) / Double(originalWords.count)
        
        // Calculate accuracy (inverse of WER, capped at 0-100%)
        let accuracy = max(0, min(100, (1.0 - wer) * 100))
        
        // Analyze word-level differences
        let wordAnalysis = analyzeWordDifferences(originalWords, recognizedWords, operations)
        
        // Count different types of errors
        let substitutions = wordAnalysis.filter { $0.status == .substitution }.count
        let deletions = wordAnalysis.filter { $0.status == .deletion }.count
        let insertions = wordAnalysis.filter { $0.status == .insertion }.count
        let correctWords = wordAnalysis.filter { $0.status == .correct }.count
        
        return ComparisonResult(
            originalText: original,
            recognizedText: recognized,
            wordErrorRate: wer,
            accuracy: accuracy,
            wordAnalysis: wordAnalysis,
            totalWords: originalWords.count,
            correctWords: correctWords,
            substitutions: substitutions,
            deletions: deletions,
            insertions: insertions
        )
    }
    
    func getDetailedFeedback(for result: ComparisonResult) -> String {
        var feedback = ""
        
        if result.accuracy >= 90 {
            feedback = "Excellent! Your pronunciation is very accurate."
        } else if result.accuracy >= 70 {
            feedback = "Good job! You're doing well, but there's room for improvement."
        } else if result.accuracy >= 50 {
            feedback = "Keep practicing! Focus on clear pronunciation of each word."
        } else {
            feedback = "Let's work on pronunciation. Try speaking more slowly and clearly."
        }
        
        if result.substitutions > 0 {
            feedback += "\n\nYou mispronounced \(result.substitutions) word\(result.substitutions > 1 ? "s" : "")."
        }
        
        if result.deletions > 0 {
            feedback += "\n\nYou missed \(result.deletions) word\(result.deletions > 1 ? "s" : "")."
        }
        
        if result.insertions > 0 {
            feedback += "\n\nYou added \(result.insertions) extra word\(result.insertions > 1 ? "s" : "")."
        }
        
        return feedback
    }
    
    func getMistakeHighlights(for result: ComparisonResult) -> [(word: String, status: WordAnalysis.WordStatus)] {
        return result.wordAnalysis.compactMap { analysis in
            switch analysis.status {
            case .correct:
                return nil
            case .substitution:
                return (analysis.recognizedWord ?? "", analysis.status)
            case .deletion:
                return (analysis.originalWord ?? "", analysis.status)
            case .insertion:
                return (analysis.recognizedWord ?? "", analysis.status)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func preprocessText(_ text: String) -> [String] {
        return text
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
    
    private enum EditOperation {
        case match
        case substitute
        case delete
        case insert
    }
    
    private func levenshteinDistance(_ source: [String], _ target: [String]) -> (distance: Int, operations: [[EditOperation]]) {
        let sourceCount = source.count
        let targetCount = target.count
        
        // Create matrix for distances
        var distances = Array(repeating: Array(repeating: 0, count: targetCount + 1), count: sourceCount + 1)
        
        // Create matrix for tracking operations
        var operations = Array(repeating: Array(repeating: EditOperation.match, count: targetCount + 1), count: sourceCount + 1)
        
        // Initialize first row and column
        for i in 0...sourceCount {
            distances[i][0] = i
            if i > 0 {
                operations[i][0] = .delete
            }
        }
        
        for j in 0...targetCount {
            distances[0][j] = j
            if j > 0 {
                operations[0][j] = .insert
            }
        }
        
        // Fill in the matrix
        for i in 1...sourceCount {
            for j in 1...targetCount {
                if source[i-1] == target[j-1] {
                    distances[i][j] = distances[i-1][j-1]
                    operations[i][j] = .match
                } else {
                    let substitutionCost = distances[i-1][j-1] + 1
                    let deletionCost = distances[i-1][j] + 1
                    let insertionCost = distances[i][j-1] + 1
                    
                    if substitutionCost <= deletionCost && substitutionCost <= insertionCost {
                        distances[i][j] = substitutionCost
                        operations[i][j] = .substitute
                    } else if deletionCost <= insertionCost {
                        distances[i][j] = deletionCost
                        operations[i][j] = .delete
                    } else {
                        distances[i][j] = insertionCost
                        operations[i][j] = .insert
                    }
                }
            }
        }
        
        return (distances[sourceCount][targetCount], operations)
    }
    
    private func analyzeWordDifferences(_ original: [String], _ recognized: [String], _ operations: [[EditOperation]]) -> [WordAnalysis] {
        var analysis: [WordAnalysis] = []
        var i = original.count
        var j = recognized.count
        
        // Backtrack through the operations matrix to reconstruct the alignment
        while i > 0 || j > 0 {
            let operation = operations[i][j]
            
            switch operation {
            case .match:
                analysis.append(WordAnalysis(
                    originalWord: original[i-1],
                    recognizedWord: recognized[j-1],
                    position: i-1,
                    status: .correct
                ))
                i -= 1
                j -= 1
                
            case .substitute:
                analysis.append(WordAnalysis(
                    originalWord: original[i-1],
                    recognizedWord: j > 0 ? recognized[j-1] : nil,
                    position: i-1,
                    status: .substitution
                ))
                i -= 1
                j -= 1
                
            case .delete:
                analysis.append(WordAnalysis(
                    originalWord: original[i-1],
                    recognizedWord: nil,
                    position: i-1,
                    status: .deletion
                ))
                i -= 1
                
            case .insert:
                analysis.append(WordAnalysis(
                    originalWord: nil,
                    recognizedWord: recognized[j-1],
                    position: i,
                    status: .insertion
                ))
                j -= 1
            }
        }
        
        return analysis.reversed()
    }
}

// MARK: - Convenience Extensions

extension TextComparisonService.ComparisonResult {
    var formattedAccuracy: String {
        return String(format: "%.1f%%", accuracy)
    }
    
    var formattedWER: String {
        return String(format: "%.2f", wordErrorRate)
    }
    
    var summary: String {
        return "Accuracy: \(formattedAccuracy) | Correct: \(correctWords)/\(totalWords) words"
    }
}