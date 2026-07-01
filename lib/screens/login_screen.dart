import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _cookieChannel = MethodChannel(AppConstants.cookieChannel);

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isExtracting = false;
  String _statusMsg = '';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _isLoading = true;
          _statusMsg = '';
        }),
        onPageFinished: (url) async {
          setState(() => _isLoading = false);
          await _onPageFinished(url);
        },
        onWebResourceError: (_) => setState(() => _isLoading = false),
      ))
      ..loadRequest(Uri.parse(AppConstants.baseUrl));
  }

  Future<void> _onPageFinished(String url) async {
    if (_isExtracting) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    // Cek apakah sudah di halaman course (berhasil login)
    final currentUrl = await _controller.currentUrl() ?? '';
    if (currentUrl.contains('/course') ||
        currentUrl.contains('/dashboard')) {
      if (!currentUrl.contains('login') && !currentUrl.contains('auth')) {
        setState(() {
          _isExtracting = true;
          _statusMsg = 'Menyimpan sesi...';
        });
        await _extractAndSaveSession();
      }
    }
  }

  Future<void> _extractAndSaveSession() async {
    try {
      final cookieString = await _cookieChannel.invokeMethod<String>(
        'getCookies',
        {'url': AppConstants.baseUrl},
      );

      if (cookieString == null || cookieString.isEmpty) {
        _onExtractionFailed('Cookie tidak ditemukan');
        return;
      }

      final match = RegExp(r'ci_session=([^;]+)').firstMatch(cookieString);
      final session = match?.group(1);

      if (session == null || session.isEmpty) {
        _onExtractionFailed('Session tidak ditemukan');
        return;
      }

      await AuthService.saveSession(session);
      await NotificationService.requestPermission();
      await SyncService.registerPeriodicSync();

      // Clear session-expired flag so notification can fire again if needed
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.prefSessionExpiredShown);

      // Request battery optimization exemption so WorkManager runs on time
      await _requestBatteryExemption();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on MissingPluginException {
      _onExtractionFailed('Platform tidak didukung');
    } catch (e) {
      _onExtractionFailed('Terjadi kesalahan: $e');
    }
  }

  Future<void> _requestBatteryExemption() async {
    try {
      final isOptimized = await _cookieChannel.invokeMethod<bool>('isBatteryOptimized') ?? false;
      if (!isOptimized) return; // already exempted, nothing to do

      if (!mounted) return;
      // Mark as asked so HomeScreen doesn't show the same dialog again
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefBatteryExemptionAsked, true);

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Aktifkan Notifikasi Otomatis'),
          content: const Text(
            'Agar Digitech+ bisa memberi tahu kamu soal tugas dan presensi secara otomatis, '
            'izinkan app ini berjalan di background.\n\n'
            'Di halaman berikutnya, pilih "Izinkan".',
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
        await _cookieChannel.invokeMethod('requestBatteryExemption');
      }
    } catch (_) {
      // Non-critical, ignore if native method fails
    }
  }

  void _onExtractionFailed(String msg) {
    setState(() {
      _isExtracting = false;
      _statusMsg = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(child: WebViewWidget(controller: _controller)),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: AppTheme.primary,
                minHeight: 3,
              ),
            ),
          if (_isExtracting)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        _statusMsg.isEmpty ? 'Menyimpan sesi...' : _statusMsg,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_statusMsg.isNotEmpty && !_isExtracting)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMsg,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
