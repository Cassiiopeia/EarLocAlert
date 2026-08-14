import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/background/watch_engine_entrypoint.dart' as watch_engine;

void main() {
  // Riverpod 으로 통일한다 — get_it 을 병행하지 않는다
  // (docs/02-ARCHITECTURE.md)
  runApp(const ProviderScope(child: EarLocAlertApp()));
}

/// 감시 서비스가 띄우는 엔진의 진입점 (이슈 #93)
///
/// **왜 `main.dart` 에 있나** — 네이티브는 이 함수를 라이브러리 경로와
/// 이름으로 찾는다(`WatchEngine.kt`). 그런데 Dart 컴파일러는 **어떤
/// 진입점에서도 도달할 수 없는 라이브러리를 번들에서 통째로 제외한다.**
/// `@pragma('vm:entry-point')` 는 함수가 트리셰이킹되는 것을 막을 뿐,
/// 라이브러리가 애초에 포함되지 않는 것은 막지 못한다.
///
/// 실제로 구현 파일에 직접 두었더니 엔진 부팅이 이렇게 실패했다:
///
/// ```
/// Dart_LookupLibrary: library '...watch_engine_entrypoint.dart' not found
/// Could not create root isolate
/// ```
///
/// 증상은 **"지오펜스 이벤트는 받는데 판정이 하나도 안 도는 것"** 이라
/// 원인을 찾기 어렵다. `main.dart` 는 항상 번들에 있으므로 여기 두고,
/// 실제 구현은 `watch_engine_entrypoint.dart` 에 그대로 둔다 — 이 파일이
/// import 되므로 그쪽 라이브러리도 함께 살아난다.
@pragma('vm:entry-point')
void watchEngineMain() => watch_engine.watchEngineMain();
