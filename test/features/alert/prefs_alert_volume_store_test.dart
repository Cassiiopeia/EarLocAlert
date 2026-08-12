import 'package:ear_loc_alert/features/alert/data/prefs_alert_volume_store.dart';
import 'package:ear_loc_alert/features/alert/domain/alert_effects.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 알림음 크기 설정 저장소 (이슈 #86)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PrefsAlertVolumeStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = PrefsAlertVolumeStore();
  });

  test('저장한 값이 그대로 돌아온다', () async {
    await store.save(0.3);
    expect(await store.volume(), 0.3);
  });

  test('저장된 값이 없으면 기본값이다', () async {
    expect(await store.volume(), AlertVolumeStore.defaultVolume);
  });

  test('범위 밖 값은 잘라서 저장한다 — 소리를 죽이거나 귀를 때리면 안 된다', () async {
    await store.save(1.7);
    expect(await store.volume(), 1.0);

    await store.save(-0.5);
    expect(await store.volume(), 0.0);
  });

  test('저장소에 손상된 값이 있어도 범위 안으로 돌아온다', () async {
    SharedPreferences.setMockInitialValues({'alert_volume.level': 42.0});
    expect(await store.volume(), 1.0);
  });
}
