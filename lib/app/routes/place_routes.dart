part of '../router.dart';

// 장소 등록·편집·지도 선택 라우트와 폼 이탈 처리

/// 지도 위치 선택 라우트 — 검색 서비스를 조립해 내려준다 (issue #72).
class _MapPickerRoute extends ConsumerWidget {
  const _MapPickerRoute({required this.args});

  final MapPickArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaceMapPickerScreen(
      // 플랫폼 구현은 app 이 넣는다 — 화면은 인터페이스만 안다 (규칙 3)
      locationService: const CurrentLocationChannel(),
      args: args,
      searchService: ref.watch(placeSearchServiceProvider),
      onPicked: (result) => context.pop(result),
    );
  }
}

/// 지도 화면을 열고 선택 결과를 기다린다.
///
/// 폼은 `Navigator`·`GoRouter` 를 직접 만지지 않는다 — 화면 전환은 전부
/// 여기서 조율한다 (docs/02-ARCHITECTURE.md).
/// 장소 등록·편집 화면의 배선 (이슈 #121)
///
/// **폼이 `sounds` 를 직접 import 하지 않게 하는 자리다** (규칙 1).
/// 알림음 시트를 열고 이름을 조회하는 일을 여기서 이어붙인다 —
/// 설정 화면(`_SettingsRoute`)이 시트와 provider 를 잇는 것과 같은 방식이다.
class _PlaceFormRoute extends ConsumerWidget {
  const _PlaceFormRoute({this.existing});

  /// null 이면 신규 등록
  final AlertPlace? existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaceFormScreen(
      existing: existing,
      // 저장 뒤 바로 나간다 — 워치 안내는 설정에서만 연다 (이슈 #304)
      onSaved: () => _leaveForm(context),
      onPlaceLimitReached: () => _onPlaceLimitReached(context, ref),
      onDeleted: () => _leaveForm(context),
      onPickOnMap: (args) => _pickOnMap(context, args),
      // 무료는 기본음 외 잠금 (#294) — 기존에 고른 음은 그대로 유지
      onPickSound: (current) => showSoundPickerSheet(
        context,
        current: current,
        onUnlockPro: () =>
            unawaited(showProOfferSheet(context, entryPoint: 'sound_picker')),
      ),
      onDescribeSound: (sound) => _describeSound(ref, sound, context.l10n),
      // 장소별 진동 패턴 (#311) — 무료는 기본만, 이미 고른 패턴은 그대로 유지
      onPickVibrationPattern: (current) async {
        final choice = await showVibrationPatternSheet(
          context,
          current: current,
          allowFollowDefault: true,
          onUnlockPro: () => unawaited(
            showProOfferSheet(context, entryPoint: 'vibration_pattern'),
          ),
        );
        return choice == null ? null : (pattern: choice.pattern);
      },
    );
  }
}

/// 알림음의 표시 이름.
///
/// 사용자 음원은 저장소에서 파일명을 읽는다. **행이 없으면 지워진
/// 음원이다** — 그 사실을 숨기지 않는다. 실제 알림은 기본음으로 울리므로
/// 소리가 안 나지는 않지만, 사용자는 자기가 고른 것이 사라졌음을
/// 알아야 다시 고를 수 있다.
Future<String> _describeSound(
  WidgetRef ref,
  AlertSound sound,
  AppLocalizations l10n,
) async {
  switch (sound) {
    case PresetSound(:final preset):
      return preset.localizedLabel(l10n);
    case CustomSoundRef(:final id):
      final found = await ref.read(customSoundRepositoryProvider).findById(id);
      return found?.displayName ?? l10n.routeDeletedSound;
  }
}

Future<MapPickResult?> _pickOnMap(BuildContext context, MapPickArgs args) {
  return context.push<MapPickResult>(AppRoutes.placeMap, extra: args);
}

/// 홈에서 `push` 로 들어왔으면 `pop` 이 자연스럽다 — 스택이 유지되어
/// 뒤로가기 동작과 결과가 같다.
///
/// **`canPop` 을 확인하는 이유** — 딥링크나 알림 탭처럼 스택 없이 이 화면에
/// 바로 진입하는 경로가 있다. 그때 `pop` 하면 갈 곳이 없어 아무 일도
/// 일어나지 않고, 사용자는 저장했는데 화면이 그대로인 상태에 갇힌다.
/// 그것이 정확히 이 이슈에서 고치려는 증상이다.
void _leaveForm(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.home);
  }
}
