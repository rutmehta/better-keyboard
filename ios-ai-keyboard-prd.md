# iOS AI Keyboard — Product Requirements Document

**Version:** 1.0  
**Last Updated:** January 29, 2026  
**Author:** interfere.com AI Team

---

## Executive Summary

A custom iOS keyboard that combines best-in-class swipe typing with haptic feedback and on-device AI capabilities. The keyboard works across all applications, with intelligent features like screenshot-based context analysis for generating contextually appropriate responses.

**Key Differentiators:**
- Superior swipe typing (SHARK2 algorithm + language model reranking)
- Rich haptic feedback on every keypress
- On-device LLM integration via Apple's Foundation Models framework
- Screenshot analysis for context-aware AI assistance (dating apps, emails, Slack, etc.)
- Privacy-first: all processing happens on-device

---

## Table of Contents

1. [Product Vision](#1-product-vision)
2. [Target Users](#2-target-users)
3. [Technical Constraints](#3-technical-constraints)
4. [Feature Specifications](#4-feature-specifications)
5. [Architecture Overview](#5-architecture-overview)
6. [Implementation Phases](#6-implementation-phases)
7. [Risk Assessment](#7-risk-assessment)
8. [Success Metrics](#8-success-metrics)
9. [Appendix](#9-appendix)

---

## 1. Product Vision

### 1.1 Problem Statement

Current iOS keyboards fall short in several areas:
- Apple's default keyboard lacks swipe typing sophistication
- Third-party keyboards have poor haptic feedback or require network access
- No keyboard offers intelligent, context-aware AI assistance
- Users must leave their current app to get AI help with messages

### 1.2 Solution

An iOS keyboard that:
1. Provides Google Keyboard-quality swipe typing with superior haptics
2. Integrates on-device AI for smart suggestions and completions
3. Analyzes screenshots to understand conversation context
4. Works seamlessly across ALL iOS applications
5. Operates entirely on-device for maximum privacy

### 1.3 Use Cases

| Use Case | Description | Apps |
|----------|-------------|------|
| Dating Assistance | Analyze match profiles/conversations, generate witty openers/replies | Hinge, Bumble, Tinder |
| Professional Communication | Draft emails, polish messages | Mail, Gmail, Outlook |
| Social Media | Craft engaging responses | Instagram, Twitter, LinkedIn |
| Messaging | Quick smart replies | iMessage, WhatsApp, Slack |
| General Writing | Autocomplete, tone adjustment, grammar | Notes, any text field |

---

## 2. Target Users

### 2.1 Primary Persona: "Alex"

- Age: 22-35
- Tech-savvy professional or student
- Active on dating apps and social media
- Values efficiency and polish in communication
- Privacy-conscious (skeptical of cloud-based AI)

### 2.2 Secondary Persona: "Jordan"

- Age: 28-45
- Business professional
- Sends 50+ messages daily across multiple platforms
- Needs quick, professional responses
- Uses swipe typing extensively

---

## 3. Technical Constraints

### 3.1 iOS Keyboard Extension Limitations

| Constraint | Value | Impact |
|------------|-------|--------|
| Memory Ceiling | 48MB (hard kill) | Must optimize all components |
| Context Access | ~300 chars via textDocumentProxy | Limited conversation history |
| Full Access Required | Haptics, clipboard, network | Must explain value to users |
| No Screen Capture | Cannot read screen content | Screenshot workaround required |
| No Microphone | Direct access prohibited | App jump pattern if needed |
| Secure Fields | Auto-fallback to system keyboard | Cannot assist with passwords |

### 3.2 Device Requirements

| Feature | Minimum Device | Notes |
|---------|----------------|-------|
| Foundation Models | iPhone 15 Pro / M1 Mac | iOS 26+, Apple Intelligence enabled |
| Haptic Feedback | iPhone 8+ | Core Haptics, Taptic Engine |
| Swipe Typing | Any supported device | Pure software implementation |
| Screenshot Analysis | Any supported device | Photos library access |

### 3.3 Required Permissions

| Permission | Purpose | When Requested |
|------------|---------|----------------|
| Full Access | Haptics, clipboard, App Groups | Initial setup |
| Photos Library | Screenshot access | First AI analysis |
| App Groups | Keyboard ↔ App communication | Automatic |

---

## 4. Feature Specifications

### 4.1 Phase 1: Core Keyboard

#### 4.1.1 Swipe Typing

**Algorithm:** SHARK2 (Shape-writing recognition)

**Components:**
- Geometric shape matching using Dynamic Time Warping (DTW)
- DAWG dictionary (Directed Acyclic Word Graph) for fast lookup
- Bayesian integration for candidate ranking
- N-gram language model for context awareness

**Performance Requirements:**
- < 17ms latency per touch point
- < 100ms total gesture-to-suggestion time
- 95%+ accuracy on first suggestion
- Support for 100K+ word vocabulary

**Technical Implementation:**

```
Touch Input Stream
       │
       ▼
┌─────────────────────┐
│  Gesture Capture    │  Sample at 60Hz, normalize coordinates
│  (UIGestureRecognizer) │
└─────────────────────┘
       │
       ▼
┌─────────────────────┐
│  Shape Encoder      │  Convert path to feature vector
│  - Curvature        │  33 features per point (Grammarly approach)
│  - Velocity         │
│  - Direction        │
└─────────────────────┘
       │
       ▼
┌─────────────────────┐
│  SHARK2 Decoder     │  DTW distance to ideal word shapes
│  (or Lightweight    │  Output: top 50 candidates
│   LSTM if memory    │
│   allows)           │
└─────────────────────┘
       │
       ▼
┌─────────────────────┐
│  Language Model     │  Rerank using N-gram or Foundation Models
│  Reranking          │  Context: previous 2-3 words
└─────────────────────┘
       │
       ▼
┌─────────────────────┐
│  Suggestion Bar     │  Top 3 candidates displayed
│  [word1] [word2]    │
│  [word3]            │
└─────────────────────┘
```

**Data Structures:**

```swift
// DAWG Node (memory-efficient)
struct DAWGNode {
    var edges: [Character: Int]  // Index to next node
    var isTerminal: Bool
    var wordId: Int?  // For terminal nodes
}

// Gesture Template
struct GestureTemplate {
    let wordId: Int
    let points: [CGPoint]  // Normalized key centers
    let totalLength: Float
}

// Candidate
struct SwipeCandidate {
    let word: String
    let geometricScore: Float  // DTW distance
    let languageScore: Float   // N-gram probability
    var combinedScore: Float { geometricScore * 0.6 + languageScore * 0.4 }
}
```

#### 4.1.2 Haptic Feedback

**Implementation:**

```swift
import UIKit

class HapticEngine {
    private var impactGenerator: UIImpactFeedbackGenerator?
    private var selectionGenerator: UISelectionFeedbackGenerator?
    
    func prepare() {
        impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator?.prepare()
        selectionGenerator = UISelectionFeedbackGenerator()
        selectionGenerator?.prepare()
    }
    
    func keyTap() {
        impactGenerator?.impactOccurred(intensity: 0.5)
    }
    
    func spaceTap() {
        impactGenerator?.impactOccurred(intensity: 0.7)
    }
    
    func deleteTap() {
        impactGenerator?.impactOccurred(intensity: 0.6)
    }
    
    func swipeComplete() {
        selectionGenerator?.selectionChanged()
    }
    
    func suggestionSelect() {
        impactGenerator?.impactOccurred(intensity: 0.8)
    }
    
    // CRITICAL: Deallocate when keyboard disappears to save battery
    func suspend() {
        impactGenerator = nil
        selectionGenerator = nil
    }
}
```

**Haptic Intensity Settings:**

| Action | Intensity | Generator Type |
|--------|-----------|----------------|
| Key tap | 0.5 | Impact (light) |
| Space | 0.7 | Impact (light) |
| Delete | 0.6 | Impact (light) |
| Swipe complete | — | Selection |
| Suggestion select | 0.8 | Impact (light) |
| Error (invalid input) | 1.0 | Notification (error) |

#### 4.1.3 Basic Keyboard Layout

**Supported Layouts:**
- QWERTY (primary)
- Numbers & Symbols (secondary)
- Emoji picker (tertiary)

**Key Features:**
- Globe button for keyboard switching (Apple requirement)
- Long-press for alternate characters
- Shift/caps lock behavior matching iOS standard
- Return key adapts to context (Send, Search, Done, etc.)

---

### 4.2 Phase 2: AI Integration

#### 4.2.1 On-Device LLM (Foundation Models)

**Framework:** Apple Foundation Models (iOS 26+)

**Capabilities:**
- ~3B parameter model, 2-bit quantization
- Sub-10ms time-to-first-token
- 30 tokens/second generation
- 4K context window
- Runs as system service (doesn't count against 48MB limit)

**Implementation:**

```swift
import FoundationModels

class AIEngine {
    private var session: LanguageModelSession?
    
    func initialize() async throws {
        guard LanguageModelSession.isAvailable else {
            throw AIError.notAvailable
        }
        session = LanguageModelSession()
    }
    
    // Streaming completion for suggestion bar
    func streamCompletion(
        context: String,
        partial: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let prompt = """
                Context: \(context)
                Current input: \(partial)
                Complete this naturally in 1-5 words:
                """
                
                do {
                    for try await chunk in session!.streamResponse(to: prompt) {
                        continuation.yield(chunk.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // Generate reply suggestions from screenshot analysis
    func generateReplies(
        conversationText: String,
        style: ReplyStyle
    ) async throws -> [String] {
        let prompt = """
        Conversation:
        \(conversationText)
        
        Generate 3 \(style.rawValue) reply options. 
        Format: One reply per line, no numbering.
        """
        
        let response = try await session!.respond(to: prompt)
        return response.content
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { String($0) }
    }
}

enum ReplyStyle: String {
    case flirty = "flirty and witty"
    case professional = "professional and polished"
    case casual = "casual and friendly"
    case funny = "humorous"
}
```

**Fallback Strategy:**

```
┌─────────────────────────────────────────────────────────┐
│                   AI Request                            │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │ Foundation Models     │
              │ available?            │
              └───────────────────────┘
                    │           │
                   Yes          No
                    │           │
                    ▼           ▼
         ┌─────────────┐  ┌─────────────────┐
         │ Use on-     │  │ CoreML fallback │
         │ device FM   │  │ (smaller model) │
         └─────────────┘  └─────────────────┘
                               │
                               ▼
                    ┌───────────────────────┐
                    │ CoreML available?     │
                    └───────────────────────┘
                          │           │
                         Yes          No
                          │           │
                          ▼           ▼
               ┌─────────────┐  ┌─────────────────┐
               │ Use CoreML  │  │ Cloud API       │
               │ model       │  │ (with consent)  │
               └─────────────┘  └─────────────────┘
```

#### 4.2.2 Screenshot Analysis Pipeline

**Flow:**

```
┌──────────────────────────────────────────────────────────────────┐
│  USER IN TARGET APP (Hinge, Slack, Email, etc.)                 │
│                                                                  │
│  1. User takes screenshot(s) of conversation                     │
│  2. User switches to AI keyboard                                 │
│  3. User taps "✨ AI" button                                     │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  KEYBOARD EXTENSION                                              │
│                                                                  │
│  4. Deep link to containing app with "analyze" intent            │
│     URL: yourapp://analyze?source=keyboard                       │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  CONTAINING APP                                                  │
│                                                                  │
│  5. Fetch recent screenshots (last 2 minutes)                    │
│     PHPhotoLibrary with mediaSubtype == .photoScreenshot         │
│                                                                  │
│  6. OCR with Vision framework                                    │
│     VNRecognizeTextRequest → conversation text                   │
│                                                                  │
│  7. Generate replies with Foundation Models                      │
│     Input: extracted text + user style preference                │
│     Output: 3-5 contextual reply options                         │
│                                                                  │
│  8. Save results to App Groups shared container                  │
│     UserDefaults(suiteName: "group.com.yourapp")                 │
│                                                                  │
│  9. Return to original app (automatic or user-initiated)         │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  KEYBOARD EXTENSION (back in target app)                        │
│                                                                  │
│  10. Read replies from shared container                          │
│  11. Display reply options in keyboard UI                        │
│  12. User taps preferred reply                                   │
│  13. Insert via textDocumentProxy.insertText()                   │
└──────────────────────────────────────────────────────────────────┘
```

**Screenshot Fetching:**

```swift
import Photos

class ScreenshotManager {
    
    func fetchRecentScreenshots(
        limit: Int = 5,
        withinSeconds: TimeInterval = 120
    ) async throws -> [UIImage] {
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw ScreenshotError.permissionDenied
        }
        
        let options = PHFetchOptions()
        let cutoffDate = Date().addingTimeInterval(-withinSeconds)
        
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "mediaSubtype == %d", 
                       PHAssetMediaSubtype.photoScreenshot.rawValue),
            NSPredicate(format: "creationDate > %@", cutoffDate as NSDate)
        ])
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        options.fetchLimit = limit
        
        let results = PHAsset.fetchAssets(with: .image, options: options)
        
        return await withCheckedContinuation { continuation in
            var images: [UIImage] = []
            let manager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = true
            requestOptions.deliveryMode = .highQualityFormat
            
            results.enumerateObjects { asset, index, _ in
                manager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: 1170, height: 2532), // iPhone 14 Pro
                    contentMode: .aspectFit,
                    options: requestOptions
                ) { image, _ in
                    if let image = image {
                        images.append(image)
                    }
                }
            }
            
            continuation.resume(returning: images)
        }
    }
}
```

**Vision OCR:**

```swift
import Vision

class OCREngine {
    
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                
                continuation.resume(returning: text)
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // Combine multiple screenshots (scrolling conversation)
    func extractConversation(from images: [UIImage]) async throws -> String {
        var allText: [String] = []
        
        for image in images.reversed() { // Oldest first
            let text = try await extractText(from: image)
            allText.append(text)
        }
        
        // Simple deduplication (remove overlapping content)
        return deduplicateConversation(allText)
    }
    
    private func deduplicateConversation(_ chunks: [String]) -> String {
        // Find overlapping suffixes/prefixes and merge
        var result = chunks.first ?? ""
        
        for i in 1..<chunks.count {
            let current = chunks[i]
            // Find overlap between result's suffix and current's prefix
            let overlap = findOverlap(result, current)
            if overlap > 20 { // Significant overlap
                result += String(current.dropFirst(overlap))
            } else {
                result += "\n---\n" + current
            }
        }
        
        return result
    }
    
    private func findOverlap(_ a: String, _ b: String) -> Int {
        let maxOverlap = min(a.count, b.count, 200)
        for length in stride(from: maxOverlap, through: 20, by: -10) {
            let aSuffix = String(a.suffix(length))
            if b.hasPrefix(aSuffix) {
                return length
            }
        }
        return 0
    }
}
```

#### 4.2.3 Context Sources (Beyond Screenshots)

| Source | Access Method | Data Available | Full Access Required |
|--------|---------------|----------------|---------------------|
| textDocumentProxy | Direct | ~300 chars before/after cursor | No |
| UIPasteboard | Direct | Clipboard content (text/image) | Yes |
| UITextInputMode | Direct | Keyboard type, language | No |
| Bundle Identifier | Direct | Hosting app identity | No |
| App Groups | Shared container | User preferences, history | No |

**Context-Aware Suggestions by App:**

```swift
enum HostApp {
    case dating(DatingApp)
    case email(EmailApp)
    case messaging(MessagingApp)
    case social(SocialApp)
    case unknown(String)
    
    init(bundleId: String) {
        switch bundleId {
        case "com.hinge.Hinge": self = .dating(.hinge)
        case "com.cardify.tinder": self = .dating(.tinder)
        case "com.bumble.app": self = .dating(.bumble)
        case "com.apple.mobilemail": self = .email(.appleMail)
        case "com.google.Gmail": self = .email(.gmail)
        case "com.apple.MobileSMS": self = .messaging(.imessage)
        case "net.whatsapp.WhatsApp": self = .messaging(.whatsapp)
        case "com.slack.Slack": self = .messaging(.slack)
        case "com.burbn.instagram": self = .social(.instagram)
        case "com.linkedin.LinkedIn": self = .social(.linkedin)
        default: self = .unknown(bundleId)
        }
    }
    
    var defaultTone: ReplyStyle {
        switch self {
        case .dating: return .flirty
        case .email: return .professional
        case .messaging: return .casual
        case .social: return .casual
        case .unknown: return .casual
        }
    }
    
    var suggestedPromptPrefix: String {
        switch self {
        case .dating: return "You're helping craft a dating app message. Be charming and witty."
        case .email: return "You're helping draft a professional email. Be clear and polished."
        case .messaging: return "You're helping with a casual message. Be friendly and natural."
        case .social: return "You're helping with a social media response. Be engaging."
        case .unknown: return "You're helping write a message."
        }
    }
}
```

---

### 4.3 Phase 3: Polish & Optimization

#### 4.3.1 Memory Management

**Budget Allocation (48MB ceiling):**

| Component | Allocation | Notes |
|-----------|------------|-------|
| UI Layer | 8 MB | KeyboardKit or custom views |
| DAWG Dictionary | 5 MB | 100K words, compressed |
| Gesture Templates | 3 MB | Pre-computed ideal paths |
| CoreML Model (if used) | 4 MB | Quantized int8 |
| Runtime Buffers | 5 MB | Touch points, candidates |
| Foundation Models | 0 MB | System service |
| **Safety Margin** | **23 MB** | For OS overhead |
| **Total** | **25 MB** | Well under 48MB limit |

**Lazy Loading Strategy:**

```swift
class KeyboardResources {
    // Load immediately
    var basicLayout: KeyboardLayout
    var hapticEngine: HapticEngine
    
    // Load on first swipe
    lazy var dawgDictionary: DAWGDictionary = {
        DAWGDictionary.load(from: "dictionary.dawg")
    }()
    
    lazy var gestureTemplates: [GestureTemplate] = {
        GestureTemplate.loadAll(from: "templates.bin")
    }()
    
    // Load only when AI button tapped
    lazy var aiEngine: AIEngine? = {
        guard LanguageModelSession.isAvailable else { return nil }
        return try? AIEngine()
    }()
    
    // Aggressive cleanup when backgrounded
    func releaseNonEssential() {
        // Keep only basic layout
        dawgDictionary.releaseCache()
        gestureTemplates = []
        aiEngine = nil
    }
}
```

#### 4.3.2 Battery Optimization

- Deallocate haptic generators when keyboard is dismissed
- Use `.light` impact intensity (less motor activation)
- Batch touch processing (don't process every 60Hz sample)
- Lazy-load AI components only when requested
- Cancel in-flight LLM requests if user types instead

#### 4.3.3 Settings & Customization

**User Preferences (in Containing App):**

| Setting | Options | Default |
|---------|---------|---------|
| Haptic Intensity | Off / Light / Medium / Strong | Light |
| Swipe Sensitivity | Low / Medium / High | Medium |
| AI Style | Flirty / Professional / Casual / Funny | Auto (by app) |
| Quick Suggestions | On / Off | On |
| Screenshot History | Keep 5 / 10 / 20 / Don't keep | 10 |
| Keyboard Theme | Light / Dark / System | System |

---

## 5. Architecture Overview

### 5.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              iOS DEVICE                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    CONTAINING APP                                │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │   │
│  │  │  Settings   │  │  Onboarding │  │  Screenshot Processor   │ │   │
│  │  │  UI         │  │  Flow       │  │  - PHPhotoLibrary       │ │   │
│  │  │             │  │             │  │  - Vision OCR           │ │   │
│  │  └─────────────┘  └─────────────┘  │  - Foundation Models    │ │   │
│  │                                     └─────────────────────────┘ │   │
│  │                                                                  │   │
│  │  ┌─────────────────────────────────────────────────────────────┐│   │
│  │  │                    APP GROUPS CONTAINER                     ││   │
│  │  │  - User preferences                                         ││   │
│  │  │  - Generated replies (temporary)                            ││   │
│  │  │  - Custom dictionary entries                                ││   │
│  │  └─────────────────────────────────────────────────────────────┘│   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                    ▲                                    │
│                                    │ Shared Container                   │
│                                    ▼                                    │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    KEYBOARD EXTENSION                            │   │
│  │                                                                  │   │
│  │  ┌───────────────────┐  ┌───────────────────┐                   │   │
│  │  │   UI Layer        │  │   Input Engine    │                   │   │
│  │  │   - Key views     │  │   - Tap handling  │                   │   │
│  │  │   - Suggestion    │  │   - Swipe decode  │                   │   │
│  │  │     bar           │  │   - DAWG lookup   │                   │   │
│  │  │   - AI panel      │  │                   │                   │   │
│  │  └───────────────────┘  └───────────────────┘                   │   │
│  │                                                                  │   │
│  │  ┌───────────────────┐  ┌───────────────────┐                   │   │
│  │  │   Haptic Engine   │  │   AI Integration  │                   │   │
│  │  │   - Impact gen    │  │   - FM session    │                   │   │
│  │  │   - Selection gen │  │   - App jump      │                   │   │
│  │  └───────────────────┘  │   - Reply display │                   │   │
│  │                         └───────────────────┘                   │   │
│  │                                                                  │   │
│  │  ┌─────────────────────────────────────────────────────────────┐│   │
│  │  │   textDocumentProxy                                         ││   │
│  │  │   - insertText(), deleteBackward()                          ││   │
│  │  │   - documentContextBeforeInput (~300 chars)                 ││   │
│  │  └─────────────────────────────────────────────────────────────┘│   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    SYSTEM SERVICES                               │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │   │
│  │  │ Foundation  │  │   Photos    │  │   Core Haptics          │ │   │
│  │  │ Models      │  │   Library   │  │   (Taptic Engine)       │ │   │
│  │  │ (on-device  │  │             │  │                         │ │   │
│  │  │  LLM)       │  │             │  │                         │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Data Flow

```
USER INPUT                    SWIPE PATH                     OUTPUT
    │                             │                             │
    ▼                             ▼                             ▼
┌─────────┐               ┌─────────────┐              ┌─────────────┐
│ Key Tap │──────────────▶│ Insert char │─────────────▶│ Text Field  │
└─────────┘               └─────────────┘              └─────────────┘
    │                             │                             ▲
    ▼                             │                             │
┌─────────┐                       │                             │
│ Haptic  │                       │                             │
│ Feedback│                       │                             │
└─────────┘                       │                             │
                                  │                             │
┌─────────┐               ┌─────────────┐              ┌─────────────┐
│ Swipe   │──────────────▶│ SHARK2      │─────────────▶│ Suggestions │
│ Gesture │               │ Decoder     │              │ [a][b][c]   │
└─────────┘               └─────────────┘              └─────────────┘
                                  │                             │
                                  ▼                             │
                          ┌─────────────┐                       │
                          │ LM Rerank   │                       │
                          │ (optional)  │                       │
                          └─────────────┘                       │
                                                                │
┌─────────┐               ┌─────────────┐              ┌─────────────┐
│ AI      │──────────────▶│ Screenshot  │─────────────▶│ Reply       │
│ Button  │               │ + OCR + LLM │              │ Options     │
└─────────┘               └─────────────┘              └─────────────┘
                                                                │
                                                                ▼
                                                       ┌─────────────┐
                                                       │ User taps   │
                                                       │ → Insert    │
                                                       └─────────────┘
```

---

## 6. Implementation Phases

### Phase 1: Core Keyboard (Weeks 1-6)

**Goal:** Functional keyboard with swipe typing and haptics

#### Week 1-2: Project Setup & Basic Keyboard

| Task | Description | Deliverable |
|------|-------------|-------------|
| 1.1 | Create Xcode project with keyboard extension target | Project structure |
| 1.2 | Implement UIInputViewController subclass | KeyboardViewController.swift |
| 1.3 | Build basic QWERTY layout (tap typing only) | Working tap keyboard |
| 1.4 | Add globe button for keyboard switching | Apple compliance |
| 1.5 | Configure App Groups | Shared container |
| 1.6 | Set up Full Access permission flow | Settings integration |

**Milestone 1:** User can type with tap keyboard, switch keyboards

#### Week 3-4: Haptic Feedback & Polish

| Task | Description | Deliverable |
|------|-------------|-------------|
| 2.1 | Implement HapticEngine class | HapticEngine.swift |
| 2.2 | Add haptics to all key actions | Tactile feedback |
| 2.3 | Build settings UI in containing app | Settings screen |
| 2.4 | Add haptic intensity preference | User customization |
| 2.5 | Implement shift/caps lock behavior | Standard iOS behavior |
| 2.6 | Add numbers & symbols layout | Secondary keyboard |

**Milestone 2:** Haptic feedback on all keypresses, basic settings

#### Week 5-6: Swipe Typing Foundation

| Task | Description | Deliverable |
|------|-------------|-------------|
| 3.1 | Build DAWG dictionary from word list | dictionary.dawg |
| 3.2 | Implement gesture capture (60Hz sampling) | GestureCapture.swift |
| 3.3 | Generate ideal gesture templates for top 10K words | templates.bin |
| 3.4 | Implement DTW distance calculation | DTWMatcher.swift |
| 3.5 | Build basic SHARK2 decoder (geometric only) | SwipeDecoder.swift |
| 3.6 | Display top 3 candidates in suggestion bar | UI integration |

**Milestone 3:** Basic swipe typing works (geometric matching only)

---

### Phase 2: Swipe Optimization (Weeks 7-10)

**Goal:** Production-quality swipe typing

#### Week 7-8: Language Model Integration

| Task | Description | Deliverable |
|------|-------------|-------------|
| 4.1 | Build N-gram language model from corpus | ngram.bin |
| 4.2 | Implement LM scoring for candidates | LanguageModel.swift |
| 4.3 | Bayesian integration (geometric + LM scores) | Improved accuracy |
| 4.4 | Add context awareness (previous 2-3 words) | Context buffer |
| 4.5 | Test Foundation Models availability in extension | Proof of concept |
| 4.6 | (If available) Use FM for advanced reranking | AI-powered suggestions |

**Milestone 4:** Swipe accuracy > 90% on common words

#### Week 9-10: Performance & Edge Cases

| Task | Description | Deliverable |
|------|-------------|-------------|
| 5.1 | Profile memory usage with Instruments | < 30MB usage |
| 5.2 | Optimize hot paths (< 17ms per touch) | Performance tuning |
| 5.3 | Handle edge cases (short words, similar shapes) | Robustness |
| 5.4 | Add user dictionary (custom words) | Personalization |
| 5.5 | Implement autocorrect for tap typing | Spell check |
| 5.6 | Beta testing with 10-20 users | Feedback collection |

**Milestone 5:** Swipe typing production-ready, < 100ms latency

---

### Phase 3: AI Features (Weeks 11-14)

**Goal:** Screenshot analysis and AI reply generation

#### Week 11-12: Screenshot Pipeline

| Task | Description | Deliverable |
|------|-------------|-------------|
| 6.1 | Implement ScreenshotManager in containing app | Screenshot fetching |
| 6.2 | Build Vision OCR pipeline | Text extraction |
| 6.3 | Handle multiple screenshots (deduplication) | Conversation stitching |
| 6.4 | Implement app jump flow (keyboard → app → keyboard) | Deep linking |
| 6.5 | Build App Groups communication layer | Reply passing |
| 6.6 | Design AI button and reply panel UI | Keyboard UI |

**Milestone 6:** Can extract text from screenshots and display in keyboard

#### Week 13-14: AI Reply Generation

| Task | Description | Deliverable |
|------|-------------|-------------|
| 7.1 | Integrate Foundation Models in containing app | AIEngine.swift |
| 7.2 | Build prompt templates for different contexts | Prompt engineering |
| 7.3 | Implement style selection (flirty/professional/etc) | Style picker |
| 7.4 | Auto-detect host app for default style | Bundle ID mapping |
| 7.5 | Add cloud LLM fallback (with user consent) | API integration |
| 7.6 | End-to-end testing across major apps | QA |

**Milestone 7:** AI reply generation works in Hinge, Slack, Mail, etc.

---

### Phase 4: Launch Prep (Weeks 15-18)

**Goal:** App Store submission

#### Week 15-16: Polish & Optimization

| Task | Description | Deliverable |
|------|-------------|-------------|
| 8.1 | Final memory optimization pass | < 40MB peak |
| 8.2 | Battery impact testing | Acceptable drain |
| 8.3 | Accessibility audit (VoiceOver, Dynamic Type) | A11y compliance |
| 8.4 | Localization (keyboard labels) | Multi-language |
| 8.5 | Onboarding flow in containing app | First-run experience |
| 8.6 | Privacy policy and terms | Legal compliance |

**Milestone 8:** App meets Apple quality guidelines

#### Week 17-18: Submission

| Task | Description | Deliverable |
|------|-------------|-------------|
| 9.1 | App Store screenshots and preview video | Marketing assets |
| 9.2 | Write App Store description | Listing |
| 9.3 | TestFlight beta to 100+ users | Broader testing |
| 9.4 | Address TestFlight feedback | Bug fixes |
| 9.5 | Submit to App Store review | Submission |
| 9.6 | Address any review rejections | Approval |

**Milestone 9:** App live on App Store

---

## 7. Risk Assessment

### 7.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Foundation Models unavailable in keyboard extension | Medium | High | App jump fallback pattern ready; test early |
| Memory pressure causes crashes | Medium | High | Aggressive lazy loading; 23MB safety margin |
| Swipe accuracy below acceptable threshold | Low | High | Fallback to simpler geometric-only decoder |
| OCR fails on varied screenshot formats | Medium | Medium | Train on diverse app screenshots; user feedback |
| App Store rejection | Medium | High | Build substantial containing app; follow guidelines |

### 7.2 Business Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Apple releases competing feature | Medium | High | Move fast; differentiate on AI features |
| iOS 26 adoption slow | Medium | Medium | CoreML fallback for older devices |
| Users don't enable Full Access | Medium | Medium | Clear value proposition in onboarding |
| Competition from Cupidly/Keys AI | High | Medium | Superior swipe typing as differentiator |

### 7.3 Contingency Plans

**If Foundation Models don't work in extension:**
1. Use app jump pattern for ALL AI features
2. Keep keyboard lightweight (swipe + haptics only)
3. Minimize app jump friction (< 2 seconds round trip)

**If swipe accuracy is poor:**
1. License FleksySDK (commercial, proven quality)
2. Focus on AI features as primary differentiator
3. Position as "AI keyboard" not "swipe keyboard"

**If App Store rejects:**
1. Ensure containing app has standalone value (AI chat, writing assistant)
2. Remove any features that might be flagged (if any)
3. Resubmit with detailed appeal if rejection seems unfair

---

## 8. Success Metrics

### 8.1 Technical Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Swipe accuracy (first suggestion) | > 95% | Automated test suite |
| Gesture-to-suggestion latency | < 100ms | Instruments profiling |
| Memory usage (peak) | < 40MB | Instruments profiling |
| Crash rate | < 0.1% | Crash reporting |
| AI reply generation time | < 3s | Timer in app |

### 8.2 User Metrics

| Metric | Target (Month 1) | Target (Month 6) |
|--------|------------------|------------------|
| Daily Active Users | 1,000 | 50,000 |
| Full Access enabled | > 80% | > 85% |
| AI feature usage | > 30% of DAU | > 50% of DAU |
| App Store rating | > 4.0 | > 4.5 |
| Retention (Day 7) | > 40% | > 50% |

### 8.3 Engagement Metrics

| Metric | Target |
|--------|--------|
| Swipes per user per day | > 50 |
| AI replies generated per user per week | > 10 |
| Time in keyboard vs system keyboard | > 70% |

---

## 9. Appendix

### 9.1 Glossary

| Term | Definition |
|------|------------|
| DAWG | Directed Acyclic Word Graph — memory-efficient dictionary structure |
| DTW | Dynamic Time Warping — algorithm for comparing gesture shapes |
| SHARK2 | Shape-writing recognition algorithm (IBM Research) |
| textDocumentProxy | iOS API providing limited access to text around cursor |
| Foundation Models | Apple's on-device LLM framework (iOS 26+) |
| App Groups | iOS mechanism for sharing data between app and extension |
| Full Access | iOS permission granting keyboard network/haptics/clipboard access |

### 9.2 Open Source Dependencies

| Library | Purpose | License |
|---------|---------|---------|
| KeyboardKit (optional) | UI framework | MIT |
| swift-algorithms | Performance utilities | Apache 2.0 |
| (Custom) | DAWG implementation | Proprietary |
| (Custom) | SHARK2 decoder | Proprietary |

### 9.3 Reference Materials

- [Apple Keyboard Extension Guide](https://developer.apple.com/documentation/uikit/keyboards_and_input/creating_a_custom_keyboard)
- [Foundation Models Documentation](https://developer.apple.com/documentation/foundationmodels)
- [SHARK2 Paper (IBM Research)](https://dl.acm.org/doi/10.1145/1166253.1166255)
- [How-We-Swipe Dataset](https://osf.io/sj67f/)
- [KeyboardKit GitHub](https://github.com/KeyboardKit/KeyboardKit)
- [Cupidly App Store](https://apps.apple.com/us/app/cupidly/id6753102932)

### 9.4 Contact

**Project Lead:** [Your Name]  
**Email:** [your@email.com]  
**Slack:** #ios-keyboard-project

---

*Document Version 1.0 — January 29, 2026*
