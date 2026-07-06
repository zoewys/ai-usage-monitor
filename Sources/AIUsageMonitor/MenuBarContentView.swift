import AIUsageMonitorCore
import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(spacing: 10) {
                if let weekly = store.snapshot.weekly, weekly.id != store.snapshot.headlineBucket?.id {
                    GlassMetricRow(
                        icon: "calendar",
                        title: "本周剩余",
                        bucket: weekly,
                        tint: .cyan
                    )
                }
                if let fiveHour = store.snapshot.fiveHour, fiveHour.id != store.snapshot.headlineBucket?.id {
                    GlassMetricRow(
                        icon: "timer",
                        title: "5 小时剩余",
                        bucket: fiveHour,
                        tint: .purple
                    )
                }
            }

            if let errorMessage = store.snapshot.errorMessage {
                errorBanner(errorMessage)
            }

            footer
        }
        .padding(16)
        .frame(width: 336)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 14)
        .scaleEffect(0.9, anchor: .topLeading)
        .frame(width: 336 * 0.9, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                if let codexIcon = Self.codexIcon {
                    Image(nsImage: codexIcon)
                        .resizable()
                        .scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(store.snapshot.level.tint.opacity(0.18))
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(store.snapshot.level.tint)
                }
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("Codex")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("剩余用量")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                Text(store.snapshot.headlineText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(store.snapshot.headlineBadge)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(store.snapshot.level.tint)
                if let resetsAt = store.snapshot.headlineBucket?.resetsAt {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9, weight: .semibold))
                        Text("重置 \(resetsAt.resetLabel)")
                            .lineLimit(1)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private static let codexIcon: NSImage? = {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 46, height: 46)
        return icon
    }()

    private var footer: some View {
        HStack(spacing: 10) {
            Label(store.snapshot.refreshedAt.updatedLabel, systemImage: "clock")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            GlassIconButton(
                systemImage: store.isRefreshing ? "hourglass" : "arrow.clockwise",
                help: "刷新"
            ) {
                store.refresh()
            }
            .disabled(store.isRefreshing)

            GlassIconButton(systemImage: "arrow.up.right.square", help: "打开 Codex") {
                NSWorkspace.shared.open(URL(string: "codex://")!)
            }

            GlassIconButton(systemImage: "power", help: "退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.top, 2)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color(nsColor: .systemRed))
        .padding(10)
        .background(Color(nsColor: .systemRed).opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct GlassMetricRow: View {
    let icon: String
    let title: String
    let bucket: UsageBucket?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Spacer()

                Text(percentText)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * progressValue)
                }
            }
            .frame(height: 8)

            HStack(spacing: 5) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .semibold))
                Text("重置 \(resetText)")
                    .lineLimit(1)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var percentText: String {
        guard let remaining = bucket?.remainingPercent else {
            return "--%"
        }

        return "\(Int(remaining.rounded()))%"
    }

    private var progressValue: Double {
        guard let remaining = bucket?.remainingPercent else {
            return 0
        }

        return max(0, min(1, remaining / 100))
    }

    private var resetText: String {
        guard let resetsAt = bucket?.resetsAt else {
            return "--"
        }

        return resetsAt.resetLabel
    }
}

private struct GlassIconButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 31, height: 31)
                .background(.thinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private extension UsageSnapshot {
    var level: UsageLevel {
        usageLevel(for: headlineRemainingPercent)
    }

    var headlineBadge: String {
        guard let remaining = headlineRemainingPercent else {
            return "--%"
        }

        return "\(Int(remaining.rounded()))%"
    }

    var headlineText: String {
        if errorMessage != nil {
            return "无法读取 Codex 剩余用量"
        }

        guard weekly != nil || fiveHour != nil else {
            return "正在读取剩余用量"
        }

        return "当前最紧额度"
    }
}

private extension UsageLevel {
    var tint: Color {
        switch self {
        case .normal:
            return Color(nsColor: .systemGreen)
        case .warning:
            return Color(nsColor: .systemOrange)
        case .critical:
            return Color(nsColor: .systemRed)
        case .unknown:
            return Color(nsColor: .secondaryLabelColor)
        }
    }
}

private extension Date {
    var updatedLabel: String {
        let seconds = max(0, Int(Date().timeIntervalSince(self)))

        if seconds < 60 {
            return "刚刚更新"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes) 分钟前更新"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) 小时前更新"
        }

        let days = hours / 24
        return "\(days) 天前更新"
    }

    var resetLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        if Calendar.current.isDateInToday(self) {
            return "今天 \(formatter.string(from: self))"
        }

        if Calendar.current.isDateInTomorrow(self) {
            return "明天 \(formatter.string(from: self))"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: self)
    }
}
