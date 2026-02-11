import Foundation

// MARK: - Language Model Protocol

/// Scoring protocol for candidate reranking.
/// Implementations range from a simple unigram stub to full N-gram models
/// and eventually Foundation Models integration.
protocol LanguageModelProtocol {
    /// Score a candidate word given surrounding context.
    /// Returns a probability in 0...1 (higher = more likely in context).
    func score(word: String, context: String) -> Float
}

// MARK: - Unigram Language Model

/// Basic unigram model backed by word frequencies.
/// Used as the initial stub; returns a frequency-based probability
/// independent of context. Future N-gram and Foundation Models
/// integrations will replace this.
final class UnigramLanguageModel: LanguageModelProtocol {

    /// Normalized log-frequency for each word.
    private var frequencies: [String: Float] = [:]

    /// Default score for unknown words — low but nonzero.
    private let unknownScore: Float = 0.01

    init() {}

    /// Load word frequencies from a dictionary of raw counts.
    /// The counts are normalized to 0...1 using log-frequency scaling.
    func loadFrequencies(_ rawCounts: [String: Int]) {
        guard !rawCounts.isEmpty else { return }
        let maxCount = Float(rawCounts.values.max() ?? 1)
        let logMax = logf(maxCount + 1)
        for (word, count) in rawCounts {
            let logFreq = logf(Float(count) + 1)
            frequencies[word.lowercased()] = logFreq / logMax
        }
    }

    /// Load from a compact binary format.
    /// Format: [4 bytes wordCount] then for each word:
    ///   [2 bytes wordLen] [N bytes UTF-8] [4 bytes Float frequency]
    func loadFromBinary(at url: URL) throws {
        let data = try Data(contentsOf: url)
        var offset = 0

        let count = readInt32(data, &offset)
        frequencies.reserveCapacity(Int(count))

        for _ in 0..<count {
            let len = Int(readUInt16(data, &offset))
            let wordBytes = Array(data[offset..<(offset + len)])
            offset += len
            let freq = readFloat(data, &offset)
            if let word = String(bytes: wordBytes, encoding: .utf8) {
                frequencies[word] = freq
            }
        }
    }

    /// Save to compact binary format.
    func saveToBinary(at url: URL) throws {
        var data = Data()
        appendInt32(&data, Int32(frequencies.count))
        for (word, freq) in frequencies {
            let utf8 = Array(word.utf8)
            appendUInt16(&data, UInt16(utf8.count))
            data.append(contentsOf: utf8)
            appendFloat(&data, freq)
        }
        try data.write(to: url)
    }

    func score(word: String, context: String) -> Float {
        return frequencies[word.lowercased()] ?? unknownScore
    }

    // MARK: - Binary helpers

    private func readInt32(_ data: Data, _ offset: inout Int) -> Int32 {
        let value = data[offset..<(offset + 4)].withUnsafeBytes { $0.load(as: Int32.self) }
        offset += 4
        return Int32(littleEndian: value)
    }

    private func readUInt16(_ data: Data, _ offset: inout Int) -> UInt16 {
        let value = data[offset..<(offset + 2)].withUnsafeBytes { $0.load(as: UInt16.self) }
        offset += 2
        return UInt16(littleEndian: value)
    }

    private func readFloat(_ data: Data, _ offset: inout Int) -> Float {
        let value = data[offset..<(offset + 4)].withUnsafeBytes { $0.load(as: UInt32.self) }
        offset += 4
        return Float(bitPattern: UInt32(littleEndian: value))
    }

    private func appendInt32(_ data: inout Data, _ value: Int32) {
        var v = value.littleEndian
        withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
    }

    private func appendUInt16(_ data: inout Data, _ value: UInt16) {
        var v = value.littleEndian
        withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
    }

    private func appendFloat(_ data: inout Data, _ value: Float) {
        var v = value.bitPattern.littleEndian
        withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
    }
}

// MARK: - Placeholder Equal-Probability Model

/// Returns equal probability (0.5) for every word, effectively disabling
/// language model influence. Used when no frequency data is available.
struct PlaceholderLanguageModel: LanguageModelProtocol {
    func score(word: String, context: String) -> Float {
        return 0.5
    }
}
