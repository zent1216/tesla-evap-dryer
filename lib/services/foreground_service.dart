import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// 에바포레이터 건조 중 알림바 표시 + 배터리 최적화 방지
class EvapForegroundService {
  static bool _initialized = false;

  // ── 초기화 (앱 시작 시 1회) ─────────────────────────────────
  static void init() {
    if (_initialized) return;
    _initialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'evap_dryer_channel',
        channelName: '에바포레이터 건조',
        channelDescription: '에바포레이터 건조 진행 상황을 표시합니다.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.drawable,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher', // mipmap/ic_launcher 대체
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,        // ★ CPU Wake Lock
        allowWifiLock: false,
      ),
    );
  }

  // ── 배터리 최적화 제외 요청 ────────────────────────────────
  /// 이미 제외되어 있으면 false 반환 (아무 것도 안 함)
  /// 아직 아니라면 시스템 팝업 띄우고 true 반환
  static Future<bool> requestBatteryOptimizationExemption() async {
    final ignored =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (ignored) return false; // 이미 제외됨

    await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    return true;
  }

  // ── 서비스 시작 (건조 시작 시) ────────────────────────────
  static Future<void> start({required int totalSeconds}) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }

    final min = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;

    await FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: '💨 에바포레이터 건조 중',
      notificationText:
          '$min:${sec.toString().padLeft(2, '0')} 남음 · 완료까지 잠시 기다려주세요',
      callback: _serviceCallback,
    );
  }

  // ── 알림 업데이트 (1초마다) ───────────────────────────────
  static Future<void> update(int remainingSeconds) async {
    if (!await FlutterForegroundTask.isRunningService) return;

    final min = remainingSeconds ~/ 60;
    final sec = remainingSeconds % 60;
    final timeStr = '$min:${sec.toString().padLeft(2, '0')}';

    await FlutterForegroundTask.updateService(
      notificationTitle: '💨 에바포레이터 건조 중',
      notificationText: '$timeStr 남음',
    );
  }

  // ── 서비스 종료 (건조 완료 / 중단 시) ─────────────────────
  static Future<void> stop({bool completed = true}) async {
    if (!await FlutterForegroundTask.isRunningService) return;

    if (completed) {
      // 완료 알림으로 업데이트 후 잠깐 유지
      await FlutterForegroundTask.updateService(
        notificationTitle: '✅ 에바포레이터 건조 완료',
        notificationText: '에어컨 냄새 방지 완료!',
      );
      await Future.delayed(const Duration(seconds: 3));
    }

    await FlutterForegroundTask.stopService();
  }
}

// 포그라운드 서비스 콜백 (격리된 스레드에서 실행, 아무 작업 없음)
// 건조 타이머는 Flutter UI 스레드에서 관리하므로 여기선 비워둠
@pragma('vm:entry-point')
void _serviceCallback() {
  FlutterForegroundTask.setTaskHandler(_NoOpHandler());
}

class _NoOpHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
