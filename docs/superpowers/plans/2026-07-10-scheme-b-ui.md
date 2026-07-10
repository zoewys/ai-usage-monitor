# Scheme B Usage Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将已确认的方案 B 落到 macOS 菜单栏应用，展示两个额度、具体重置时刻和独立状态色，并消除多余留白。

**Architecture:** 数据读取和 `UsageStore` 保持不变。新增一个可测试的重置时刻格式化工具；`MenuBarContentView` 继续观察现有 store，但改为“标题栏 + 同框双层用量卡 + 可选错误提示”的组合。窗口尺寸同步收紧。

**Tech Stack:** Swift 5.9、SwiftUI、AppKit、Swift Package Manager、XCTest

---

### Task 1: 具体重置时刻格式化

**Files:**
- Create: `Sources/AIUsageMonitorCore/ResetTimeFormatter.swift`
- Create: `Tests/AIUsageMonitorCoreTests/ResetTimeFormatterTests.swift`

- [ ] **Step 1: 写入失败测试**

测试固定使用东八区日历，并覆盖当天、次日、未来日期和空值：

```swift
XCTAssertEqual(ResetTimeFormatter.label(for: todayReset, relativeTo: now, calendar: calendar), "今天 21:20")
XCTAssertEqual(ResetTimeFormatter.label(for: tomorrowReset, relativeTo: now, calendar: calendar), "明天 08:05")
XCTAssertEqual(ResetTimeFormatter.label(for: weeklyReset, relativeTo: now, calendar: calendar), "7月17日 周五 10:24")
XCTAssertEqual(ResetTimeFormatter.label(for: nil, relativeTo: now, calendar: calendar), "--")
```

- [ ] **Step 2: 运行测试并确认测试先失败**

Run: `swift test --filter ResetTimeFormatterTests`

Expected: 因 `ResetTimeFormatter` 尚不存在而编译失败。

- [ ] **Step 3: 实现格式化工具**

使用 `Calendar.startOfDay(for:)` 判断日期差，并用日历组件生成稳定的中文标签：

```swift
public enum ResetTimeFormatter {
    public static func label(
        for date: Date?,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current
    ) -> String
}
```

同日返回 `今天 HH:mm`，下一日返回 `明天 HH:mm`，其他日期返回 `M月d日 周X HH:mm`，空值返回 `--`。

- [ ] **Step 4: 运行格式化测试**

Run: `swift test --filter ResetTimeFormatterTests`

Expected: 4 个场景全部通过。

### Task 2: 方案 B 菜单栏界面

**Files:**
- Modify: `Sources/AIUsageMonitor/MenuBarContentView.swift`

- [ ] **Step 1: 简化标题栏**

保留 Codex 图标、`Codex` 标题、刷新和退出按钮，删除标题下方的“剩余用量”或倒计时文案。

- [ ] **Step 2: 合并两个额度到同一用量框**

视图层级固定为：

```text
usageCard
├── fiveHourRow
│   ├── 5 小时剩余 + 百分比
│   └── 下次重置 + 具体时刻
├── fiveHourProgress
└── weeklyRow
    ├── 本周剩余 + 百分比
    └── 下次重置 + 具体时刻
```

本周部分不添加独立底色、边框或分隔线。

- [ ] **Step 3: 应用独立状态色**

沿用现有阈值：

```text
remaining >= 50  -> 柔和绿色 #3F8F72
20 <= remaining < 50 -> 琥珀色 #BB7622
remaining < 20 -> 珊瑚红 #C95656
```

5 小时状态控制共享用量框的淡色背景、边框、主百分比和进度条；本周状态只控制本周百分比颜色。

- [ ] **Step 4: 替换重置时间文案**

两个重置区域统一显示 `下次重置`，数值使用 `ResetTimeFormatter.label(for:)`，不再只展示倒计时。

- [ ] **Step 5: 保持错误状态**

继续在用量框下方展示现有红色错误提示，不改变数据刷新和错误转换逻辑。

### Task 3: 收紧面板高度

**Files:**
- Modify: `Sources/AIUsageMonitor/MenuBarContentView.swift`
- Modify: `Sources/AIUsageMonitor/AppDelegate.swift`

- [ ] **Step 1: 调整 SwiftUI 基础高度**

正常状态从 228 缩短到与内容相符的高度，错误状态保留足够的错误提示空间；继续使用 0.9 显示缩放。

- [ ] **Step 2: 同步 NSPanel 尺寸**

`configurePanel()` 初始尺寸和 `togglePopover()` 动态尺寸必须与 SwiftUI 缩放后的高度一致，避免底部空白或裁切。

### Task 4: 验证

**Files:**
- Verify: `Sources/AIUsageMonitor/MenuBarContentView.swift`
- Verify: `Sources/AIUsageMonitor/AppDelegate.swift`
- Verify: `Sources/AIUsageMonitorCore/ResetTimeFormatter.swift`
- Verify: `Tests/AIUsageMonitorCoreTests/ResetTimeFormatterTests.swift`

- [ ] **Step 1: 运行完整测试**

Run: `swift test`

Expected: 所有 XCTest 通过，0 failures。

- [ ] **Step 2: 构建应用**

Run: `swift build`

Expected: 构建成功，无 Swift 编译错误。

- [ ] **Step 3: 检查改动范围**

Run: `git diff --check && git status --short`

Expected: 仅包含方案 B UI、重置时间格式化、测试、设计稿和本计划；无空白错误。

- [ ] **Step 4: 保留未提交状态**

本轮不自动提交，等待用户查看实际应用后再决定是否提交。
