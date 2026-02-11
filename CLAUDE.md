# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS AI Keyboard — a custom iOS keyboard app combining SHARK2-based swipe typing, haptic feedback, and on-device AI via Apple's Foundation Models framework (iOS 26+). Privacy-first: all processing on-device.

The project consists of a **Keyboard Extension** (runs in 48MB sandbox) and a **Containing App** (settings, screenshot processing, AI generation). Communication between them uses App Groups shared containers.

## Current Status

The project is in the planning/design phase. The primary artifact is `ios-ai-keyboard-prd.md` — a comprehensive PRD covering architecture, algorithms, implementation phases, and success metrics. No Swift code has been written yet.

## Architecture

### Two Targets
- **Keyboard Extension:** KeyboardViewController, key views, suggestion bar, AI panel, gesture capture (60Hz), SHARK2 swipe decoder, DAWG dictionary lookup, haptic engine, textDocumentProxy for text insertion (~300 char context window)
- **Containing App:** Settings/onboarding UI, screenshot processing pipeline (PHPhotoLibrary → Vision OCR → Foundation Models), App Groups IPC, custom dictionary management

### Key Algorithms
- **SHARK2 Decoder:** Shape-writing with Dynamic Time Warping (DTW), produces top-50 candidates reranked by language model. Scoring: 60% geometric distance + 40% language probability.
- **DAWG:** Directed Acyclic Word Graph for 100K+ word dictionary (~5MB)
- **Foundation Models:** Apple's 3B param on-device LLM, runs as system service (doesn't count against extension memory)

### Memory Budget (48MB hard limit)
UI: 8MB, DAWG: 5MB, Gesture Templates: 3MB, CoreML: 4MB, Runtime: 5MB, Safety margin: 23MB

### Performance Targets
- Swipe: <17ms per touch point, <100ms gesture-to-suggestion, >95% first-suggestion accuracy
- AI reply: <3 seconds end-to-end
- Crash rate: <0.1%

## Frameworks
UIKit, Foundation, CoreHaptics, Vision, Photos, FoundationModels (iOS 26+), App Groups

## Planned Dependencies
- KeyboardKit (MIT, optional)
- swift-algorithms (Apache 2.0)
- Custom DAWG and SHARK2 implementations (proprietary)

## Implementation Phases (from PRD)
1. **Phase 1 (Weeks 1-6):** Core keyboard — Xcode project, QWERTY layout, haptics, DAWG, gesture capture, basic swipe
2. **Phase 2 (Weeks 7-10):** Swipe optimization — N-gram LM, Foundation Models testing, memory profiling, beta
3. **Phase 3 (Weeks 11-14):** AI features — screenshot pipeline, Vision OCR, app jump flow, prompt engineering
4. **Phase 4 (Weeks 15-18):** Launch prep — optimization, accessibility, localization, TestFlight, App Store submission

## Key Constraints
- Keyboard extensions have a 48MB memory hard limit
- textDocumentProxy provides only ~300 characters of surrounding context
- Foundation Models may not be available directly in keyboard extension — use app jump pattern as fallback
- AI fallback chain: Foundation Models → CoreML → Cloud API (with user consent)
