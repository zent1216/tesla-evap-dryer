import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../main.dart';
import '../services/tesla_service.dart';
import '../services/foreground_service.dart';
import '../config.dart';

enum EvapState { idle, cooldown, waking, startingClimate, settingMax, drying, finishing, done }

class EvapDryerCard extends StatefulWidget {
  const EvapDryerCard({super.key});

  @override
  State<EvapDryerCard> createState() => _EvapDryerCardState();
}

class _EvapDryerCardState extends State<EvapDryerCard>
    with SingleTickerProviderStateMixin {
  EvapState _state = EvapState.idle;
  int _remaining = TeslaConfig.evapDryDurationSeconds;
  Timer? _dryTimer;
  Timer? _cooldownTick;  // 쿨다운 남은시간 UI 갱신용
  late AnimationController _pulseCtrl;

  // ── 쿨다운 ──────────────────────────────────────────────
  static const _prefLastRun  = 'evap_last_run';
  static const _prefCooldown = 'evap_cooldown_hours';
  static const _cooldownOptions = [6, 12, 24, 48]; // 선택 가능한 시간(h)

  DateTime? _lastRunAt;
  int _cooldownHours = 24; // 기본값 24시간

  Duration get _cooldownDuration => Duration(hours: _cooldownHours);

  // 쿨다운 남은 시간 (음수면 쿨다운 끝)
  Duration get _cooldownLeft {
    if (_lastRunAt == null) return Duration.zero;
    final elapsed = DateTime.now().difference(_lastRunAt!);
    final left = _cooldownDuration - elapsed;
    return left > Duration.zero ? left : Duration.zero;
  }

  bool get _inCooldown => _cooldownLeft > Duration.zero;

  String get _cooldownLeftLabel {
    final d = _cooldownLeft;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '$h시간 $m분 후 사용 가능';
    return '$m분 후 사용 가능';
  }

  // ── 초기화 ───────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRunMs = prefs.getInt(_prefLastRun);
    final savedCooldown = prefs.getInt(_prefCooldown);
    if (!mounted) return;
    setState(() {
      if (lastRunMs != null) {
        _lastRunAt = DateTime.fromMillisecondsSinceEpoch(lastRunMs);
      }
      _cooldownHours = savedCooldown ?? 24;
      if (_inCooldown) _startCooldownTick();
    });
  }

  Future<void> _saveLastRun() async {
    _lastRunAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefLastRun, _lastRunAt!.millisecondsSinceEpoch);
  }

  Future<void> _saveCooldownHours(int hours) async {
    _cooldownHours = hours;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefCooldown, hours);
  }

  // 쿨다운 중 UI 매 분 갱신
  void _startCooldownTick() {
    _cooldownTick?.cancel();
    _cooldownTick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_inCooldown) _cooldownTick?.cancel();
    });
  }

  @override
  void dispose() {
    _dryTimer?.cancel();
    _cooldownTick?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  bool get _running =>
      _state != EvapState.idle &&
      _state != EvapState.done &&
      _state != EvapState.cooldown;

  String get _stateLabel {
    switch (_state) {
      case EvapState.waking:          return '차량 깨우는 중...';
      case EvapState.startingClimate: return '에어컨 시스템 시작 중...';
      case EvapState.settingMax:      return 'Max Defrost + 최고 온도 설정 중...';
      case EvapState.drying:          return '에바포레이터 건조 중...';
      case EvapState.finishing:       return '마무리 중...';
      case EvapState.done:            return '✅ 건조 완료!';
      default:                        return '';
    }
  }

  // ── 쿨다운 설정 다이얼로그 ───────────────────────────────
  void _showCooldownPicker() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('재작동 최소 간격',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '건조 완료 후 이 시간이 지나야\n다시 실행할 수 있습니다.',
              style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93), height: 1.5),
            ),
            const SizedBox(height: 16),
            ..._cooldownOptions.map((h) => _CooldownOption(
              hours: h,
              selected: _cooldownHours == h,
              onTap: () {
                setState(() => _cooldownHours = h);
                _saveCooldownHours(h);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  // ── 안전 경고 다이얼로그 ─────────────────────────────────
  void _showSafetyAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          const Text('⚠️ ', style: TextStyle(fontSize: 20)),
          Text(title, style: const TextStyle(
              color: Color(0xFFFF9F0A), fontWeight: FontWeight.w700)),
        ]),
        content: Text(message,
            style: const TextStyle(color: Color(0xFF8E8E93), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인',
                style: TextStyle(
                    color: Color(0xFF0A84FF), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── 건조 시작 ────────────────────────────────────────────
  Future<void> _startDry() async {
    if (_inCooldown) return;

    // ① 알림 권한 요청 (Android 13+, 최초 1회)
    await FlutterForegroundTask.requestNotificationPermission();

    // ② 배터리 최적화 제외 요청 (아직 제외 안 된 경우에만 팝업)
    await EvapForegroundService.requestBatteryOptimizationExemption();

    final appState = context.read<AppState>();
    final svc = context.read<TeslaService>();
    final vin = appState.selectedVehicle?.vin;
    if (vin == null) return;

    // 1단계: 차량 깨우고 안전 체크
    setState(() {
      _state = EvapState.waking;
      _remaining = TeslaConfig.evapDryDurationSeconds;
    });

    await svc.wakeVehicle(vin);
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    final freshData = await svc.getVehicleData(vin);
    if (!mounted) return;

    if (freshData != null) {
      if (freshData.isDriving) {
        _showSafetyAlert('주행 중',
            '차량이 주행 중입니다 (기어: ${freshData.shiftState}).\n완전히 주차한 후 다시 시도해주세요.');
        setState(() => _state = EvapState.idle);
        return;
      }
      if (freshData.remoteStart) {
        _showSafetyAlert('원격 시동 중',
            '현재 원격 시동이 켜져 있습니다.\n원격 시동이 꺼진 후 다시 시도해주세요.');
        setState(() => _state = EvapState.idle);
        return;
      }
      if (freshData.isUserPresent) {
        _showSafetyAlert('탑승자 감지됨',
            '차량 안에 사람이 있어 에바포레이터 건조를 시작할 수 없습니다.\n차량이 비어있을 때 다시 시도해주세요.');
        setState(() => _state = EvapState.idle);
        return;
      }
      if (freshData.anyDoorOpen) {
        _showSafetyAlert('도어 열림 감지',
            '도어가 열려있습니다.\n모든 문을 닫은 후 다시 시도해주세요.');
        setState(() => _state = EvapState.idle);
        return;
      }
    }

    // 2단계: 에어컨 시작
    setState(() => _state = EvapState.startingClimate);
    final r1 = await svc.sendCommand(vin, 'auto_conditioning_start');
    if (!r1.success && !mounted) return;
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // 3단계: Max Defrost + 최고 온도
    setState(() => _state = EvapState.settingMax);
    await svc.sendCommand(vin, 'set_preconditioning_max', {'on': true});
    await Future.delayed(const Duration(milliseconds: 500));
    await svc.sendCommand(vin, 'set_temps', {
      'driver_temp': TeslaConfig.evapMaxTemp,
      'passenger_temp': TeslaConfig.evapMaxTemp,
    });
    await svc.sendCommand(vin, 'remote_seat_heater_request',
        {'seat_position': 0, 'seat_heater_level': 3});
    await svc.sendCommand(vin, 'remote_seat_heater_request',
        {'seat_position': 1, 'seat_heater_level': 3});
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // 4단계: 카운트다운 + 포그라운드 서비스 시작
    setState(() => _state = EvapState.drying);
    await EvapForegroundService.start(
        totalSeconds: TeslaConfig.evapDryDurationSeconds);

    _dryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remaining--);
      EvapForegroundService.update(_remaining); // 알림바 업데이트
      if (_remaining <= 0) {
        t.cancel();
        _finishDry();
      }
    });
  }

  Future<void> _finishDry() async {
    final appState = context.read<AppState>();
    final svc = context.read<TeslaService>();
    final vin = appState.selectedVehicle?.vin;
    if (vin == null) return;

    setState(() => _state = EvapState.finishing);
    await svc.sendCommand(vin, 'set_preconditioning_max', {'on': false});
    await svc.sendCommand(vin, 'auto_conditioning_stop');
    await svc.sendCommand(vin, 'remote_seat_heater_request',
        {'seat_position': 0, 'seat_heater_level': 0});
    await svc.sendCommand(vin, 'remote_seat_heater_request',
        {'seat_position': 1, 'seat_heater_level': 0});

    if (!mounted) return;

    // ★ 포그라운드 서비스 종료 (완료 알림 3초 후 사라짐)
    await EvapForegroundService.stop(completed: true);

    // ★ 쿨다운 시작
    await _saveLastRun();
    setState(() => _state = EvapState.done);
    _startCooldownTick();

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _state = EvapState.idle);
  }

  Future<void> _cancel() async {
    _dryTimer?.cancel();
    await EvapForegroundService.stop(completed: false); // 알림 즉시 제거
    final appState = context.read<AppState>();
    final svc = context.read<TeslaService>();
    final vin = appState.selectedVehicle?.vin;
    if (vin != null) {
      await svc.sendCommand(vin, 'set_preconditioning_max', {'on': false});
      await svc.sendCommand(vin, 'auto_conditioning_stop');
      await svc.sendCommand(vin, 'remote_seat_heater_request',
          {'seat_position': 0, 'seat_heater_level': 0});
      await svc.sendCommand(vin, 'remote_seat_heater_request',
          {'seat_position': 1, 'seat_heater_level': 0});
    }
    if (mounted) setState(() => _state = EvapState.idle);
  }

  // ── UI ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final inCooldown = _inCooldown && !_running;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: inCooldown
              ? [const Color(0xFF1C1C1E), const Color(0xFF1A1A1A)]
              : [const Color(0xFF1C1C1E), const Color(0xFF0D1A2E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _running
              ? const Color(0xFF0A84FF).withOpacity(0.5)
              : inCooldown
                  ? const Color(0xFF38383A)
                  : const Color(0xFF38383A),
          width: _running ? 1.5 : 1,
        ),
        boxShadow: _running
            ? [BoxShadow(
                color: const Color(0xFF0A84FF).withOpacity(0.15),
                blurRadius: 20, spreadRadius: 2)]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더 ──────────────────────────────────────
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _running ? 0.6 + _pulseCtrl.value * 0.4 : 1.0,
                    child: Text(
                      inCooldown ? '💤' : '💨',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('에바포레이터 건조',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text(
                        inCooldown ? _cooldownLeftLabel : '에어컨 냄새 방지 · 5분 자동 시퀀스',
                        style: TextStyle(
                          fontSize: 12,
                          color: inCooldown
                              ? const Color(0xFFFF9F0A)
                              : const Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                // 쿨다운 설정 버튼 (idle 또는 쿨다운 중일 때만)
                if (!_running)
                  GestureDetector(
                    onTap: _showCooldownPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 13, color: Color(0xFF8E8E93)),
                          const SizedBox(width: 4),
                          Text('${_cooldownHours}h',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF8E8E93))),
                        ],
                      ),
                    ),
                  ),
                if (_state == EvapState.done) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF30D158).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('완료',
                        style: TextStyle(color: Color(0xFF30D158), fontSize: 13)),
                  ),
                ],
              ],
            ),

            // ── 쿨다운 진행바 ──────────────────────────────
            if (inCooldown) ...[
              const SizedBox(height: 14),
              _CooldownBar(
                lastRunAt: _lastRunAt,
                cooldownDuration: _cooldownDuration,
              ),
            ],

            // ── 실행 중: 단계 바 + 타이머 ──────────────────
            if (_running || _state == EvapState.done) ...[
              const SizedBox(height: 16),
              _StepBar(state: _state),
            ],
            if (_state == EvapState.drying) ...[
              const SizedBox(height: 16),
              _CircularTimer(
                remaining: _remaining,
                total: TeslaConfig.evapDryDurationSeconds,
              ),
            ],
            if (_running || _state == EvapState.done) ...[
              const SizedBox(height: 10),
              Center(
                child: Text(_stateLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: _state == EvapState.done
                          ? const Color(0xFF30D158)
                          : const Color(0xFF8E8E93),
                    )),
              ),
            ],

            const SizedBox(height: 16),

            // ── 버튼 ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_running || _state == EvapState.done || inCooldown)
                        ? null
                        : _startDry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A84FF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF2C2C2E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      inCooldown
                          ? _cooldownLeftLabel
                          : _running
                              ? '실행 중...'
                              : '건조 시작',
                      style: TextStyle(
                        fontSize: inCooldown ? 13 : 16,
                        fontWeight: FontWeight.w700,
                        color: inCooldown || _running
                            ? const Color(0xFF8E8E93)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
                if (_running) ...[
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _cancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C2C2E),
                      foregroundColor: const Color(0xFF8E8E93),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('중단'),
                  ),
                ],
              ],
            ),

            // ── 원리 설명 ──────────────────────────────────
            if (!_running && _state != EvapState.done && !inCooldown) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '작동 원리: Max Defrost + 28°C 설정으로 AC 컴프레서를 끄고\n'
                  '따뜻한 바람만 순환시켜 에바포레이터를 건조합니다.',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF6E6E73), height: 1.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 쿨다운 진행 바 ───────────────────────────────────────────────────
