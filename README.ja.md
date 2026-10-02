# EarLocAlert

[English](README.md) · [한국어](README.ko.md) · **日本語** · [简体中文](README.zh-CN.md)

[![Flutter](https://img.shields.io/badge/Flutter-3.35.5-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)](https://flutter.dev/multi-platform)
[![License](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-blue.svg)](LICENSE)

**イヤホン位置通知: 静かに知らせる、位置情報ベースの通知アプリ**

目的地に着いたとき、またはある場所を離れたとき、周りの人の迷惑にならずに、確実にお知らせします。

<p align="center">
  <img src="docs/images/home-en.webp" alt="マップのホーム画面: 登録した場所と監視状態 (英語表示)" width="260">
  &nbsp;&nbsp;
  <img src="docs/images/add-place-en.webp" alt="場所の登録: イヤホン接続時のみ音が鳴る (英語表示)" width="260">
</p>

---

## こんな経験はありませんか

- シャトルバスでうたた寝して、降りる場所を過ぎてしまった
- 図書館やオフィスでアラームが鳴って気まずかった
- イヤホンをしているのに、通知が**スピーカー**から鳴ってしまった

## 基本の動作

```
イヤホン (Bluetooth・有線・USB-C) が接続されている  →  イヤホンからのみ音を再生
接続されていない                                    →  バイブレーションのみ。スピーカーは無音
```

**端末のスピーカーからは、どんな場合も音を出しません。** これがこのアプリの存在理由です。

| 機能 | 説明 |
|---|---|
| 場所の登録 | 地図で場所を選び、名前・半径 (50m〜2km)・通知タイプを設定 |
| バックグラウンド監視 | アプリを開いたままにしなくても動作 |
| 到着 / 出発の通知 | 到着したとき、出発したとき、またはその両方 |
| 静かな通知 | 解除するまでバイブレーションを繰り返す |
| イヤホンの自動検出 | 通知が鳴る瞬間に接続状態を確認 |
| ローカル保存 | **位置情報は端末の外に出ません** |
| 対応言語 | 日本語、英語、韓国語、中国語 |

---

## 開発状況

アプリの機能はすべて実装済みで、Google Play での公開を準備中です。正式リリースはまだです。進捗の詳細は [11-ROADMAP](docs/11-ROADMAP.md) (韓国語) をご覧ください。

---

## 技術スタック

| 領域 | 使用技術 |
|---|---|
| フレームワーク | Flutter 3.35.5 / Dart 3.9+ |
| 状態管理 | Riverpod (code generation) |
| ルーティング | go_router |
| モデル | Freezed + json_serializable |
| ローカル保存 | Drift (SQLite) |
| 地図 | Google Maps |
| 位置情報 | geolocator + プラットフォームのジオフェンス |
| オーディオ | audio_session + just_audio |
| 広告 | Google Mobile Ads |

## 対応環境

- Android 8.0 (API 26) 以上
- iOS 13.0 以上

> **プラットフォームごとに動作が異なります。** Android はフォアグラウンドサービスで精密に監視し、iOS は OS のジオフェンスに任せます。iOS は監視地点が 20 件までに制限され、到着の検出が遅れることがあります → [05-PLATFORM](docs/05-PLATFORM.md) (韓国語)

---

## 開発

```bash
flutter pub get      # 依存関係のインストール
dart format .        # フォーマット
flutter test         # テスト
flutter run          # 実行
```

ビルドとリリースは GitHub Actions が処理します。`docs/` の設計ドキュメントは韓国語です。まず [01-REQUIREMENTS](docs/01-REQUIREMENTS.md) と、理由を記録した [10-DECISIONS](docs/10-DECISIONS.md) をご覧ください。

プルリクエストの前に [CONTRIBUTING.md](CONTRIBUTING.md) をお読みください。変更履歴は [CHANGELOG.md](CHANGELOG.md) にあります。

---

## プライバシー

- **位置情報は端末内にのみ保存され、外部に送信されません**
- 広告 ID は広告提供事業者 (Google AdMob) が収集します
- 会員登録はなく、アカウント情報も収集しません

詳細: [09-RELEASE](docs/09-RELEASE.md) (韓国語)

---

## ライセンス

このリポジトリは**ソース公開 (source-available)** です。OSI 承認のオープンソースライセンスではありません。

[PolyForm Noncommercial 1.0.0](LICENSE): 閲覧・学習・改変・フォークは**非商用目的**に限り許可されます。商用利用 (ストア配布、有料サービス、広告収益化など) は許可されません。

ソースを公開しているのは、このアプリが位置情報を端末の外に送信していないことを誰でも確認できるようにするためです → [NOTICE](NOTICE)

## お問い合わせ

- 開発者: Cassiiopeia
- Issues: [GitHub Issues](https://github.com/Cassiiopeia/EarLocAlert/issues)
- セキュリティ報告: [SECURITY.md](SECURITY.md) をご覧ください
