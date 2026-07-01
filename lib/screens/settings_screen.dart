import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _tugasEnabled = true;
  bool _presensiEnabled = true;
  bool _notifPermissionGranted = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check after the user comes back from the system settings screen.
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tugasEnabled = prefs.getBool(AppConstants.prefNotifTugasEnabled) ?? true;
      _presensiEnabled =
          prefs.getBool(AppConstants.prefNotifPresensiEnabled) ?? true;
    });
    await _checkPermission();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _checkPermission() async {
    final granted = await NotificationService.areNotificationsEnabled();
    if (mounted) setState(() => _notifPermissionGranted = granted);
  }

  Future<void> _setTugas(bool value) async {
    setState(() => _tugasEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefNotifTugasEnabled, value);
  }

  Future<void> _setPresensi(bool value) async {
    setState(() => _presensiEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefNotifPresensiEnabled, value);
  }

  Future<void> _fixPermission() async {
    final granted = await NotificationService.requestPermission();
    if (!granted) {
      // Already denied before, the OS won't show the prompt again,
      // so send the user straight to the system settings screen.
      await NotificationService.openAppNotificationSettings();
    }
    await _checkPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Pengaturan Notifikasi',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                _StatusHero(
                  granted: _notifPermissionGranted,
                  onFix: _fixPermission,
                ),
                const SizedBox(height: 28),
                _SectionLabel('KATEGORI'),
                const SizedBox(height: 10),
                _RoundedGroup(
                  children: [
                    _ToggleRow(
                      icon: Icons.assignment_rounded,
                      color: AppTheme.primary,
                      title: 'Notifikasi Tugas',
                      subtitle: 'Tugas baru, deadline H-24/H-3, tugas terlewat',
                      value: _tugasEnabled,
                      onChanged: _setTugas,
                    ),
                    const _RowDivider(),
                    _ToggleRow(
                      icon: Icons.how_to_reg_rounded,
                      color: AppTheme.warning,
                      title: 'Notifikasi Presensi',
                      subtitle: 'Saat presensi mata kuliah dibuka',
                      value: _presensiEnabled,
                      onChanged: _setPresensi,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SectionLabel('SUARA & GAYA NOTIFIKASI'),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Setiap kategori punya pengaturan suara sendiri di HP kamu, pilih sesuai selera.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 10),
                _RoundedGroup(
                  children: [
                    _ChannelRow(
                      icon: Icons.notifications_rounded,
                      color: AppTheme.primary,
                      title: AppConstants.notifChannelName,
                      subtitle: 'Nada dering & getar untuk tugas baru',
                      onTap: () => NotificationService.openChannelSettings(
                        AppConstants.notifChannelId,
                      ),
                    ),
                    const _RowDivider(),
                    _ChannelRow(
                      icon: Icons.alarm_rounded,
                      color: AppTheme.danger,
                      title: AppConstants.deadlineChannelName,
                      subtitle: 'Nada dering & getar untuk deadline dan tugas terlewat',
                      onTap: () => NotificationService.openChannelSettings(
                        AppConstants.deadlineChannelId,
                      ),
                    ),
                    const _RowDivider(),
                    _ChannelRow(
                      icon: Icons.how_to_reg_rounded,
                      color: AppTheme.warning,
                      title: AppConstants.presensiChannelName,
                      subtitle: 'Nada dering & getar untuk presensi dibuka',
                      onTap: () => NotificationService.openChannelSettings(
                        AppConstants.presensiChannelId,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton.icon(
                    onPressed: NotificationService.openAppNotificationSettings,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Buka semua pengaturan notifikasi HP'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  final bool granted;
  final VoidCallback onFix;

  const _StatusHero({required this.granted, required this.onFix});

  @override
  Widget build(BuildContext context) {
    final color = granted ? AppTheme.primary : AppTheme.danger;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: granted
              ? [AppTheme.primary, AppTheme.primaryDark]
              : [AppTheme.danger, const Color(0xFFB71C1C)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              granted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  granted ? 'Notifikasi aktif' : 'Notifikasi belum aktif',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  granted
                      ? 'Tugas dan presensi akan sampai tepat waktu'
                      : 'Aktifkan supaya tugas dan presensi tidak terlewat',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (!granted) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onFix,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.danger,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: const Text(
                'Aktifkan',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Colors.grey[500],
        ),
      ),
    );
  }
}

class _RoundedGroup extends StatelessWidget {
  final List<Widget> children;
  const _RoundedGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChannelRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _IconBadge(icon: icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
