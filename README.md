# 提词器（iPhone 原生相机版）

一个能在 **苹果系统「相机」App 上悬浮提词**的 iPhone 应用。

## 它是怎么做到「原生相机 + 提词」的

iOS 不允许第三方 App 往别的 App 上画普通悬浮窗，唯一的合法通道是系统「画中画」（Picture in Picture）。

所以这个 App 的做法是：

1. 把台词预先渲染成一段「匀速向上滚动」的竖屏视频（720×1280，30fps）
2. 用 `AVPlayerLayer` + `AVPictureInPictureController` 把这段视频送进系统画中画
3. 画中画窗口浮在所有 App 最上层——包括系统「相机」
4. 因为它是系统级浮窗，**不会出现在你录下的画面里，也不影响画质**

代价（系统限制，无法绕过）：画中画窗口里不能放自定义按钮，只能用它自带的播放/暂停。所以 App 里额外做了「3 秒后开始」倒计时，方便你切到相机后再开始念。

## 功能

- 台词管理：新建 / 编辑 / 删除，本地保存
- 字号 26–88pt、行距、左对齐 / 居中
- 滚动速度 15–160 pt/s，拍摄中还能 0.5x–2x 实时变速
- 背景色：纯黑 / 深灰 / 深蓝
- 水平镜像（配分光镜提词器硬件时用）
- 3 秒倒计时开始、一键回到开头
- 按 iPhone 12 Pro Max（6.7 英寸）调的默认字号和浮窗比例

## 编译（Windows 也能做，不花钱）

代码本身是纯 Swift + SwiftUI + AVKit，没有任何第三方依赖。

### 方式 A：GitHub Actions 云端编译（推荐，不需要 Mac）

1. 注册 / 登录 GitHub
2. 新建一个仓库（Public 或 Private 都行，Public 不消耗额度）
3. 把本目录下**所有文件**（包括 `.github` 文件夹）上传到仓库根目录
   - 网页上传：`Add file` → `Upload files`，把解压后的内容整体拖进去
   - 注意 `.github` 是隐藏文件夹，Windows 资源管理器要开启「显示隐藏项目」
4. 上传后会自动触发构建；也可以手动：仓库 → `Actions` → `Build Unsigned IPA` → `Run workflow`
5. 等 5–8 分钟，进入这次运行，页面底部 `Artifacts` 里下载 `Teleprompter-ipa`
6. 解压得到 `Teleprompter.ipa`

### 方式 B：有 Mac 的话

```bash
brew install xcodegen
xcodegen generate
open Teleprompter.xcodeproj
# Xcode 里选自己的 Apple ID 团队，直接 Run 到手机
```

## 安装到 iPhone（Windows + Sideloadly）

1. Windows 上装 [Sideloadly](https://sideloadly.io/) 和 iTunes（或 Apple Devices，提供驱动）
2. 用数据线连 iPhone，手机上点「信任此电脑」
3. Sideloadly 里：
   - `IPA` 选刚下载的 `Teleprompter.ipa`
   - `Apple ID` 填你的 Apple ID（建议先去 appleid.apple.com 生成一个**App 专用密码**填进去，比直接填密码稳）
   - 点 `Start`，输入密码
4. 手机上：设置 → 通用 → VPN 与设备管理 → 信任你的开发者证书
5. 打开 App

### 能用多久

- **免费 Apple ID**：签名有效期 **7 天**。到期 App 打不开，重新用 Sideloadly 签一次即可（不用删 App，稿子会保留）
- 免费 Apple ID 限制：最多同时 3 个自签 App
- **付费开发者账号**（$99/年 ≈ ¥688）：签名 **1 年**，到期重签一次
- iOS 26.3 用不了 TrollStore，所以没有「永久免签」这条路

## 使用方法

1. App 里点进一段台词（示例台词可以先删掉）
2. 点 **「浮到相机上」**，提词窗口浮起
3. 回桌面，打开系统 **「相机」**
4. 浮窗会盖在取景框上方，可以单指拖动位置、双指缩放大小
5. 点浮窗里的播放键开始滚；或者在 App 里点 **「3 秒后开始」**，倒计时结束后切到相机正好开始

### 拍摄中怎么手动控制

- **浮窗上**：点一下会出现系统自带的暂停键和 ±15 秒。苹果把画中画窗口的触摸完全接管了，第三方 App 不能在里面加手势或按钮，所以「在浮窗上滑动」做不到。
- **App 里**：上下滑动预览区可以快进 / 回退，也可以直接拖进度条，或者用「后退 5s / 前进 5s」按钮。
- **拍摄时（App 已在后台）**：按 AirPods、蓝牙耳机或线控耳机的播放/暂停键 → 暂停或继续；切歌键 → 前后跳 5 秒。这条是唯一能「不看屏幕、不碰手机」控制的方式。

## 已知限制

- 画中画窗口尺寸有限，最大约屏幕 1/3，字号太小会看不清——建议 44pt 以上
- 画中画里不能放自定义控件（苹果限制）
- 台词改动或设置改动后，进入提词页会重新渲染一次（一般 1–3 秒，长稿会久一点）
- 如果 App 切到后台后浮窗被系统收回，检查：设置 → 通用 → 后台 App 刷新 是否给本 App 开了权限

## 目录结构

```
project.yml                      XcodeGen 工程定义
Support/Info.plist               构建时生成
Teleprompter/
  App/TeleprompterApp.swift      入口
  Models/ScriptItem.swift        台词模型
  Store/ScriptStore.swift        本地持久化
  Store/PrompterSettings.swift   排版与滚动设置
  PiP/PrompterMovieBuilder.swift 台词渲染成滚动视频
  PiP/PiPController.swift        画中画控制
  PiP/KeepAliveAudio.swift       后台保活
  Views/                         界面
.github/workflows/build.yml      云端编译
```
