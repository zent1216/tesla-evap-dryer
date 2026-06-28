import 'package:shared_preferences/shared_preferences.dart';

class TeslaConfig {
  static String _clientId = '';
  static String get clientId => _clientId;

  static Future<void> loadClientId() async {
    final prefs = await SharedPreferences.getInstance();
    _clientId = prefs.getString('tesla_client_id') ?? '';
  }

  static Future<void> saveClientId(String id) async {
    _clientId = id.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tesla_client_id', _clientId);
  }

  static bool get hasClientId => _clientId.isNotEmpty;

  static const String redirectUri = 'https://zent1216.github.io/tesla-evap-dryer/callback';
  static const String authBase =
      'https://fleet-auth.prd.vn.cloud.tesla.com/oauth2/v3';
  static const String scopes =
      'openid offline_access vehicle_device_data vehicle_cmds vehicle_charging_cmds';

  static const Map<String, String> regionUrls = {
    'ap': 'https://fleet-api.prd.ap.vn.cloud.tesla.com',
    'na': 'https://fleet-api.prd.na.vn.cloud.tesla.com',
    'eu': 'https://fleet-api.prd.eu.vn.cloud.tesla.com',
  };

  static const Map<String, String> regionNames = {
    'ap': '아시아·태평양 (한국)',
    'na': '북미',
    'eu': '유럽',
  };

  static const int evapDryDurationSeconds = 5 * 60;
  static const double evapMaxTemp = 28.0;
}
