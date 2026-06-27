import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/vehicle.dart';
import '../services/tesla_service.dart';
import '../widgets/evap_dryer_card.dart';
import '../widgets/backup_card.dart';
import 'login_screen.dart';
import 'vehicle_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _refreshTimer;
  bool _waking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final appState = context.read<AppState>();
    final svc = context.read<TeslaService>();
    final vin = appState.selectedVehicle?.vin;
    if (vin == null) return;
    final data = await svc.getVehicleData(vin);
    if (mounted) appState.setData(data);
  }

  Future<void> _wake() async {
    final appState = context.read<AppState>();
    final svc = context.read<TeslaService>();
    final vin = appState.selectedVehicle?.vin;
    if (vin == null) return;
    setState(() => _waking = true);
    _showSnack('차량을 깨우는 중...');
    await svc.wakeVehicle(vin);
    await Future.delayed(const Duration(seconds: 4));
    await _loadData();
    if (mounted) setState(() => _waking = false);
  }

  Future<void> _cmd(String command, [Map<String, dynamic>? body]) async {
    final appState = context.read<AppState>();
    final svc = context.read<TeslaService>();
    final vin = appState.selectedVehicle?.vin;
    if (vin == null) return;
    final result = await svc.sendCommand(vin, command, body);
    if (mounted) {
      if (result.success) {
        _showSnack('✅ 완료', success: true);
        Future.delayed(const Duration(seconds: 2), _loadData);
      } else {
        _showSnack('❌ ${result.reason.isNotEmpty ? result.reason : "명령 실패"}',
            success: false);
      }
    }
  }

  void _showSnack(String msg, {bool? success}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        backgroundColor: success == true
            ? const Color(0xFF30D158).withOpacity(0.9)
            : success == false
                ? const Color(0xFFE82127).withOpacity(0.9)
                : const Color(0xFF2C2C2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final vehicle = appState.selectedVehicle;
    final data = appState.vehicleData;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          // ── 상단 앱바 ─────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: const Color(0xFF0A0A0A),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const VehicleListScreen()),
              ),
            ),
            actions: [
              if (_waking)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFFFD60A),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.power_settings_new, size: 20),
                  onPressed: _wake,
                  tooltip: '차량 깨우기',
                ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                color: const Color(0xFF1C1C1E),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'refresh', child: Text('데이터 새로고침')),
                  const PopupMenuItem(value: 'logout', child: Text('로그아웃')),
                ],
                onSelected: (v) async {
                  if (v == 'refresh') _loadData();
                  if (v == 'logout') {
                    await context.read<TeslaService>().logout();
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle?.displayName ?? 'My Tesla',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: vehicle?.isOnline == true
                              ? const Color(0xFF30D158)
                              : vehicle?.isAsleep == true
                                  ? const Color(0xFFFFD60A)
                                  : const Color(0xFF8E8E93),
                        ),
                      ),
                      Text(
                        vehicle?.isOnline == true
                            ? '온라인'
                            : vehicle?.isAsleep == true
                                ? '절전 중'
                                : '���프라인',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF8E8E93)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── 배터리 + 상태 ─────────────────────────────────
                if (data != null) _StatusSection(data: data),

                // ── 빠른 동작 ─────────────────────────────────────
                _QuickActions(onCmd: _cmd),

                // ── ★ 에바포레이터 건조 카드 ──────────────────────
                const EvapDryerCard(),

                const SizedBox(height: 12),

                // ── 제어 섹션들 ───────────────────────────────────
                _CommandSection(
                  icon: '🚪',
                  title: '도어 & 트렁크',
                  children: [
                    _CmdRow('잠금', onTap: () => _cmd('door_lock')),
                    _CmdRow('잠금 해제', onTap: () => _cmd('door_unlock')),
                    _CmdRow('앞 트렁크', onTap: () => _cmd('actuate_trunk', {'which_trunk': 'front'})),
                    _CmdRow('뒤 트렁크', onTap: () => _cmd('actuate_trunk', {'which_trunk': 'rear'})),
                    // 창문 — 현재 상태��� 따라 토글
                    _WindowToggleRow(
                      isVenting: data?.windowsVenting ?? false,
                      onVent: () => _cmd('window_control', {'command': 'vent', 'lat': 0, 'lon': 0}),
                      onClose: () => _cmd('window_control', {'command': 'close', 'lat': 0, 'lon': 0}),
                    ),
                    _CmdRow('충전구 열기', onTap: () => _cmd('charge_port_door_open')),
                    _CmdRow('충전구 닫기', onTap: () => _cmd('charge_port_door_close')),
                  ],
                ),

                _CommandSection(
                  icon: '🌡️',
                  title: '기후 & 공조',
                  children: [
                    _CmdRow('에어컨 켜기', color: const Color(0xFF30D158),
                        onTap: () => _cmd('auto_conditioning_start')),
                    _CmdRow('에어컨 끄기', color: const Color(0xFFFF453A),
                        onTap: () => _cmd('auto_conditioning_stop')),
                    _CmdRow('Max Defrost 켜기', color: const Color(0xFF0A84FF),
                        onTap: () => _cmd('set_preconditioning_max', {'on': true})),
                    _CmdRow('최고 온도 (28°C)', onTap: () => _cmd('set_temps',
                        {'driver_temp': 28.0, 'passenger_temp': 28.0})),
                    _CmdRow('바이오웨폰 방어 모드', onTap: () => _cmd('set_bioweapon_mode',
                        {'on': true, 'manual_override': true})),
                    _CmdRow('Dog 모드', onTap: () => _cmd('set_climate_keeper_mode', {'climate_keeper_mode': 2})),
                    _CmdRow('Camp 모드', onTap: () => _cmd('set_climate_keeper_mode', {'climate_keeper_mode': 3})),
                    _CmdRow('시트 히터 OFF', onTap: () async {
                      await _cmd('remote_seat_heater_request', {'seat_position': 0, 'seat_heater_level': 0});
                      await _cmd('remote_seat_heater_request', {'seat_position': 1, 'seat_heater_level': 0});
                    }),
                  ],
                ),

                _CommandSection(
                  icon: '⚡',
                  title: '충전',
                  children: [
                    _CmdRow('충전 시작', color: const Color(0xFF30D158),
                        onTap: () => _cmd('charge_start')),
                    _CmdRow('충전 중지', color: const Color(0xFFFF453A),
                        onTap: () => _cmd('charge_stop')),
                    _CmdRow('충전 한도 80%', onTap: () => _cmd('set_charge_limit', {'percent': 80})),
                    _CmdRow('충전 한도 90%', onTap: () => _cmd('set_charge_limit', {'percent': 90})),
                    _CmdRow('최대 충전 모드', onTap: () => _cmd('charge_max_range')),
                    _CmdRow('표준 충전 모드', onTap: () => _cmd('charge_standard')),
                  ],
                ),

                _CommandSection(
                  icon: '🛡️',
                  title: '보안',
                  children: [
                    _CmdRow('센트리 모드 켜기', color: const Color(0xFF0A84FF),
                        onTap: () => _cmd('set_sentry_mode', {'on': true})),
                    _CmdRow('센트리 모드 끄기', onTap: () => _cmd('set_sentry_mode', {'on': false})),
                    _CmdRow('발레 모드 켜기', onTap: () => _cmd('set_valet_mode', {'on': true, 'password': '0000'})),
                    _CmdRow('발레 모드 끄기', onTap: () => _cmd('set_valet_mode', {'on': false})),
                  ],
                ),

                _CommandSection(
                  icon: '🎮',
                  title: '원격',
                  children: [
                    _CmdRow('원격 시동', color: const Color(0xFF30D158),
                        onTap: () => _cmd('remote_start_drive')),
                    _CmdRow('경적', onTap: () => _cmd('honk_horn')),
                    _CmdRow('라이트 점멸', onTap: () => _cmd('flash_lights')),
                    _CmdRow('HomeLink', onTap: () => _cmd('trigger_homelink', {'lat': 0, 'lon': 0})),
                    _CmdRow('붐박스 (방귀)', onTap: () => _cmd('remote_boombox', {'sound_id': 0})),
                  ],
                ),

                _CommandSection(
                  icon: '🎵',
                  title: '미디어',
                  children: [
                    _CmdRow('재생 / 일시정지', onTap: () => _cmd('media_toggle_playback')),
                    _CmdRow('이전 트랙', onTap: () => _cmd('media_prev_track')),
                    _CmdRow('다음 트랙', onTap: () => _cmd('media_next_track')),
                  ],
                ),

                // ── 설정 백업 / 복원 ───────────────────────────────
                const BackupCard(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 상태 카드 ─────────────────────────────────────────────────────────
class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.data});
  final VehicleData data;

  @override
  Widget build(BuildContext context) {
    final pct = data.batteryLevel ?? 0;
    final range = data.estRangeKm != null ? '${data.estRangeKm!.round()} km' : '–';
    final barColor = pct < 20
        ? const Color(0xFFFF453A)
        : pct < 40
            ? const Color(0xFFFFD60A)
            : const Color(0xFF30D158);

    return Column(
      children: [
        // 배터리 바
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$pct%',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('$range 남음',
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF8E8E93))),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  backgroundColor: const Color(0xFF2C2C2E),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        // 상태 그리드
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _StatCell(
                label: '잠금',
                value: data.locked == true ? '🔒' : '🔓',
                valueColor: data.locked == true
                    ? const Color(0xFF30D158)
                    : const Color(0xFFFF453A),
              ),
              _StatCell(
                label: '실내 온도',
                value: data.insideTemp != null
                    ? '${data.insideTemp!.round()}°C'
                    : '–',
              ),
              _StatCell(
                label: '충전',
                value: data.chargingState == 'Charging' ? '⚡' : (data.chargingState ?? '–'),
                valueColor: data.chargingState == 'Charging'
                    ? const Color(0xFF30D158)
                    : null,
              ),
              _StatCell(
                label: '센트리',
                value: data.sentryMode == true ? '🛡️' : '–',
                valueColor: data.sentryMode == true
                    ? const Color(0xFF30D158)
                    : null,
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF2C2C2E), height: 1),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value, this.valueColor});
  final String label, value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: valueColor ?? Colors.white,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
        ],
      ),
    );
  }
}