class _CooldownBar extends StatelessWidget {
  const _CooldownBar({required this.lastRunAt, required this.cooldownDuration});
  final DateTime? lastRunAt;
  final Duration cooldownDuration;

  @override
  Widget build(BuildContext context) {
    if (lastRunAt == null) return const SizedBox.shrink();
    final elapsed = DateTime.now().difference(lastRunAt!);
    final progress = (elapsed.inSeconds / cooldownDuration.inSeconds).clamp(0.0, 1.0);
    final lastRunLabel =
        '${lastRunAt!.month}/${lastRunAt!.day} ${lastRunAt!.hour.toString().padLeft(2,'0')}:${lastRunAt!.minute.toString().padLeft(2,'0')} 마지막 건조';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lastRunLabel,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
            Text('${(progress * 100).round()}%',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF2C2C2E),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress > 0.8
                  ? const Color(0xFF30D158)
                  : const Color(0xFFFF9F0A),
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

// ── 쿨다운 옵션 행 ───────────────────────────────────────────────────
class _CooldownOption extends StatelessWidget {
  const _CooldownOption({
    required this.hours,
    required this.selected,
    required this.onTap,
  });
  final int hours;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0A84FF).withOpacity(0.15)
              : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF0A84FF).withOpacity(0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text('$hours시간',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF0A84FF) : Colors.white,
                )),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF0A84FF), size: 18),
          ],
        ),
      ),
    );
  }
}

