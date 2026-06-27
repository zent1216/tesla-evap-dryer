import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/vehicle.dart';

class TeslaService extends ChangeNotifierBase {
  final _storage = const FlutterSecureStorage();

  String _region = 'ap';
  String get region => _region;

  String get _fleetBase =>
      TeslaConfig.regionUrls[_region] ?? TeslaConfig.regionUrls['ap']!;

  // ── 초기화 ──────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _region = prefs.getString('region') ?? 'ap';
  }

  Future<void> setRegion(String r) async {
    _region = r;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('region', r);
  }

  // ── 인증 상태 ────────────────────────────────────────────
  Future<bool> get isLoggedIn async =>
      (await _storage.read(key: 'access_token')) != null;

  Future<String?> get accessToken => _storage.read(key: 'access_token');

  // ── OAuth 2.0 PKCE 로그인 ───────────────────────────────
  Future<bool> login() async {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    final state = _randomString(16);

    final authUri = Uri.parse('${TeslaConfig.authBase}/authorize').replace(
      queryParameters: {
        'client_id': TeslaConfig.clientId,
        'redirect_uri': TeslaConfig.redirectUri,
        'response_type': 'code',
        'scope': TeslaConfig.scopes,
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    );

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: 'teslapwa',
      );

      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];
      final returnedState = uri.queryParameters['state'];

      if (code == null || returnedState != state) return false;

      return await _exchangeCode(code, verifier);
    } catch (e) {
      return false;
    }
  }

  Future<bool> _exchangeCode(String code, String verifier) async {
    final resp = await http.post(
      Uri.parse('${TeslaConfig.authBase}/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': TeslaConfig.clientId,
        'code': code,
        'redirect_uri': TeslaConfig.redirectUri,
        'code_verifier': verifier,
      },
    );

    if (resp.statusCode != 200) return false;
    final data = jsonDecode(resp.body);
    await _storage.write(key: 'access_token', value: data['access_token']);
    await _storage.write(key: 'refresh_token', value: data['refresh_token']);
    return true;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  // ── 토큰 갱신 ────────────────────────────────────────────
  Future<bool> refreshTokens() async {
    final rt = await _storage.read(key: 'refresh_token');
    if (rt == null) return false;

    final resp = await http.post(
      Uri.parse('${TeslaConfig.authBase}/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': TeslaConfig.clientId,
        'refresh_token': rt,
      },
    );

    if (resp.statusCode != 200) return false;
    final data = jsonDecode(resp.body);
    await _storage.write(key: 'access_token', value: data['access_token']);
    if (data['refresh_token'] != null) {
      await _storage.write(key: 'refresh_token', value: data['refresh_token']);
    }
    return true;
  }

  // ── API 헬퍼 ─────────────────────────────────────────────
  Future<Map<String, dynamic>?> _get(String path) async {
    final token = await accessToken;
    if (token == null) return null;
    final resp = await http.get(
      Uri.parse('$_fleetBase$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    if (resp.statusCode == 401) {
      if (await refreshTokens()) return _get(path);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _post(String path,
      [Map<String, dynamic>? body]) async {
    final token = await accessToken;
    if (token == null) return null;
    final resp = await http.post(
      Uri.parse('$_fleetBase$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body != null ? jsonEncode(body) : '{}',
    );
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body);
    }
    if (resp.statusCode == 401) {
      if (await refreshTokens()) return _post(path, body);
    }
    return null;
  }

  // ── 차량 목록 ─────────────────────────────────────────────
  Future<List<Vehicle>> getVehicles() async {
    final data = await _get('/api/1/vehicles');
    if (data == null) return [];
    final list = data['response'] as List? ?? [];
    return list.map((v) => Vehicle.fromJson(v)).toList();
  }

  // ── 차량 데이터 ───────────────────────────────────────────
  Future<VehicleData?> getVehicleData(String vin) async {
    final data = await _get(
      '/api/1/vehicles/$vin/vehicle_data'
      '?endpoints=charge_state;climate_state;vehicle_state;drive_state',
    );
    if (data == null) return null;
    final resp = data['response'] as Map<String, dynamic>?;
    if (resp == null) return null;
    return VehicleData.fromJson(resp);
  }

  // ── 차량 깨우기 ───────────────────────────────────────────
  Future<bool> wakeVehicle(String vin) async {
    final data = await _post('/api/1/vehicles/$vin/wake_up');
    return data != null;
  }

  // ── 명령 전송 ─────────────────────────────────────────────
  Future<CommandResult> sendCommand(
    String vin,
    String command, [
    Map<String, dynamic>? body,
  ]) async {
    final data = await _post('/api/1/vehicles/$vin/command/$command', body);
    if (data == null) return CommandResult(false, '네트워크 오류');
    final r = data['response'] ?? data;
    final result = r['result'] == true;
    final reason = r['reason'] as String? ?? '';
    return CommandResult(result, reason);
  }

  // ── PKCE 헬퍼 ─────────────────────────────────────────────
  static String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rng = Random.secure();
    return List.generate(128, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static String _randomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}

/// ChangeNotifier 없이 쓸 수 있는 간단한 기반 클래스
class ChangeNotifierBase with ChangeNotifier {}

class CommandResult {
  final bool success;
  final String reason;
  CommandResult(this.success, this.reason);
}
