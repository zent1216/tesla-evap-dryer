import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/vehicle.dart';
import '../services/tesla_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  List<Vehicle> _vehicles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() { _loading = true; _error = null; });
    final svc = context.read<TeslaService>();
    final vehicles = await svc.getVehicles();
    if (!mounted) return;
    if (vehicles.isEmpty) {
      setState(() {
        _error = '등록된 차량이 없거나 로그인이 필요합니다.';
        _loading = false;
      });
    } else {
      setState(() { _vehicles = vehicles; _loading = false; });
      if (vehicles.length == 1) _selectVehicle(vehicles.first);
    }
  }

  void _selectVehicle(Vehicle v) {
    context.read<AppState>().setVehicle(v);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Future<void> _logout() async {
    await context.read<TeslaService>().logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('차량 선택'),
        actions: [
          TextButton(
            onPressed: _logout,
            child: const Text('로그아웃', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
        ],
      ),
      body: _build(),
    );
  }

  Widget _build() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE82127)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Color(0xFF8E8E93))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadVehicles,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE82127)),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vehicles.length,
      itemBuilder: (context, i) => _VehicleCard(
        vehicle: _vehicles[i],
        onTap: () => _selectVehicle(_vehicles[i]),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.onTap});
  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateColor = vehicle.isOnline
        ? const Color(0xFF30D158)
        : vehicle.isAsleep
            ? const Color(0xFFFFD60A)
            : const Color(0xFF8E8E93);
    final stateLabel = vehicle.isOnline ? '온라인' : vehicle.isAsleep ? '절전' : '오프라인';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF38383A)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: Text('T', style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900,
                  color: Color(0xFFE82127),
                )),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle.displayName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(vehicle.vin,
                      style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8E8E93), fontFamily: 'monospace',
                      )),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: stateColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(stateLabel, style: TextStyle(color: stateColor, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
