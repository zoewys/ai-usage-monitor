# AI Usage Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that shows Codex Week and 5h remaining usage plus reset times.

**Architecture:** Use a Swift Package with a small AppKit menu bar executable and a reusable core target. The core target owns Codex app-server JSON-RPC access, provider abstraction, usage models, and rate-limit parsing. The app target owns NSStatusItem, popover UI, refresh lifecycle, and display formatting.

**Tech Stack:** Swift 5.9 language mode, SwiftPM, AppKit, SwiftUI, Foundation, XCTest.

---

## File Structure

- `Package.swift`: SwiftPM manifest with `AIUsageMonitor`, `AIUsageMonitorCore`, and tests.
- `Sources/AIUsageMonitorCore/UsageModels.swift`: provider, snapshot, bucket, and usage-level types.
- `Sources/AIUsageMonitorCore/RateLimitParser.swift`: flexible parser for `rateLimits` and `rateLimitsByLimitId`.
- `Sources/AIUsageMonitorCore/CodexAppServerClient.swift`: one-shot JSON-RPC client for `codex app-server`.
- `Sources/AIUsageMonitorCore/CodexUsageProvider.swift`: provider that calls `account/rateLimits/read`.
- `Sources/AIUsageMonitorCore/UsageService.swift`: provider manager for current and future AI usage sources.
- `Sources/AIUsageMonitor/main.swift`: NSApplication entry.
- `Sources/AIUsageMonitor/AppDelegate.swift`: menu bar item, popover, and lifecycle.
- `Sources/AIUsageMonitor/UsageStore.swift`: refresh state and timer.
- `Sources/AIUsageMonitor/MenuBarContentView.swift`: SwiftUI popover content.
- `Tests/AIUsageMonitorCoreTests/*.swift`: parser and usage-level tests.
- `scripts/build_app.sh`: build `.app` bundle locally.
- `README.md`: run, test, and package instructions.

## Tasks

### Task 1: Scaffold Swift Package

- [ ] Create package manifest, `.gitignore`, README skeleton, and build script.
- [ ] Run `swift package describe` and confirm the package loads.

### Task 2: Core Usage Models And Parser

- [ ] Add `UsageModels.swift`.
- [ ] Add parser tests for Week, 5h, label fallback, missing bucket, and usage level.
- [ ] Implement `RateLimitParser.swift`.
- [ ] Run `swift test --filter AIUsageMonitorCoreTests`.

### Task 3: Codex Provider

- [ ] Add `CodexAppServerClient.swift`.
- [ ] Add `CodexUsageProvider.swift`.
- [ ] Add `UsageService.swift`.
- [ ] Keep provider abstraction so other AI tools can be added later.

### Task 4: Menu Bar UI

- [ ] Add `main.swift`, `AppDelegate.swift`, `UsageStore.swift`, and `MenuBarContentView.swift`.
- [ ] Show title as `Codex xx%` or `Codex --%`.
- [ ] In popover show Codex Week, Codex 5h, each reset time, last refresh, refresh button, Open Codex, and Quit.

### Task 5: Verify And Update River

- [ ] Run `swift test`.
- [ ] Run `swift build`.
- [ ] Run `scripts/build_app.sh`.
- [ ] Update River project card with repo path and current status.
