import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 설정 백업/복원 서비스
/// 백업 대상: 리전, 쿨다운 시간, Client ID, 마지막 건조 시각
/// 제외 대상: 액세스 토큰 / 리프레시 토큰 (보안 상 제외, 재로그인 필요)
class BackupService {
  static const _version = 1;

  // 백업에 포함할 SharedPreferences 키 목록
  static const _backupKeys = [
    'region',
    'evap_cooldown_hours',
    'evap_last_run',
    'client_id_override', // 사용자가 커스텀 Client ID를 저장했을 경우
  ];

  // ── 내보내기 ─────────────────────────────────────────────
  /// 설정을 JSON으로 직렬화 → 공유 시트 표시
  static Future<ExportResult> export() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        '_version': _version,
        '_exported_at': DateTime.now().toIso8601String(),
        '_note': '테슬라 제어 앱 설정 백업 파일 — 토큰 미포함, 재로그인 필요',
      };

      for (final key in _backupKeys) {
        final value = prefs.get(key);
        if (value != null) data[key] = value;
      }

      final json = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = utf8.encode(json);

      // 임시 파일에 저장
      final tmpDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}'
          '_${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}';
      final file = File('${tmpDir.path}/tesla_settings_$stamp.json');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: '테슬라 제어 앱 설정 백업',
        text: '이 파일을 안전한 곳에 저장해두세요.\n복원 시 앱에서 "설정 가져오기"로 불러올 수 있습니다.',
      );

      return ExportResult(success: true, message: '설정을 공유했습니다.');
    } catch (e) {
      return ExportResult(success: false, message: '내보내기 실패: $e');
    }
  }

  // ── 가져오기 ─────────────────────────────────────────────
  /// 파일 피커 → JSON 파싱 → SharedPreferences 적용
  static Future<ImportResult> import() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(success: false, message: '파일을 선택하지 않았습니다.');
      }

      final path = result.files.single.path;
      if (path == null) {
        return ImportResult(success: false, message: '파일 경로를 읽을 수 없습니다.');
      }

      final json = await File(path).readAsString();
      final data = jsonDecode(json) as Map<String, dynamic>;

      // 버전 체크
      final ver = data['_version'] as int? ?? 1;
      if (ver > _version) {
        return ImportResult(
          success: false,
          message: '이 백업 파일은 최신 앱에서 만들어졌습니다. 앱을 업데이트해주세요.',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      int restored = 0;

      for (final key in _backupKeys) {
        final value = data[key];
        if (value == null) continue;
        if (value is String)      { await prefs.setString(key, value); restored++; }
        else if (value is int)    { await prefs.setInt(key, value);    restored++; }
        else if (value is double) { await prefs.setDouble(key, value); restored++; }
        else if (value is bool)   { await prefs.setBool(key, value);   restored++; }
      }

      final exportedAt = data['_exported_at'] as String?;
      final label = exportedAt != null
          ? DateTime.tryParse(exportedAt)
                ?.toLocal()
                .toString()
                .substring(0, 16)
          : null;

      return ImportResult(
        success: true,
        restoredCount: restored,
        message: '설정 $restored개를 복원했습니다.'
            '${label != null ? '\n백업 시각: $label' : ''}',
        requiresRestart: true,
      );
    } catch (e) {
      return ImportResult(success: false, message: '가져오기 실패: $e');
    }
  }

  // ── 미리보기 (가져오기 전 확인용) ───────────────────────
  static Map<String, String> previewData(Map<String, dynamic> data) {
    const labels = {
      'region': '서버 리전',
      'evap_cooldown_hours': '건조 쿨다운 시간',
      'evap_last_run': '마지막 건조 시각',
      'client_id_override': 'Client ID',
    };
    final result = <String, String>{};
    for (final key in _backupKeys) {
      if (data.containsKey(key)) {
        final value = data[key];
        String display = value.toString();
        if (key == 'evap_cooldown_hours') display = '${value}시간';
        if (key == 'evap_last_run') {
          final dt = DateTime.fromMillisecondsSinceEpoch(value as int).toLocal();
          display = dt.toString().substring(0, 16);
        }
        result[labels[key] ?? key] = display;
      }
    }
    return result;
  }
}

class ExportResult {
  final bool success;
  final String message;
  const ExportResult({required this.success, required this.message});
}

class ImportResult {
  final bool success;
  final String message;
  final int restoredCount;
  final bool requiresRestart;
  const ImportResult({
    required this.success,
    required this.message,
    this.restoredCount = 0,
    this.requiresRestart = false,
  });
}
