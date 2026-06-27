class Vehicle {
  final String vin;
  final String displayName;
  final String state; // online | asleep | offline
  final String? model;

  Vehicle({
    required this.vin,
    required this.displayName,
    required this.state,
    this.model,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      vin: json['vin'] ?? '',
      displayName: json['display_name'] ?? 'My Tesla',
      state: json['state'] ?? 'unknown',
      model: json['vehicle_config']?['car_type'],
    );
  }

  bool get isOnline => state == 'online';
  bool get isAsleep => state == 'asleep';
}

class VehicleData {
  final int? batteryLevel;
  final double? estRangeKm;
  final bool? locked;
  final bool? sentryMode;
  final double? insideTemp;
  final String? chargingState;
  final bool? climateOn;

  /// 탑승자 감지 (vehicle_state.is_user_present)
  final bool isUserPresent;

  /// 도어 열림 여부 (앞 운전석/동승석/뒷문)
  final bool anyDoorOpen;

  /// 창문 상태 (fd_window: 0=닫힘, 1=환기, 2=열림)
  final int? fdWindow; // 앞 운전석
  final int? rdWindow; // 뒤 운전석

  /// 원격 시동 중 (vehicle_state.remote_start)
  final bool remoteStart;

  /// 기어 상태 (drive_state.shift_state): 'P', 'D', 'R', 'N', null=주차
  final String? shiftState;

  VehicleData({
    this.batteryLevel,
    this.estRangeKm,
    this.locked,
    this.sentryMode,
    this.insideTemp,
    this.chargingState,
    this.climateOn,
    this.isUserPresent = false,
    this.anyDoorOpen = false,
    this.fdWindow,
    this.rdWindow,
    this.remoteStart = false,
    this.shiftState,
  });

  /// 창문이 환기 상태인지
  bool get windowsVenting => (fdWindow ?? 0) > 0 || (rdWindow ?? 0) > 0;

  /// 주행 중 여부 (D/R/N — P나 null이 아닌 경우)
  bool get isDriving =>
      shiftState != null && shiftState != 'P';

  factory VehicleData.fromJson(Map<String, dynamic> json) {
    final cs = json['charge_state'] ?? {};
    final cl = json['climate_state'] ?? {};
    final vs = json['vehicle_state'] ?? {};
    final ds = json['drive_state'] ?? {};

    final anyDoor = (vs['df'] ?? 0) > 0 ||
        (vs['dr'] ?? 0) > 0 ||
        (vs['pf'] ?? 0) > 0 ||
        (vs['pr'] ?? 0) > 0;

    return VehicleData(
      batteryLevel: cs['battery_level'],
      estRangeKm: cs['est_battery_range'] != null
          ? (cs['est_battery_range'] as num).toDouble() * 1.609
          : null,
      locked: vs['locked'],
      sentryMode: vs['sentry_mode'],
      insideTemp: cl['inside_temp'] != null
          ? (cl['inside_temp'] as num).toDouble()
          : null,
      chargingState: cs['charging_state'],
      climateOn: cl['is_climate_on'],
      isUserPresent: vs['is_user_present'] == true,
      anyDoorOpen: anyDoor,
      fdWindow: vs['fd_window'] as int?,
      rdWindow: vs['rd_window'] as int?,
      remoteStart: vs['remote_start'] == true,
      shiftState: ds['shift_state'] as String?,
    );
  }
}
