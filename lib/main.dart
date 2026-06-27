import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/tesla_service.dart';
import 'services/foreground_service.dart';
import 'screens/login_screen.dart';
import 'screens/vehicle_list_screen.dart';
import 'screens/dashboard_screen.dart';
import 'models/vehicle.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  EvapForegroundService.init(); // 포그라운드 서비스 초기화
  runApp(const TeslaApp());
}

class TeslaApp extends StatelessWidget {
  const TeslaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TeslaService()),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: MaterialApp(
        title: 'Tesla 제어 앱',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const SplashScreen(),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      cardColor: const Color(0xFF1C1C1E),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE82127),
        secondary: Color(0xFF0A84FF),
        surface: Color(0xFF1C1C1E),
        surfaceContainerHighest: Color(0xFF2C2C2E),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0A0A),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      dividerColor: const Color(0xFF38383A),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Color(0xFF8E8E93)),
      ),
    );
  }
}

// ── 앱 전역 상태 ────────────────────────────────────────────────────
class AppState extends ChangeNotifier {
  Vehicle? selectedVehicle;
  VehicleData? vehicleData;
  bool dataLoading = false;

  void setVehicle(Vehicle v) {
    selectedVehicle = v;
    vehicleData = null;
    notifyListeners();
  }

  void setData(VehicleData? d) {
    vehicleData = d;
    dataLoading = false;
    notifyListeners();
  }
}

// ── 스플래시 → 로그인 또는 대시보드 ────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final svc = context.read<TeslaService>();
    await svc.init();
    if (!mounted) return;
    final loggedIn = await svc.isLoggedIn;
    if (!mounted) return;
    if (loggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VehicleListScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(child: TeslaLogo()),
    );
  }
}

// Tesla T 로고 위젯
class TeslaLogo extends StatelessWidget {
  const TeslaLogo({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.5),
      painter: _TeslaPainter(),
    );
  }
}

class _TeslaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE82127)
      ..style = PaintingStyle.fill;

    // Tesla T 심볼
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(0, h * 0.134);
    path.lineTo(w * 0.5, h * 0.134);
    path.lineTo(w * 0.5, h);

    // T 위
    path.moveTo(0, 0);
    path.lineTo(w, 0);
    path.lineTo(w, h * 0.134);
    path.lineTo(0, h * 0.134);
    path.close();

    // T 세로
    final rect = Rect.fromLTWH(w * 0.35, 0, w * 0.3, h);
    canvas.drawRect(rect, paint);
    // T 가로
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.134), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
