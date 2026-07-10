import AIUsageMonitorCore
import AppKit
import SwiftUI

enum MenuBarPanelMetrics {
    static let baseWidth: CGFloat = 300
    static let normalBaseHeight: CGFloat = 210
    static let errorBaseHeight: CGFloat = 284
    static let displayScale: CGFloat = 0.9

    static var panelWidth: CGFloat {
        baseWidth * displayScale
    }

    static var normalPanelHeight: CGFloat {
        normalBaseHeight * displayScale
    }

    static var errorPanelHeight: CGFloat {
        errorBaseHeight * displayScale
    }
}

struct MenuBarContentView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            usageCard

            if let errorMessage = store.snapshot.errorMessage {
                errorBanner(errorMessage)
            }
        }
        .padding(16)
        .frame(
            width: MenuBarPanelMetrics.baseWidth,
            height: baseHeight,
            alignment: .topLeading
        )
        .background(
            Color(red: 0.988, green: 0.992, blue: 1.000),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 1)
        )
        .scaleEffect(MenuBarPanelMetrics.displayScale, anchor: .topLeading)
        .frame(
            width: MenuBarPanelMetrics.panelWidth,
            height: baseHeight * MenuBarPanelMetrics.displayScale,
            alignment: .topLeading
        )
    }

    private var baseHeight: CGFloat {
        store.snapshot.errorMessage == nil
            ? MenuBarPanelMetrics.normalBaseHeight
            : MenuBarPanelMetrics.errorBaseHeight
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                if let codexIcon = Self.codexIcon {
                    Image(nsImage: codexIcon)
                        .resizable()
                        .scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(
                            Image(systemName: "bolt.horizontal.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(width: 36, height: 36)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )

            Text("Codex")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 5) {
                GlassIconButton(
                    systemImage: store.isRefreshing ? "hourglass" : "arrow.clockwise",
                    help: "刷新"
                ) {
                    store.refresh()
                }
                .disabled(store.isRefreshing)

                GlassIconButton(systemImage: "power", help: "退出") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("5 小时剩余")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(store.snapshot.fiveHour.percentText)
                        .font(.system(size: 30, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(fiveHourLevel.tint)
                }

                Spacer(minLength: 8)

                ResetTimeBlock(
                    resetsAt: store.snapshot.fiveHour?.resetsAt,
                    compact: false
                )
            }

            ProgressBar(value: fiveHourProgress, tint: fiveHourLevel.tint)
                .padding(.top, 10)

            HStack(alignment: .bottom, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("本周剩余")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(store.snapshot.weekly.percentText)
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(weeklyLevel.tint)
                }

                Spacer(minLength: 8)

                ResetTimeBlock(
                    resetsAt: store.snapshot.weekly?.resetsAt,
                    compact: true
                )
            }
            .padding(.top, 12)
        }
        .padding(13)
        .background(
            fiveHourLevel.cardGradient,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(fiveHourLevel.cardBorder, lineWidth: 1)
        )
        .shadow(color: fiveHourLevel.cardShadow, radius: 10, y: 4)
    }

    private var fiveHourLevel: UsageLevel {
        usageLevel(for: store.snapshot.fiveHour?.remainingPercent)
    }

    private var weeklyLevel: UsageLevel {
        usageLevel(for: store.snapshot.weekly?.remainingPercent)
    }

    private var fiveHourProgress: Double {
        progressValue(for: store.snapshot.fiveHour?.remainingPercent)
    }

    private func progressValue(for remaining: Double?) -> Double {
        guard let remaining else { return 0 }
        return max(0, min(1, remaining / 100))
    }

    private static let codexIcon: NSImage? = {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 36, height: 36)
        return icon
    }()

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color(nsColor: .systemRed))
        .padding(10)
        .background(
            Color(nsColor: .systemRed).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}

private struct GlassIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 27, height: 27)
                .background(
                    Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct ProgressBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.07))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, proxy.size.width * value))
            }
        }
        .frame(height: 4)
    }
}

private struct ResetTimeBlock: View {
    let resetsAt: Date?
    let compact: Bool

    var body: some View {
        if compact {
            content
        } else {
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    Color.white.opacity(0.70),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        }
    }

    private var content: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("下次重置")
                .font(.system(size: compact ? 8 : 9, weight: .semibold))
                .foregroundStyle(.tertiary)

            Text(ResetTimeFormatter.label(for: resetsAt))
                .font(.system(size: compact ? 9 : 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

private extension UsageLevel {
    var tint: Color {
        switch self {
        case .normal:
            return Color(red: 0.247, green: 0.561, blue: 0.447)
        case .warning:
            return Color(red: 0.733, green: 0.463, blue: 0.133)
        case .critical:
            return Color(red: 0.788, green: 0.337, blue: 0.337)
        case .unknown:
            return Color(nsColor: .secondaryLabelColor)
        }
    }

    var cardGradient: LinearGradient {
        let colors: [Color]

        switch self {
        case .normal:
            colors = [
                Color(red: 0.953, green: 0.980, blue: 0.969),
                Color(red: 0.894, green: 0.957, blue: 0.925)
            ]
        case .warning:
            colors = [
                Color(red: 1.000, green: 0.980, blue: 0.941),
                Color(red: 1.000, green: 0.937, blue: 0.824)
            ]
        case .critical:
            colors = [
                Color(red: 1.000, green: 0.973, blue: 0.973),
                Color(red: 1.000, green: 0.902, blue: 0.902)
            ]
        case .unknown:
            colors = [
                Color(red: 0.965, green: 0.969, blue: 0.976),
                Color(red: 0.941, green: 0.949, blue: 0.961)
            ]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var cardBorder: Color {
        switch self {
        case .normal:
            return tint.opacity(0.14)
        case .warning, .critical:
            return tint.opacity(0.16)
        case .unknown:
            return Color.primary.opacity(0.06)
        }
    }

    var cardShadow: Color {
        switch self {
        case .normal, .warning, .critical:
            return tint.opacity(0.09)
        case .unknown:
            return Color.clear
        }
    }
}

private extension Optional where Wrapped == UsageBucket {
    var percentText: String {
        guard let remaining = self?.remainingPercent else {
            return "--%"
        }
        return "\(Int(remaining.rounded()))%"
    }
}
