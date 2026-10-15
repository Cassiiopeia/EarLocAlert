import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';

part 'app_database_provider.g.dart';

/// 앱 데이터베이스 하나 (docs/02-ARCHITECTURE.md)
///
/// DI 는 Riverpod 코드 생성으로 통일한다. 저장소 provider 는 각 기능의 data
/// 계층에 둔다 — core 가 features 를 알면 안 된다 (아키텍처 검수 #276).
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
