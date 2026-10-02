# EarLocAlert

[English](README.md) · [한국어](README.ko.md) · [日本語](README.ja.md) · **简体中文**

[![Flutter](https://img.shields.io/badge/Flutter-3.35.5-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)](https://flutter.dev/multi-platform)
[![License](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-blue.svg)](LICENSE)

**耳机位置提醒: 安静提醒你的位置通知应用**

到达目的地或离开某个地点时，不打扰身边的人，也能确保你收到提醒。

<p align="center">
  <img src="docs/images/home-en.webp" alt="地图主页: 已保存的地点和监控状态 (英文界面)" width="220">
  &nbsp;
  <img src="docs/images/add-place-en.webp" alt="添加地点: 仅在连接耳机时发出声音 (英文界面)" width="220">
  &nbsp;
  <img src="docs/images/alert-en.webp" alt="到达提醒: 一个大按钮即可关闭 (英文界面)" width="220">
</p>

---

## 你是否遇到过

- 在班车上打了个盹，错过了要下的站
- 在图书馆或办公室里闹钟响了，尴尬不已
- 明明戴着耳机，提醒却从**扬声器**里响了出来

## 工作方式

```
已连接耳机 (蓝牙、有线或 USB-C)  →  仅通过耳机播放声音
未连接                          →  仅振动。扬声器保持静音
```

**无论任何情况，应用都不会通过设备扬声器发出声音。** 这正是这个应用存在的理由。

| 功能 | 说明 |
|---|---|
| 添加地点 | 在地图上选点，设置名称、半径 (50 米至 2 公里) 和提醒类型 |
| 后台监控 | 无需一直打开应用 |
| 到达 / 离开提醒 | 到达时、离开时，或两者都提醒 |
| 安静提醒 | 持续重复振动，直到你关闭 |
| 自动检测耳机 | 在提醒触发的瞬间确认连接状态 |
| 本地存储 | **位置信息不会离开你的设备** |
| 支持语言 | 中文、英语、韩语、日语 |

---

## 开发状态

应用功能已全部实现，正在准备在 Google Play 上架。尚未正式发布。进度详情见 [11-ROADMAP](docs/11-ROADMAP.md) (韩语)。

---

## 技术栈

| 领域 | 使用 |
|---|---|
| 框架 | Flutter 3.35.5 / Dart 3.9+ |
| 状态管理 | Riverpod (code generation) |
| 路由 | go_router |
| 模型 | Freezed + json_serializable |
| 本地存储 | Drift (SQLite) |
| 地图 | Google Maps |
| 定位 | geolocator + 平台地理围栏 |
| 音频 | audio_session + just_audio |
| 广告 | Google Mobile Ads |

## 支持的平台

- Android 8.0 (API 26) 及以上
- iOS 13.0 及以上

> **各平台的行为不同。** Android 通过前台服务精确监控，iOS 则交给系统的地理围栏处理。iOS 最多监控 20 个地点，到达检测可能有延迟 → [05-PLATFORM](docs/05-PLATFORM.md) (韩语)

---

## 开发

```bash
flutter pub get      # 安装依赖
dart format .        # 格式化
flutter test         # 测试
flutter run          # 运行
```

构建与发布由 GitHub Actions 处理。`docs/` 中的设计文档为韩语。建议先阅读 [01-REQUIREMENTS](docs/01-REQUIREMENTS.md)，以及记录各项决定原因的 [10-DECISIONS](docs/10-DECISIONS.md)。

提交 Pull Request 前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。版本历史见 [CHANGELOG.md](CHANGELOG.md)。

---

## 隐私

- **位置信息仅保存在设备上，不会发送到任何地方**
- 广告标识符由广告提供方 (Google AdMob) 收集
- 无需注册，也不收集账号信息

详情: [09-RELEASE](docs/09-RELEASE.md) (韩语)

---

## 许可证

本仓库为**源码公开 (source-available)**，并非 OSI 认证的开源许可证。

[PolyForm Noncommercial 1.0.0](LICENSE): 阅读、学习、修改和 fork 仅限**非商业用途**。不允许商业使用 (应用商店分发、付费服务、广告变现等)。

公开源码是为了让任何人都能验证本应用不会把位置信息发送到设备之外 → [NOTICE](NOTICE)

## 联系方式

- 开发者: Cassiiopeia
- Issues: [GitHub Issues](https://github.com/Cassiiopeia/EarLocAlert/issues)
- 安全问题: 请见 [SECURITY.md](SECURITY.md)
