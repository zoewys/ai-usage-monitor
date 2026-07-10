# DMG Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将当前方案 B UI 版本推送到 GitHub，并通过 `v0.1.2` tag 自动生成可下载的 macOS DMG。

**Architecture:** 保留现有 `.app` 和 ZIP 产物，新增独立 DMG 打包脚本，把应用和 `/Applications` 快捷方式放入压缩磁盘映像。GitHub Actions 在 tag 构建后生成 ZIP 和 DMG，并将二者发布到同一个 GitHub Release。

**Tech Stack:** Swift Package Manager、Bash、`hdiutil`、GitHub Actions、GitHub Releases

---

### Task 1: 新增 DMG 打包脚本

**Files:**
- Create: `scripts/build_dmg.sh`

- [ ] **Step 1: 校验版本参数和应用产物**

脚本接受 `0.1.2` 或 `v0.1.2`，统一去掉开头的 `v`；如果 `build/AIUsageMonitor.app` 不存在则直接失败，避免发布空镜像。

```bash
VERSION="${1:-${VERSION:-}}"
VERSION="${VERSION#v}"
APP_DIR="$ROOT_DIR/build/AIUsageMonitor.app"
[[ -n "$VERSION" ]]
[[ -d "$APP_DIR" ]]
```

- [ ] **Step 2: 创建拖放安装结构**

DMG 暂存目录包含应用和 Applications 快捷方式：

```bash
ditto "$APP_DIR" "$STAGE_DIR/AIUsageMonitor.app"
ln -s /Applications "$STAGE_DIR/Applications"
```

- [ ] **Step 3: 创建并校验 DMG**

```bash
hdiutil create -volname "AI Usage Monitor" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_PATH"
hdiutil verify "$DMG_PATH"
```

产物固定为 `build/releases/AIUsageMonitor-v0.1.2.dmg`。

### Task 2: 接入 GitHub Actions Release

**Files:**
- Modify: `.github/workflows/release.yml`
- Modify: `README.md`

- [ ] **Step 1: 构建 ZIP 和 DMG**

现有 `Build app` 后运行：

```bash
APP_ZIP="build/releases/AIUsageMonitor-${GITHUB_REF_NAME}.zip"
DMG_PATH="build/releases/AIUsageMonitor-${GITHUB_REF_NAME}.dmg"
mkdir -p build/releases
ditto -c -k --keepParent build/AIUsageMonitor.app "$APP_ZIP"
scripts/build_dmg.sh "${GITHUB_REF_NAME#v}"
```

- [ ] **Step 2: 上传两种产物**

`actions/upload-artifact@v4` 的 `path` 同时包含 `${{ env.APP_ZIP }}` 和 `${{ env.DMG_PATH }}`；`gh release create` 同时附加 ZIP 与 DMG。

- [ ] **Step 3: 更新发布文档**

README 说明 `v*` tag 会生成 ZIP 和 DMG，并给出 `v0.1.2` 发布命令。

### Task 3: 本地验证

**Files:**
- Verify: `scripts/build_dmg.sh`
- Verify: `.github/workflows/release.yml`

- [ ] **Step 1: 运行脚本语法检查**

Run: `bash -n scripts/build_app.sh scripts/build_dmg.sh`

Expected: exit 0。

- [ ] **Step 2: 运行测试与版本化构建**

Run: `swift test`

Run: `VERSION=0.1.2 BUILD_NUMBER=3 scripts/build_app.sh`

Expected: 所有测试通过，`Info.plist` 版本为 `0.1.2`。

- [ ] **Step 3: 构建并验证 DMG**

Run: `scripts/build_dmg.sh 0.1.2`

Run: `hdiutil verify build/releases/AIUsageMonitor-v0.1.2.dmg`

Expected: DMG 校验成功，镜像中包含 `AIUsageMonitor.app` 和 `Applications` 快捷方式。

### Task 4: 提交和远端发布

**Files:**
- Commit: 当前 UI、测试、设计稿、计划和 DMG 发布文件

- [ ] **Step 1: 展示提交方案**

提交前展示完整变更摘要、无需 changeset 的判断以及 commit message，等待用户确认。

- [ ] **Step 2: 提交并推送 main**

```bash
git add .
git commit -m "feat: ship redesigned usage monitor with dmg release"
git push origin main
```

- [ ] **Step 3: 创建并推送新 tag**

```bash
git tag -a v0.1.2 -m "v0.1.2"
git push origin v0.1.2
```

- [ ] **Step 4: 验证 GitHub Release**

确认 tag workflow 结论为 success，Release `v0.1.2` 中存在 `AIUsageMonitor-v0.1.2.dmg`，下载后再次运行 `hdiutil verify`。
