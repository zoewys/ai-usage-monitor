import AIUsageMonitorCore
import AppKit
import SwiftUI

struct MenuBarContentView: View {
    private static let baseWidth: CGFloat = 300
    private static let normalBaseHeight: CGFloat = 228
    private static let errorBaseHeight: CGFloat = 284
    private static let displayScale: CGFloat = 0.9

    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            fiveHourBlock

            weeklyCard

            if let errorMessage = store.snapshot.errorMessage {
                errorBanner(errorMessage)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 20, trailing: 16))
        .frame(width: Self.baseWidth, height: baseHeight, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 1)
        )
        .scaleEffect(Self.displayScale, anchor: .topLeading)
        .frame(
            width: Self.baseWidth * Self.displayScale,
            height: baseHeight * Self.displayScale,
            alignment: .topLeading
        )
    }

    private var baseHeight: CGFloat {
        store.snapshot.errorMessage == nil ? Self.normalBaseHeight : Self.errorBaseHeight
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

            VStack(alignment: .leading, spacing: 1) {
                Text(fiveHourHeadline)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.none)
                Text("Codex")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }

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

    private var fiveHourHeadline: String {
        guard store.snapshot.fiveHour != nil else {
            return store.snapshot.errorMessage == nil ? "读取中" : "暂无数据"
        }
        return "5 小时剩余"
    }

    private var fiveHourBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.snapshot.fiveHour.percentText)
                    .font(.system(size: 30, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(fiveHourTint)

                Spacer()

                ResetLabel(resetsAt: store.snapshot.fiveHour?.resetsAt)
            }

            ProgressBar(value: fiveHourProgress, tint: fiveHourTint)
        }
    }

    private var weeklyCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("本周剩余")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(store.snapshot.weekly.percentText)
                    .font(.system(size: 20, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(weeklyTint)
            }

            ResetLabel(resetsAt: store.snapshot.weekly?.resetsAt, compact: true)

            ProgressBar(value: weeklyProgress, tint: weeklyTint)
        }
        .padding(11)
        .background(
            Color.primary.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private var fiveHourTint: Color {
        usageLevel(for: store.snapshot.fiveHour?.remainingPercent).tint
    }

    private var weeklyTint: Color {
        usageLevel(for: store.snapshot.weekly?.remainingPercent).tint
    }

    private var fiveHourProgress: Double {
        progressValue(for: store.snapshot.fiveHour?.remainingPercent)
    }

    private var weeklyProgress: Double {
        progressValue(for: store.snapshot.weekly?.remainingPercent)
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
                .frame(width: 24, height: 24)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
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
                    .shadow(color: Color.primary.opacity(0.04), radius: 1, y: 0.5)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, proxy.size.width * value))
                    .shadow(color: tint.opacity(0.35), radius: 4, y: 0)
            }
        }
        .frame(height: 5)
    }
}

private struct ResetLabel: View {
    let resetsAt: Date?
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: compact ? 9 : 10, weight: .semibold))
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: compact ? 10 : 11, weight: .medium))
        .foregroundStyle(.tertiary)
    }

    private var text: String {
        guard let resetsAt else { return "重置 --" }
        return "重置 \(resetsAt.resetDurationLabel)"
    }
}

private extension UsageLevel {
    var tint: Color {
        switch self {
        case .normal:
            return Color(red: 0.302, green: 0.678, blue: 0.478)
        case .warning:
            return Color(red: 0.831, green: 0.576, blue: 0.251)
        case .critical:
            return Color(red: 0.788, green: 0.361, blue: 0.361)
        case .unknown:
            return Color(nsColor: .secondaryLabelColor)
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

private extension Date {
    var resetDurationLabel: String {
        let seconds = max(0, Int(timeIntervalSinceNow))

        if seconds < 60 {
            return "即将"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes) 分钟"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours < 24 {
            if remainingMinutes > 0 {
                return "\(hours) 小时 \(remainingMinutes) 分"
            }
            return "\(hours) 小时"
        }

        let days = hours / 24
        let remainingHours = hours % 24
        if remainingHours > 0 {
            return "\(days) 天 \(remainingHours) 小时"
        }
        return "\(days) 天"
    }
}
