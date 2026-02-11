import Foundation

// MARK: - DAWG Node

/// A single node in the Directed Acyclic Word Graph.
/// Uses compact arrays with integer indices instead of object pointers
/// for cache-friendly, memory-efficient traversal (~5MB for 100K words).
struct DAWGNode {
    /// Sorted parallel arrays for binary-search edge lookup.
    var edgeLabels: [Character]
    var edgeTargets: [Int]
    var isTerminal: Bool
    var wordId: Int?

    init(isTerminal: Bool = false, wordId: Int? = nil) {
        self.edgeLabels = []
        self.edgeTargets = []
        self.isTerminal = isTerminal
        self.wordId = wordId
    }

    /// O(log n) edge lookup via binary search on sorted labels.
    func target(for label: Character) -> Int? {
        var lo = 0
        var hi = edgeLabels.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if edgeLabels[mid] == label {
                return edgeTargets[mid]
            } else if edgeLabels[mid] < label {
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        return nil
    }

    mutating func addEdge(label: Character, target: Int) {
        // Insert in sorted order for binary search
        let index = edgeLabels.firstIndex(where: { $0 >= label }) ?? edgeLabels.count
        if index < edgeLabels.count && edgeLabels[index] == label {
            edgeTargets[index] = target
        } else {
            edgeLabels.insert(label, at: index)
            edgeTargets.insert(target, at: index)
        }
    }
}

// MARK: - DAWG Dictionary

/// Memory-efficient dictionary using a Directed Acyclic Word Graph.
/// Shares common suffixes across words, reducing the 100K-word dictionary
/// from ~3MB of raw strings down to ~5MB of indexed nodes + word list.
final class DAWGDictionary {
    private(set) var nodes: [DAWGNode]
    private(set) var words: [String]

    /// Root is always node 0.
    private let rootIndex = 0

    init(nodes: [DAWGNode] = [], words: [String] = []) {
        self.nodes = nodes
        self.words = words
    }

    // MARK: - Queries

    func contains(_ word: String) -> Bool {
        var current = rootIndex
        for ch in word.lowercased() {
            guard let next = nodes[current].target(for: ch) else { return false }
            current = next
        }
        return nodes[current].isTerminal
    }

    /// Returns all words that share the given prefix (up to `limit`).
    func search(prefix: String, limit: Int = 20) -> [String] {
        var current = rootIndex
        for ch in prefix.lowercased() {
            guard let next = nodes[current].target(for: ch) else { return [] }
            current = next
        }
        var results: [String] = []
        collectWords(from: current, prefix: prefix.lowercased(), results: &results, limit: limit)
        return results
    }

    /// Returns every word stored in the DAWG. Useful for template generation.
    func allWords() -> [String] {
        return words
    }

    /// Look up the word ID (index into `words`). Returns nil if not found.
    func wordId(for word: String) -> Int? {
        var current = rootIndex
        for ch in word.lowercased() {
            guard let next = nodes[current].target(for: ch) else { return nil }
            current = next
        }
        return nodes[current].wordId
    }

    /// Release internal caches when under memory pressure.
    func releaseCache() {
        // Future: if we add any caches (e.g. frequency tables), clear them here.
    }

    // MARK: - DFS collection

    private func collectWords(from nodeIndex: Int, prefix: String, results: inout [String], limit: Int) {
        if results.count >= limit { return }
        let node = nodes[nodeIndex]
        if node.isTerminal {
            results.append(prefix)
        }
        for i in 0..<node.edgeLabels.count {
            if results.count >= limit { return }
            let nextPrefix = prefix + String(node.edgeLabels[i])
            collectWords(from: node.edgeTargets[i], prefix: nextPrefix, results: &results, limit: limit)
        }
    }

    // MARK: - Binary Serialization

