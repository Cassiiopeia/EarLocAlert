/// 프로 안내 시트를 연 자리 > 강조할 혜택 + 로그 이름 (#366)
enum ProOfferEntry {
  placeAdd('place_add', ProOfferHighlight.places),
  placeSave('place_save', ProOfferHighlight.places),
  placeList('place_list', ProOfferHighlight.places),
  homeChip('home_chip', ProOfferHighlight.general),
  settingsCard('settings_card', ProOfferHighlight.general),
  soundPicker('sound_picker', ProOfferHighlight.sounds),
  vibrationPattern('vibration_pattern', ProOfferHighlight.vibrationPatterns),
  history('history', ProOfferHighlight.history),
  routines('routines', ProOfferHighlight.routines),
  backup('backup', ProOfferHighlight.backup);

  const ProOfferEntry(this.logName, this.highlight);

  /// Diagnostics 로그용 고정 토큰
  final String logName;

  /// 시트 제목과 비교표 강조 줄
  final ProOfferHighlight highlight;

  /// 결제 뒤 막혔던 장소 추가를 이어가야 하는 자리인가
  bool get shouldContinuePlaceAdd => this == placeAdd || this == placeList;
}

/// 시트에서 앞세울 혜택 7종. general = 특정 기능 없이 전체 소개
enum ProOfferHighlight {
  general,
  places,
  sounds,
  vibrationPatterns,
  history,
  routines,
  backup,
}