// ── 단계 진행 바 ─────────────────────────────────────────────────────
class _StepBar extends StatelessWidget {
  const _StepBar({required this.state});
  final EvapState state;

  int get _step {
    switch (state) {
      case EvapState.waking:          return 0;
      case EvapState.startingClimate: return 1;
      case EvapState.settingMax:      return 2;
      case EvapState.drying:          return 3;
      case EvapState.finishing:       return 3;
      case EvapState.done:            return 4;
      default:                        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        final color = i < _step
            ? const Color(0xFF30D158)
            : i == _step
                ? const Color(0xFF0A84FF)
                : const Color(0xFF38383A);
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
            height: 3,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
        );
      }),
    );
  }
}

// ── 원형 타이머 ──────────────────────────────────────────────────────
class _CircularTimer extends StatelessWidget {
  const _CircularTimer({required this.remaining, required this.total});
  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = remaining / total;
    final min = remaining ~/ 60;
    final sec = remaining % 60;
    final color = remaining < 60
        ? const Color(0xFFFFD60A)
        : const Color(0xFF0A84FF);

    return Center(
      child: SizedBox(
        width: 110, height: 110,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(110, 110),
              painter: _ArcPainter(progress: progress, color: color),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$min:${sec.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700)),
                const Text('남은 시간',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    canvas.drawCircle(center, radius,
        Paint()
          ..color = const Color(0xFF38383A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}
