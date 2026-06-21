import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/assignment.dart';
import '../services/auth_service.dart';
import '../services/scraper_service.dart';
import '../widgets/assignment_card.dart';
import 'login_screen.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => TodoScreenState();
}

class TodoScreenState extends State<TodoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  Map<AssignmentStatus, List<Assignment>> _data = {
    AssignmentStatus.todo: [],
    AssignmentStatus.missed: [],
    AssignmentStatus.submitted: [],
  };
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void reload() => _load();

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await AuthService.getSession();
      if (session == null) {
        _redirectToLogin();
        return;
      }
      final result = await ScraperService(session).fetchTodo();
      if (mounted) setState(() => _data = result);
    } on SessionExpiredException {
      _redirectToLogin();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  List<Assignment> _get(AssignmentStatus status) => _data[status] ?? [];

  @override
  Widget build(BuildContext context) {
    final todoCount = _get(AssignmentStatus.todo).length;
    final missedCount = _get(AssignmentStatus.missed).length;
    final submittedCount = _get(AssignmentStatus.submitted).length;

    return Column(
      children: [
        Container(
          color: AppTheme.primary,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              _Tab('Todo', todoCount, AppTheme.warning),
              _Tab('Missed', missedCount, AppTheme.danger),
              _Tab('Submitted', submittedCount, AppTheme.success),
            ],
          ),
        ),
        if (_isLoading)
          const LinearProgressIndicator(
            color: AppTheme.primary,
            minHeight: 2,
          ),
        Expanded(
          child: _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _AssignmentList(
                        items: _get(AssignmentStatus.todo),
                        emptyMsg: 'Tidak ada tugas yang harus dilakukan',
                      ),
                      _AssignmentList(
                        items: _get(AssignmentStatus.missed),
                        emptyMsg: 'Tidak ada tugas yang terlewat',
                      ),
                      _AssignmentList(
                        items: _get(AssignmentStatus.submitted),
                        emptyMsg: 'Belum ada tugas yang dikumpulkan',
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int count;
  final Color badgeColor;

  const _Tab(this.label, this.count, this.badgeColor);

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignmentList extends StatelessWidget {
  final List<Assignment> items;
  final String emptyMsg;

  const _AssignmentList({required this.items, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              emptyMsg,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (_, i) => AssignmentCard(assignment: items[i]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