// ── 빠른 동작 ─────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onCmd});
  final Function(String, [Map<String, dynamic>?]) onCmd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _QBtn('🔒', '잠금', () => onCmd('door_lock')),
          _QBtn('🔓', '잠금해제', () => onCmd('door_unlock')),
          _QBtn('💡', '라이트', () => onCmd('flash_lights')),
          _QBtn('📯', '경적', () => onCmd('honk_horn')),
        ],
      ),
    );
  }
}

class _QBtn extends StatelessWidget {
  const _QBtn(this.icon, this.label, this.onTap);
  final String icon, label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF8E8E93))),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 명령 섹션 (아코디언) ──────────────────────────────────────────────
class _CommandSection extends StatefulWidget {
  const _CommandSection({
    required this.icon,
    required this.title,
    required this.children,
  });
  final String icon, title;
  final List<Widget> children;

  @override
  State<_CommandSection> createState() => _CommandSectionState();
}

class _CommandSectionState extends State<_CommandSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(widget.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  Icon(
                    _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF8E8E93),
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(color: Color(0xFF2C2C2E), height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(children: widget.children),
            ),
          ],
        ],
      ),
    );
  }
}

class _CmdRow extends StatelessWidget {
  const _CmdRow(this.label, {required this.onTap, this.color});
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15, color: color ?? Colors.white)),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFF8E8E93), size: 18),
          ],
        ),
      ),
    );
  }
}

// ── 창문 환기 토글 ──────────────────────────────────────────────────
class _WindowToggleRow extends StatelessWidget {
  const _WindowToggleRow({
    required this.isVenting,
    required this.onVent,
    required this.onClose,
  });
  final bool isVenting;
  final VoidCallback onVent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // 현재 상태 아이콘
          Text(
            isVenting ? '🪟' : '⬛',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('창문 환기', style: TextStyle(fontSize: 15)),
                Text(
                  isVenting ? '현재: 환기 중' : '현재: 닫힘',
                  style: TextStyle(
                    fontSize: 12,
                    color: isVenting
                        ? const Color(0xFF0A84FF)
                        : const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          // 토글 버튼
          GestureDetector(
            onTap: isVenting ? onClose : onVent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isVenting
                    ? const Color(0xFF0A84FF).withOpacity(0.15)
                    : const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isVenting
                      ? const Color(0xFF0A84FF).withOpacity(0.4)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                isVenting ? '닫기' : '환기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isVenting
                      ? const Color(0xFF0A84FF)
                      : const Color(0xFF8E8E93),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
