# AI 剩余用量监控

macOS 菜单栏应用，用来显示 Codex 剩余用量。

P0 展示：

- `Codex 本周剩余` 百分比和重置时间
- `Codex 5 小时剩余` 百分比和重置时间
- 菜单栏标题显示 `Codex: 5 小时剩余 / 本周剩余`

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

## 发布

推送 `v*` tag 会触发 GitHub Actions 打包，并生成包含 ZIP 和 DMG 的 GitHub Release。普通用户可以下载 DMG，打开后将应用拖入 Applications：

```bash
git push origin main
git tag -a v0.1.2 -m "v0.1.2"
git push origin v0.1.2
```

## 说明

应用会优先读取本机现有的 ChatGPT 浏览器会话，失败后再兜底使用 `codex app-server`。
应用不会保存 token、cookie 或 API key。
