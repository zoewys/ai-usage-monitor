# AI 剩余用量监控

macOS 菜单栏应用，用来显示 Codex 剩余用量。

P0 展示：

- `Codex 本周剩余` 百分比和重置时间
- `Codex 5 小时剩余` 百分比和重置时间
- 菜单栏标题显示 `Codex xx%`，取本周和 5 小时里较低的剩余值

## 环境要求

- macOS 14+
- Swift 5.9+
- Brave、Chrome 或 Edge 里已有登录的 ChatGPT 会话
- 已安装 Codex CLI，作为兜底读取方式

## 运行

```bash
swift run
```

## 测试

```bash
swift test
```

## 打包 `.app`

```bash
chmod +x scripts/build_app.sh
scripts/build_app.sh
open build/AIUsageMonitor.app
```

## 说明

应用会优先读取本机现有的 ChatGPT 浏览器会话，失败后再兜底使用 `codex app-server`。
应用不会保存 token、cookie 或 API key。