    /// Binary format (little-endian):
    ///   [4 bytes] node count
    ///   [4 bytes] word count
    ///   For each node:
    ///     [1 byte]  isTerminal
    ///     [4 bytes] wordId (-1 if nil)
    ///     [2 bytes] edge count
    ///     For each edge:
    ///       [2 bytes] UTF-16 character
    ///       [4 bytes] target index
    ///   For each word:
    ///     [2 bytes] length
    ///     [N bytes] UTF-8 data
    func save(to url: URL) throws {
        var data = Data()

        // Header
        appendInt32(&data, Int32(nodes.count))
        appendInt32(&data, Int32(words.count))

        // Nodes
        for node in nodes {
            data.append(node.isTerminal ? 1 : 0)
            appendInt32(&data, Int32(node.wordId ?? -1))
            appendUInt16(&data, UInt16(node.edgeLabels.count))
            for i in 0..<node.edgeLabels.count {
                let scalar = node.edgeLabels[i].unicodeScalars.first!
                appendUInt16(&data, UInt16(scalar.value))
                appendInt32(&data, Int32(node.edgeTargets[i]))
            }
        }

        // Words
        for word in words {
            let utf8 = Array(word.utf8)
            appendUInt16(&data, UInt16(utf8.count))
            data.append(contentsOf: utf8)
        }

        try data.write(to: url)
    }

    static func load(from url: URL) throws -> DAWGDictionary {
        let data = try Data(contentsOf: url)
        var offset = 0

        let nodeCount = Int(readInt32(data, &offset))
        let wordCount = Int(readInt32(data, &offset))

        var nodes: [DAWGNode] = []
        nodes.reserveCapacity(nodeCount)

        for _ in 0..<nodeCount {
            let isTerminal = data[offset] == 1
            offset += 1
            let rawWordId = Int(readInt32(data, &offset))
            let wordId: Int? = rawWordId >= 0 ? rawWordId : nil
            let edgeCount = Int(readUInt16(data, &offset))

            var labels: [Character] = []
            var targets: [Int] = []
            labels.reserveCapacity(edgeCount)
            targets.reserveCapacity(edgeCount)

            for _ in 0..<edgeCount {
                let charVal = readUInt16(data, &offset)
                labels.append(Character(UnicodeScalar(UInt32(charVal))!))
                targets.append(Int(readInt32(data, &offset)))
            }

            var node = DAWGNode(isTerminal: isTerminal, wordId: wordId)
            node.edgeLabels = labels
            node.edgeTargets = targets
            nodes.append(node)
        }

        var words: [String] = []
        words.reserveCapacity(wordCount)

        for _ in 0..<wordCount {
            let length = Int(readUInt16(data, &offset))
            let utf8 = Array(data[offset..<(offset + length)])
            offset += length
            words.append(String(bytes: utf8, encoding: .utf8) ?? "")
        }

        return DAWGDictionary(nodes: nodes, words: words)
    }

    /// Convenience: load from a named resource in the main bundle.
    static func load(fromResource name: String) throws -> DAWGDictionary {
        guard let url = Bundle.main.url(forResource: name, withExtension: "dawg") else {
            throw DAWGError.resourceNotFound(name)
        }
        return try load(from: url)
    }

    // MARK: - Build from word list (for offline generation)

    /// Builds a simple trie-based DAWG from a sorted word list.
    /// For production, use DAWGBuilder which produces a minimal (suffix-shared) DAWG.
    static func buildFromWordList(_ words: [String]) -> DAWGDictionary {
        let builder = DAWGBuilder()
        return builder.build(from: words)
    }

    // MARK: - Binary helpers

    private func appendInt32(_ data: inout Data, _ value: Int32) {
        var v = value.littleEndian
        withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
    }

    private func appendUInt16(_ data: inout Data, _ value: UInt16) {
        var v = value.littleEndian
        withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
    }

    private static func readInt32(_ data: Data, _ offset: inout Int) -> Int32 {
        let value = data[offset..<(offset + 4)].withUnsafeBytes { $0.load(as: Int32.self) }
        offset += 4
        return Int32(littleEndian: value)
    }

    private static func readUInt16(_ data: Data, _ offset: inout Int) -> UInt16 {
        let value = data[offset..<(offset + 2)].withUnsafeBytes { $0.load(as: UInt16.self) }
        offset += 2
        return UInt16(littleEndian: value)
    }
}

// MARK: - Errors

enum DAWGError: Error {
    case resourceNotFound(String)
    case corruptedData
}
