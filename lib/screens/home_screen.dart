import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/scraper_service.dart';
import '../services/sync_service.dart';
import 'todo_screen.dart';
import 'presensi_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime? _lastSync;
  bool _syncing = false;

  final _todoKey = GlobalKey<TodoScreenState>();
  final _presensiKey = GlobalKey<PresensiScreenState>();
  late final _screens = [
    TodoScreen(key: _todoKey),
    PresensiScreen(key: _presensiKey),
  ];

  static const _channel = MethodChannel('com.digitech/cookies');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLastSync();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBatteryExemption());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastSync;
    // Hanya sync jika sudah lebih dari 5 menit sejak terakhir sync
    if (last == null || DateTime.now().difference(last).inMinutes >= 5) {
      _syncNow();
    }
  }

  Future<void> _checkBatteryExemption() async {
    try {
      // Only ask once, LoginScreen may have already asked during onboarding
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(AppConstants.prefBatteryExemptionAsked) ?? false) return;

      final isOptimized = await _channel.invokeMethod<bool>('isBatteryOptimized') ?? false;
      if (!isOptimized || !mounted) return;

      await prefs.setBool(AppConstants.prefBatteryExemptionAsked, true);

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Aktifkan Notifikasi Otomatis'),
          content: const Text(
            'Battery optimizer HP kamu membatasi notifikasi otomatis Digitech+. '
            'Izinkan app berjalan di background agar notifikasi tugas dan presensi bisa terkirim tepat waktu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nanti'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Izinkan'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _channel.invokeMethod('requestBatteryExemption');
      }
    } catch (_) {}
  }

  Future<void> _loadLastSync() async {
    final t = await SyncService.getLastSync();
    if (mounted) setState(() => _lastSync = t);
  }

  Future<void> _syncNow({bool resetSeen = false}) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await SyncService.syncNow(resetSeen: resetSeen);
      await _loadLastSync();
      _todoKey.currentState?.reload();
      _presensiKey.currentState?.reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resetSeen
                ? 'Reset selesai, notifikasi dikirim untuk semua data'
                : 'Sync selesai'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on SessionExpiredException {
      _redirectToLogin();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal sync: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _redirectToLogin() {
    AuthService.clearSession();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Keluar dari Digitech+?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.clearSession();
      await SyncService.cancelSync();
      // Clear WebView cookies so the login page doesn't auto-redirect
      try {
        await _channel.invokeMethod('clearCookies');
      } catch (_) {}
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  String get _appBarTitle {
    switch (_currentIndex) {
      case 0:
        return 'Tugas';
      case 1:
        return 'Presensi';
      default:
        return 'Digitech+';
    }
  }

  String _formatLastSync() {
    if (_lastSync == null) return 'Belum pernah sync';
    final now = DateTime.now();
    final diff = now.difference(_lastSync!);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Digitech',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const Text(
              '+',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: Color(0xFF80CBC4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _appBarTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) {
                if (val == 'sync') {
                  _syncNow();
                } else if (val == 'reset_sync') {
                  _syncNow(resetSeen: true);
                } else if (val == 'settings') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                } else if (val == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Terakhir: ${_formatLastSync()}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'sync',
                  child: Row(
                    children: [
                      Icon(Icons.sync, size: 18),
                      SizedBox(width: 8),
                      Text('Sync Sekarang'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset_sync',
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Reset & Sync (Test Notif)'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.notifications_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Pengaturan Notifikasi'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: AppTheme.danger),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: AppTheme.danger)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Tugas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_reg_outlined),
            activeIcon: Icon(Icons.how_to_reg),
            label: 'Presensi',
          ),
        ],
      ),
    );
  }
}
