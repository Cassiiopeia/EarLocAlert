import 'package:flutter/material.dart';

import '../../domain/alert_direction.dart';
import 'app_semantic_colors.dart';

/// 알림 방향(도착·출발·둘 다)의 아이콘과 색 — 앱 전체에서 이것 하나로 정한다 (#276)
///
/// 카드·지도 원·알림 화면·장소 폼이 각자 색과 아이콘을 골라, 폼은 핀 아이콘인데
/// 카드는 문 아이콘이었다. 색만으로 구분하지 않는다 — 아이콘과 문구를 함께 쓴다
/// (색각 이상 대응, docs/06-UX.md).
extension AlertDirectionAppearance on AlertDirection {
  /// 도착은 핀, 출발은 나아가는 화살표, 둘 다는 오가는 화살표 (#272)
  IconData get outlinedIcon => switch (this) {
    AlertDirection.enter => Icons.where_to_vote_outlined,
    AlertDirection.exit => Icons.near_me_outlined,
    AlertDirection.both => Icons.sync_alt_outlined,
  };

  /// 도착(과 둘 다)은 주색, 출발은 금색 — 의미 색에서 고른다
  Color colorFrom(AppSemanticColors semantic) => switch (this) {
    AlertDirection.exit => semantic.alertExit,
    AlertDirection.enter || AlertDirection.both => semantic.alertEnter,
  };
}
