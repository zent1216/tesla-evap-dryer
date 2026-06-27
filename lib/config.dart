// Tesla 앱 설정
// developer.tesla.com 에서 발급받은 Client ID로 교체하세요.
class TeslaConfig {
  // ── 여기를 채우세요 ─────────────────────────────────────
  static const String clientId = 'YOUR_CLIENT_ID_HERE';
  // ──────────────────────────────────────────────────────

  static const String redirectUri = 'teslapwa://callback';
  static const String authBase =
      'https://fleet-auth.prd.vn.cloud.tesla.com/oauth2/v3';
  static const String scopes =
      'openid offline_access vehicle_device_data vehicle_cmds vehicle_charging_cmds';

  static const Map<String, String> regionUrls = {
    'ap': 'https://fleet-api.prd.ap.vn.cloud.tesla.com', // 한국 포함
    'na': 'https://fleet-api.prd.na.vn.cloud.tesla.com',
    'eu': 'https://fleet-api.prd.eu.vn.cloud.tesla.com',
  };

  static const Map<String, String> regionNames = {
    'ap': '아시아·태평양 (한국)',
    'na': '북미',
    'eu': '유럽',
  };

  // 에바포레이터 건조 설정
  static const int evapDryDurationSeconds = 5 * 60; // 5분
  static const double evapMaxTemp = 28.0; // 최고 설정 온도 (°C)
}
