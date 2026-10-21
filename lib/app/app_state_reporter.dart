import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/build_info.dart';
import '../core/config/dev_flag.dart';
import '../core/domain/alert_schedule.dart';
import '../core/text/two_digits.dart';
import '../features/geofence/data/geofence_event_repository_provider.dart';
import '../features/geofence/data/geofence_state_repository_provider.dart';
import '../features/geofence/domain/geofence_event_repository.dart';
import '../features/geofence/domain/geofence_state.dart';
import '../features/geofence/domain/geofence_state_repository.dart';
import '../features/permission/data/ios_notification_settings_channel.dart';
import '../features/permission/data/permission_providers.dart';
import '../features/permission/domain/permission_kind.dart';
import '../features/permission/domain/permission_service.dart';
import '../features/places/data/place_repository_provider.dart';
import '../features/places/domain/alert_place.dart';
import '../features/places/domain/place_repository.dart';

part 'app_state_reporter.g.dart';

@Riverpod(keepAlive: true)
AppStateReporter appStateReporter(Ref ref) => AppStateReporter(
  places: ref.watch(placeRepositoryProvider),
  geofenceStates: ref.watch(geofenceStateRepositoryProvider),
  geofenceEvents: ref.watch(geofenceEventRepositoryProvider),
  permissions: ref.watch(permissionServiceProvider),
);

/// 디버그 보고서의 앱 상태 구역: 여러 기능의 현재 값을 한 텍스트로 (이슈 #290)
/// 구역 7개: 앱, 권한, iOS 알림 설정, 장소·판정 상태, 최근 진입·이탈, 저장된 설정, 네이티브
///
/// 기능끼리 직접 import 하지 않도록 app 계층이 모은다 (CLAUDE.md 규칙 4).
/// 구역 하나가 실패해도 나머지는 그대로 나오고, 실패 사유가 그 자리에 남는다.
class AppStateReporter {
  AppStateReporter({
    required PlaceRepository places,
    required GeofenceStateRepository geofenceStates,
    required GeofenceEventRepository geofenceEvents,
    required PermissionService permissions,
  }) : _places = places,
       _geofenceStates = geofenceStates,
       _geofenceEvents = geofenceEvents,
       _permissions = permissions;

  final PlaceRepository _places;
  final GeofenceStateRepository _geofenceStates;
  final GeofenceEventRepository _geofenceEvents;
  final PermissionService _permissions;

  // 최근 진입·이탈 기록 건수 (보관 기간 안 최신순)
  static const recentEventLimit = 100;

  /// 전체 구역 수집 > `[구역]` 머리 + `key=value` 줄
  Future<String> collect() async {
    final placeNameById = <String, String>{};
    final sections = <String, Future<List<String>> Function()>{
      'app': _app,
      'permissions': _permissionLines,
      'ios_notification_settings': _iosNotificationSettings,
      'places': () => _placeLines(placeNameById),
      'recent_geofence_events': () => _recentEvents(placeNameById),
      'preferences': _preferences,
      'native': () async => [await BuildInfo.readNativeSnapshot()],
    };
    final buffer = StringBuffer();
    for (final MapEntry(key: name, value: collectSection) in sections.entries) {
      buffer.writeln('[$name]');
      try {
        for (final line in await collectSection()) {
          buffer.writeln(line);
        }
      } on Object catch (error) {
        buffer.writeln('unavailable error=$error');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  Future<List<String>> _app() async {
    final now = DateTime.now();
    return [
      'version=${BuildInfo.label} dev_build=${DevFlag.isDevBuild}',
      'os=${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'dart_locale=${Platform.localeName}',
      'time_zone=${now.timeZoneName} offset=${now.timeZoneOffset}',
    ];
  }

  /// 권한 6종 + 판정 결과 (홈 경고가 쓰는 값과 같은 기준)
  Future<List<String>> _permissionLines() async {
    final snapshot = await _permissions.check();
    return [
      for (final kind in PermissionKind.values)
        '${kind.name}=${snapshot.statusOf(kind).name}',
      'can_monitor_in_background=${snapshot.canMonitorInBackground} '
          'can_notify=${snapshot.canNotify} '
          'can_alert_reliably=${snapshot.canAlertReliably}',
    ];
  }

  Future<List<String>> _iosNotificationSettings() async {
    if (!Platform.isIOS) return ['n/a(not ios)'];
    final settings = await const IosNotificationSettingsChannel().read();
    return [
      'authorization=${settings.authorization.name} '
          'lock_screen=${settings.lockScreen.name} '
          'alert=${settings.alert.name} '
          'notification_center=${settings.notificationCenter.name} '
          'sound=${settings.sound.name} '
          'time_sensitive=${settings.timeSensitive.name}',
    ];
  }

  /// 장소 전체 설정 + 장소별 판정 상태 (이름표는 아래 기록 구역이 재사용)
  Future<List<String>> _placeLines(Map<String, String> placeNameById) async {
    final places = await _places.findAll();
    final states = await _geofenceStates.allStates();
    placeNameById.addAll({for (final place in places) place.id: place.name});
    return [
      'count=${places.length} enabled=${places.where((p) => p.enabled).length}',
      for (final place in places)
        _placeLine(place, states[place.id] ?? GeofenceState.unknown),
    ];
  }

  String _placeLine(AlertPlace place, GeofenceState state) =>
      'id=${place.id} name="${place.name}" '
      'lat=${place.latitude} lng=${place.longitude} '
      'radius=${place.radiusMeters}m direction=${place.direction.name} '
      'enabled=${place.enabled} state=${state.name} '
      'sound_enabled=${place.soundEnabled} sound=${place.sound.storageValue} '
      'schedules=${_schedulesText(place.schedules)} '
      'created=${place.createdAt.toUtc().toIso8601String()}';

  /// `[1,2,3 07:00-09:30]` 요일(ISO 1=월)·시작·끝, 없으면 always
  String _schedulesText(List<AlertSchedule> schedules) {
    if (schedules.isEmpty) return 'always';
    return schedules
        .map(
          (schedule) =>
              '[${(schedule.daysOfWeek.toList()..sort()).join(',')} '
              '${_minuteText(schedule.startMinuteOfDay)}-'
              '${_minuteText(schedule.endMinuteOfDay)}]',
        )
        .join(' ');
  }

  String _minuteText(int minuteOfDay) =>
      '${twoDigits(minuteOfDay ~/ 60)}:${twoDigits(minuteOfDay % 60)}';

  Future<List<String>> _recentEvents(Map<String, String> placeNameById) async {
    final events = await _geofenceEvents.findRecent(limit: recentEventLimit);
    return [
      'count=${events.length} (newest first, limit=$recentEventLimit)',
      for (final event in events)
        'at=${event.occurredAt.toUtc().toIso8601String()} '
            'type=${event.type.name} place="${placeNameById[event.placeId] ?? '?'}" '
            'place_id=${event.placeId} lat=${event.latitude} '
            'lng=${event.longitude} accuracy=${event.accuracyMeters.round()}m '
            'notified=${event.notified}',
    ];
  }

  /// 저장된 설정 전체 (대기 알림·화면 모드·언어·진동 세기 등).
  /// reload: 백그라운드 isolate 가 쓴 값까지 다시 읽음
  Future<List<String>> _preferences() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final keys = preferences.getKeys().toList()..sort();
    return [
      'count=${keys.length}',
      for (final key in keys) '$key=${preferences.get(key)}',
    ];
  }
}
