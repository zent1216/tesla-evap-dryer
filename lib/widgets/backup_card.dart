import 'package:flutter/material.dart';
import '../services/backup_service.dart';

class BackupCard extends StatefulWidget {
  const BackupCard({super.key});

  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    final result = await BackupService.export();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.success) _showSnack(result.message, isError: true);
    // 성공 시 공유 시트가 자동으로 열리므로 별도 메시지 불필요
  }

  Future<void> _import() async {
    // 가져오기 전 경고 확인
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('설정 가져오기',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          '백업 파일의 설정으로 현재 설정이 덮어씌워집니다.\n'
          '로그인 정보는 유지되며, 재로그인은 필요하지 않습니다.',
          style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소',
                style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('가져오기',
                style: TextStyle(
                    color: Color(0xFF0A84FF), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    final result = await BackupService.import();
    if (!mounted) return;
    setState(() => _busy = false);

    _showSnack(result.message, isError: !result.success);

    if (result.success && result.requiresRestart) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text('✅ 복원 완료',
                style: TextStyle(fontWeight: FontWeight.w700)),
            content: const Text(
              '일부 설정은 앱을 재시작해야 적용됩니다.',
              style:
                  TextStyle(fontSize: 13, color: Color(0xFF8E8E93), height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인',
                    style: TextStyle(
                        color: Color(0xFF0A84FF),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFFF453A) : const Color(0xFF30D158),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38383A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            const Row(
              children: [
                Text('🗂️', style: TextStyle(fontSize: 22)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('설정 백업 / 복원',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('리전, 쿨다운 시간 등 · 로그인 정보 제외',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF8E8E93))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 버튼 2개
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.upload_outlined,
                    label: '설정 내보내기',
                    color: const Color(0xFF0A84FF),
                    busy: _busy,
                    onTap: _export,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.download_outlined,
                    label: '설정 가져오기',
                    color: const Color(0xFF30D158),
                    busy: _busy,
                    onTap: _import,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '💡 토큰(로그인 정보)은 보안 상 백업에 포함되지 않습니다.\n'
                '   기기 변경 후엔 Tesla 재로그인이 필요합니다.',
                style: TextStyle(
                    fontSize: 11, color: Color(0xFF6E6E73), height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: busy ? null : onTap,
      icon: busy
          ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        disabledBackgroundColor: const Color(0xFF2C2C2E),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}
