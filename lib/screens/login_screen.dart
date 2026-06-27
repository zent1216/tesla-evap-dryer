import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tesla_service.dart';
import '../config.dart';
import 'vehicle_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String _selectedRegion = 'ap';

  static const _regions = TeslaConfig.regionNames;

  Future<void> _login() async {
    final svc = context.read<TeslaService>();
    await svc.setRegion(_selectedRegion);
    setState(() => _loading = true);
    try {
      final ok = await svc.login();
      if (!mounted) return;
      if (ok) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VehicleListScreen()),
        );
      } else {
        _showError('로그인에 실패했습니다. 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE82127)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.2,
            colors: [Color(0xFF1A0000), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const TeslaLogoLarge(),
                const SizedBox(height: 28),
                const Text(
                  'Tesla 제어 앱',
                  style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '에바포레이터 건조 · 원격 제어',
                  style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
                ),
                const Spacer(),

                // 리전 선택
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF38383A)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRegion,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1C1C1E),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      icon: const Icon(Icons.expand_more, color: Color(0xFF8E8E93)),
                      onChanged: (v) => setState(() => _selectedRegion = v!),
                      items: _regions.entries.map((e) {
                        return DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 로그인 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE82127),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Tesla 계정으로 로그인',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // 안내
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0A84FF).withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    '로그인 전에 developer.tesla.com에서 앱을 등록하고,\n'
                    'config.dart의 CLIENT_ID를 채워야 합니다.\n'
                    'SETUP.md를 참고하세요.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6EC6FF), height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TeslaLogoLarge extends StatelessWidget {
  const TeslaLogoLarge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1C1C1E),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE82127).withOpacity(0.3),
            blurRadius: 30, spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Text(
          'T',
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFE82127),
            shadows: [
              Shadow(
                color: const Color(0xFFE82127).withOpacity(0.6),
                blurRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
