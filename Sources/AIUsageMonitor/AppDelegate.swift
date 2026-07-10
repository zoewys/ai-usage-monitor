import AIUsageMonitorCore
import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var panel: NSPanel?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePanel()
        bindStore()
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.title = "Codex: --% / --%"
        button.target = self
        button.action = #selector(togglePopover)
    }

    private func configurePanel() {
        let panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: MenuBarPanelMetrics.panelWidth,
                height: MenuBarPanelMetrics.normalPanelHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = NSHostingController(rootView: MenuBarContentView(store: store))
        self.panel = panel
    }

    private func bindStore() {
        store.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.statusItem.button?.title = snapshot.menuBarTitle
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let panel else {
            return
        }

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            let height = store.snapshot.errorMessage == nil
                ? MenuBarPanelMetrics.normalPanelHeight
                : MenuBarPanelMetrics.errorPanelHeight
            panel.setContentSize(NSSize(width: MenuBarPanelMetrics.panelWidth, height: height))
            let buttonFrameInWindow = button.convert(button.bounds, to: nil)
            let buttonFrameInScreen = buttonWindow.convertToScreen(buttonFrameInWindow)
            positionPanel(panel, below: buttonFrameInScreen)
            panel.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func positionPanel(_ panel: NSPanel, below buttonFrame: NSRect) {
        let panelSize = panel.frame.size
        let targetScreen = NSScreen.screens.first { screen in
            screen.frame.intersects(buttonFrame)
        } ?? NSScreen.main

        guard let screen = targetScreen else {
            return
        }

        let margin: CGFloat = 8
        let visibleFrame = screen.visibleFrame
        let preferredX = buttonFrame.maxX - panelSize.width
        let minX = visibleFrame.minX + margin
        let maxX = visibleFrame.maxX - panelSize.width - margin
        let x = min(max(preferredX, minX), maxX)
        let y = buttonFrame.minY - panelSize.height - margin

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private extension UsageSnapshot {
    var menuBarTitle: String {
        "Codex: \(fiveHour.menuBarPercentText) / \(weekly.menuBarPercentText)"
    }
}

private extension Optional where Wrapped == UsageBucket {
    var menuBarPercentText: String {
        guard let remaining = self?.remainingPercent else {
            return "--%"
        }

        return "\(Int(remaining.rounded()))%"
    }
}
