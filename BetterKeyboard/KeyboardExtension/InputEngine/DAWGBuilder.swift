import Foundation

// MARK: - DAWG Builder

/// Builds a minimal DAWG from a sorted word list.
/// Implements right-language (suffix) compression: nodes that share
/// identical subtrees are merged, dramatically reducing node count.
///
/// Algorithm:
/// 1. Insert words in sorted order into a trie.
/// 2. After inserting each word, check the "unchecked" (rightmost path) nodes
///    from the previous word. If a node's subtree matches one already seen
///    (same children, same terminal status), replace it with the existing copy.
/// 3. This is essentially the incremental construction algorithm from
///    Daciuk et al. (2000) — "Incremental Construction of Minimal Acyclic
///    Finite-State Automata."
final class DAWGBuilder {

    // During construction we use class-based nodes for pointer identity,
    // then flatten to value-type DAWGNode array at the end.
    private final class BuildNode: Hashable {
        var edges: [(Character, BuildNode)] = []
        var isTerminal: Bool = false
        var wordId: Int? = nil

        // Hashable: two nodes are equivalent if they have the same terminal
        // status and the same set of (label, target identity) edges.
        func hash(into hasher: inout Hasher) {
            hasher.combine(isTerminal)
            for (label, target) in edges {
                hasher.combine(label)
                hasher.combine(ObjectIdentifier(target))
            }
        }

        static func == (lhs: BuildNode, rhs: BuildNode) -> Bool {
            guard lhs.isTerminal == rhs.isTerminal,
                  lhs.edges.count == rhs.edges.count else { return false }
            for i in 0..<lhs.edges.count {
                if lhs.edges[i].0 != rhs.edges[i].0 { return false }
                if lhs.edges[i].1 !== rhs.edges[i].1 { return false }
            }
            return true
        }

        func child(for label: Character) -> BuildNode? {
            edges.first(where: { $0.0 == label })?.1
        }

        func setChild(_ label: Character, _ node: BuildNode) {
            if let idx = edges.firstIndex(where: { $0.0 == label }) {
                edges[idx] = (label, node)
            } else {
                edges.append((label, node))
                edges.sort(by: { $0.0 < $1.0 })
            }
        }
    }

    // The "registry" of frozen (finished) nodes for suffix sharing.
    private var registry: [BuildNode: BuildNode] = [:]

    // The unchecked nodes along the rightmost path (from root to last inserted leaf).
    // Each entry: (parent, character leading to child, child)
    private var uncheckedNodes: [(BuildNode, Character, BuildNode)] = []

    private var root = BuildNode()
    private var previousWord = ""
    private var wordList: [String] = []

    /// Build a complete DAWGDictionary from a sorted list of lowercase words.
    func build(from sortedWords: [String]) -> DAWGDictionary {
        reset()

        for word in sortedWords {
            let lowered = word.lowercased()
            insert(lowered)
        }

        // Freeze remaining unchecked nodes
        replaceOrRegister(downTo: 0)

        // Flatten into array-based DAWGDictionary
        return flatten()
    }

    /// Convenience: build from a text file with one word per line.
    func build(fromFileAt url: URL) throws -> DAWGDictionary {
        let content = try String(contentsOf: url, encoding: .utf8)
        let words = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
            .sorted()
        return build(from: words)
    }

    // MARK: - Incremental insertion

    private func insert(_ word: String) {
        // Find common prefix length with previous word
        let commonLength = zip(previousWord, word).prefix(while: { $0 == $1 }).count

        // Freeze nodes that diverge from previous word
        replaceOrRegister(downTo: commonLength)

        // Walk down existing path or create new nodes
        var current: BuildNode
        if uncheckedNodes.isEmpty {
            current = root
        } else {
            current = uncheckedNodes.last!.2
        }

        let wordChars = Array(word)
        for i in commonLength..<wordChars.count {
            let ch = wordChars[i]
            let newNode = BuildNode()
            current.setChild(ch, newNode)
            uncheckedNodes.append((current, ch, newNode))
            current = newNode
        }

        let wordId = wordList.count
        current.isTerminal = true
        current.wordId = wordId
        wordList.append(word)
        previousWord = word
    }

    /// Freeze unchecked nodes from the bottom of the stack up to `downTo`.
    /// If a node is already in the registry (same structure), replace the parent's
    /// pointer to use the registry copy — this is the suffix sharing step.
    private func replaceOrRegister(downTo: Int) {
        while uncheckedNodes.count > downTo {
            let (parent, ch, child) = uncheckedNodes.removeLast()
            if let existing = registry[child] {
                // Reuse the equivalent existing node
                parent.setChild(ch, existing)
            } else {
                registry[child] = child
            }
        }
    }

    private func reset() {
        registry = [:]
        uncheckedNodes = []
        root = BuildNode()
        previousWord = ""
        wordList = []
    }

    // MARK: - Flatten to array representation

    /// BFS through the graph, assigning each unique BuildNode an integer index,
    /// then produce the compact DAWGNode array.
    private func flatten() -> DAWGDictionary {
        var nodeMap: [ObjectIdentifier: Int] = [:]
        var queue: [BuildNode] = [root]
        nodeMap[ObjectIdentifier(root)] = 0
        var head = 0

        while head < queue.count {
            let node = queue[head]
            head += 1
            for (_, target) in node.edges {
                let id = ObjectIdentifier(target)
                if nodeMap[id] == nil {
                    nodeMap[id] = queue.count
                    queue.append(target)
                }
            }
        }

        var dawgNodes: [DAWGNode] = []
        dawgNodes.reserveCapacity(queue.count)

        for buildNode in queue {
            var node = DAWGNode(isTerminal: buildNode.isTerminal, wordId: buildNode.wordId)
            for (label, target) in buildNode.edges {
                let targetIndex = nodeMap[ObjectIdentifier(target)]!
                node.addEdge(label: label, target: targetIndex)
            }
            dawgNodes.append(node)
        }

        return DAWGDictionary(nodes: dawgNodes, words: wordList)
    }
}
