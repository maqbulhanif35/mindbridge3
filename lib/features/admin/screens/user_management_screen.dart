// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
// ignore: undefined_hidden_name
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../providers/admin_provider.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _selectedRole = 'all';
  AdminUserEntry? _selectedUser;
  final Set<String> _selectedIds = {};
  bool _bulkMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminProvider.notifier).loadUsers(reset: true);
    });
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      final state = ref.read(adminProvider);
      if (!state.isLoading) {
        ref
            .read(adminProvider.notifier)
            .loadUsers(page: state.users.length ~/ 50);
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _exportCsv(List<AdminUserEntry> users) {
    final buf = StringBuffer();
    buf.writeln('Name,Email,University,Faculty,Year,Role,Banned,Onboarded,Mood Logs,Journal,Streak,Joined');
    for (final u in users) {
      buf.writeln([
        _csvCell(u.name),
        _csvCell(u.email),
        _csvCell(u.university ?? ''),
        _csvCell(u.faculty ?? ''),
        u.yearOfStudy?.toString() ?? '',
        u.role,
        u.isBanned ? 'Yes' : 'No',
        u.onboardingCompleted ? 'Yes' : 'No',
        u.moodCount.toString(),
        u.journalCount.toString(),
        u.streakDays.toString(),
        DateFormat('yyyy-MM-dd').format(u.createdAt),
      ].join(','));
    }
    final bytes = utf8.encode(buf.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'mindbridge_users_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _csvCell(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  void _toggleBulkMode() {
    setState(() {
      _bulkMode = !_bulkMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<AdminUserEntry> users) {
    setState(() {
      if (_selectedIds.length == users.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(users.map((u) => u.id));
      }
    });
  }

  void _openUserDetail(BuildContext context, AdminUserEntry user) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, ctrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: _UserDetailPanel(
                    user: user,
                    onClose: () => Navigator.pop(_),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      setState(() => _selectedUser = user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    return Column(
      children: [
        // ── Stats Header ────────────────────────────────
        _StatsHeader(stats: state.stats),

        // ── Toolbar ────────────────────────────────────
        _UserToolbar(
          searchCtrl: _searchCtrl,
          selectedRole: _selectedRole,
          showBannedOnly: state.showBannedOnly,
          totalCount: state.users.length,
          bulkMode: _bulkMode,
          selectedCount: _selectedIds.length,
          onSearch: (q) => ref.read(adminProvider.notifier).setUserSearch(q),
          onRoleFilter: (r) {
            setState(() => _selectedRole = r);
            ref.read(adminProvider.notifier).setRoleFilter(r);
          },
          onBannedToggle: () => ref.read(adminProvider.notifier).toggleBannedFilter(),
          onExport: () => _exportCsv(
            _selectedIds.isEmpty
                ? state.users
                : state.users.where((u) => _selectedIds.contains(u.id)).toList(),
          ),
          onCreateUser: () => _showCreateUserDialog(context),
          onToggleBulk: _toggleBulkMode,
          onBulkBan: _selectedIds.isEmpty
              ? null
              : () => _bulkBan(context, state.users),
          onBulkExport: _selectedIds.isEmpty
              ? null
              : () => _exportCsv(
                    state.users.where((u) => _selectedIds.contains(u.id)).toList()),
        ),

        // ── Bulk Action Bar ─────────────────────────────
        if (_bulkMode)
          _BulkActionBar(
            selectedCount: _selectedIds.length,
            totalCount: state.users.length,
            onSelectAll: () => _selectAll(state.users),
            onClearSelection: () => setState(() => _selectedIds.clear()),
            onBanSelected: _selectedIds.isEmpty ? null : () => _bulkBan(context, state.users),
            onExportSelected: _selectedIds.isEmpty
                ? null
                : () => _exportCsv(
                      state.users.where((u) => _selectedIds.contains(u.id)).toList()),
          ),

        // ── Main Content ────────────────────────────────
        Expanded(
          child: _selectedUser != null && !isMobile
              ? Row(
                  children: [
                    Expanded(
                      child: _UserTable(
                        state: state,
                        bulkMode: _bulkMode,
                        selectedIds: _selectedIds,
                        scrollCtrl: _scrollCtrl,
                        onSelect: (u) => _openUserDetail(context, u),
                        onToggleSelect: _toggleSelect,
                      ),
                    ),
                    Container(width: 1, color: AppColors.border),
                    SizedBox(
                      width: 440,
                      child: _UserDetailPanel(
                        user: _selectedUser!,
                        onClose: () => setState(() => _selectedUser = null),
                      ),
                    ),
                  ],
                )
              : state.isLoading && state.users.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                  : state.error != null && state.users.isEmpty
                      ? _ErrorState(
                          message: state.error!,
                          onRetry: () =>
                              ref.read(adminProvider.notifier).loadUsers(reset: true))
                      : state.users.isEmpty
                          ? const _EmptyState()
                          : _UserTable(
                              state: state,
                              bulkMode: _bulkMode,
                              selectedIds: _selectedIds,
                              scrollCtrl: _scrollCtrl,
                              onSelect: (u) => _openUserDetail(context, u),
                              onToggleSelect: _toggleSelect,
                            ),
        ),
      ],
    );
  }

  Future<void> _bulkBan(BuildContext context, List<AdminUserEntry> users) async {
    final targets = users.where((u) => _selectedIds.contains(u.id) && !u.isBanned).toList();
    if (targets.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Text('Ban ${targets.length} users?'),
        content: Text(
          'This will prevent ${targets.length} user(s) from accessing MindBridge.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(_, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Ban All'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final u in targets) {
      await ref.read(adminProvider.notifier).banUser(u.id, 'Bulk ban by admin');
    }
    setState(() => _selectedIds.clear());
  }

  Future<void> _showCreateUserDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final uniCtrl = TextEditingController();
    String role = 'user';
    bool creating = false;
    String? errorMsg;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          child: SizedBox(
            width: 480,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: AppRadius.smAll,
                          ),
                          child: const Icon(LucideIcons.userPlus,
                              size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Create New User',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: const Icon(LucideIcons.x, size: 18),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Error banner
                    if (errorMsg != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: AppRadius.smAll,
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.circleAlert,
                                size: 14, color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(errorMsg!,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.error)),
                            ),
                          ],
                        ),
                      ),

                    // Full Name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: const Icon(LucideIcons.user, size: 16),
                        border:
                            OutlineInputBorder(borderRadius: AppRadius.smAll),
                        isDense: true,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Name required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Email
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: const Icon(LucideIcons.mail, size: 16),
                        border:
                            OutlineInputBorder(borderRadius: AppRadius.smAll),
                        isDense: true,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email required';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // University
                    TextFormField(
                      controller: uniCtrl,
                      decoration: InputDecoration(
                        labelText: 'University (optional)',
                        prefixIcon:
                            const Icon(LucideIcons.building2, size: 16),
                        border:
                            OutlineInputBorder(borderRadius: AppRadius.smAll),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Role
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        prefixIcon:
                            const Icon(LucideIcons.shield, size: 16),
                        border:
                            OutlineInputBorder(borderRadius: AppRadius.smAll),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('User')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(
                            value: 'superadmin', child: Text('Superadmin')),
                      ],
                      onChanged: (v) => setState(() => role = v ?? 'user'),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.infoContainer,
                        borderRadius: AppRadius.smAll,
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.info,
                              size: 13, color: AppColors.info),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'The user will be created without a password. They must use "Forgot Password" to set their password before logging in.',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.info),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: creating
                              ? null
                              : () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: creating
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setState(() {
                                    creating = true;
                                    errorMsg = null;
                                  });
                                  final result = await ref
                                      .read(adminProvider.notifier)
                                      .createUser(
                                        name: nameCtrl.text.trim(),
                                        email: emailCtrl.text.trim(),
                                        university: uniCtrl.text.trim().isEmpty
                                            ? null
                                            : uniCtrl.text.trim(),
                                        role: role,
                                      );
                                  if (!dialogCtx.mounted) return;
                                  if (result == null ||
                                      result.containsKey('error')) {
                                    setState(() {
                                      creating = false;
                                      errorMsg =
                                          result?['error']?.toString() ??
                                              'Failed to create user. Try again.';
                                    });
                                  } else {
                                    Navigator.pop(dialogCtx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'User ${nameCtrl.text.trim()} created successfully'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: creating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(LucideIcons.userPlus, size: 14),
                          label: Text(creating ? 'Creating…' : 'Create User'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Stats Header ─────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final AdminStats stats;
  const _StatsHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D5C57), AppColors.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: const Icon(LucideIcons.users, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User Management',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    Text('Manage accounts, roles & access',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
          _StatChip(
            icon: LucideIcons.users,
            label: 'Total',
            value: stats.totalUsers.toString(),
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: LucideIcons.activity,
            label: 'Active Today',
            value: stats.activeToday.toString(),
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: LucideIcons.userPlus,
            label: 'New This Week',
            value: stats.newUsersThisWeek.toString(),
            color: AppColors.info,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: LucideIcons.ban,
            label: 'Banned',
            value: stats.bannedUsers.toString(),
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: LucideIcons.loader,
            label: 'Pending',
            value: stats.pendingOnboarding.toString(),
            color: AppColors.warning,
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

// ─── Toolbar ──────────────────────────────────────────────

class _UserToolbar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String selectedRole;
  final bool showBannedOnly;
  final int totalCount;
  final bool bulkMode;
  final int selectedCount;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onRoleFilter;
  final VoidCallback onBannedToggle;
  final VoidCallback onExport;
  final VoidCallback onCreateUser;
  final VoidCallback onToggleBulk;
  final VoidCallback? onBulkBan;
  final VoidCallback? onBulkExport;

  const _UserToolbar({
    required this.searchCtrl,
    required this.selectedRole,
    required this.showBannedOnly,
    required this.totalCount,
    required this.bulkMode,
    required this.selectedCount,
    required this.onSearch,
    required this.onRoleFilter,
    required this.onBannedToggle,
    required this.onExport,
    required this.onCreateUser,
    required this.onToggleBulk,
    this.onBulkBan,
    this.onBulkExport,
  });

  Widget _searchField() => Container(
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.smAll,
        ),
        child: TextField(
          controller: searchCtrl,
          onChanged: onSearch,
          decoration: const InputDecoration(
            hintText: 'Search name, email, university…',
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: Icon(LucideIcons.search, size: 15, color: AppColors.textMuted),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      );

  Widget _roleDropdown() => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.smAll,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedRole,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Roles')),
              DropdownMenuItem(value: 'user', child: Text('Users')),
              DropdownMenuItem(value: 'admin', child: Text('Admins')),
              DropdownMenuItem(value: 'superadmin', child: Text('Superadmins')),
            ],
            onChanged: (v) => onRoleFilter(v ?? 'all'),
          ),
        ),
      );

  Widget _bannedChip() => FilterChip(
        label: const Text('Banned', style: TextStyle(fontSize: 11)),
        selected: showBannedOnly,
        onSelected: (_) => onBannedToggle(),
        selectedColor: AppColors.errorContainer,
        checkmarkColor: AppColors.error,
        visualDensity: VisualDensity.compact,
      );

  Widget _bulkBtn() => Tooltip(
        message: bulkMode ? 'Exit bulk select' : 'Bulk select',
        child: InkWell(
          borderRadius: AppRadius.smAll,
          onTap: onToggleBulk,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: bulkMode ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
              border: Border.all(color: bulkMode ? AppColors.primary : AppColors.border),
              borderRadius: AppRadius.smAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.squareCheck,
                    size: 14,
                    color: bulkMode ? AppColors.primary : AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  bulkMode && selectedCount > 0 ? '$selectedCount sel.' : 'Select',
                  style: TextStyle(
                      fontSize: 11,
                      color: bulkMode ? AppColors.primary : AppColors.textMuted,
                      fontWeight: bulkMode ? FontWeight.w600 : null),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _exportBtn() => OutlinedButton.icon(
        onPressed: onExport,
        icon: const Icon(LucideIcons.download, size: 14),
        label: const Text('Export', style: TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          visualDensity: VisualDensity.compact,
        ),
      );

  Widget _addBtn() => ElevatedButton.icon(
        onPressed: onCreateUser,
        icon: const Icon(LucideIcons.userPlus, size: 14),
        label: const Text('Add User', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          visualDensity: VisualDensity.compact,
          elevation: 0,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _searchField(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _roleDropdown(),
                    _bannedChip(),
                    _bulkBtn(),
                    _exportBtn(),
                    _addBtn(),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _searchField()),
                const SizedBox(width: 8),
                _roleDropdown(),
                const SizedBox(width: 6),
                _bannedChip(),
                const SizedBox(width: 6),
                _bulkBtn(),
                const SizedBox(width: 6),
                _exportBtn(),
                const SizedBox(width: 6),
                _addBtn(),
              ],
            ),
    );
  }
}

// ─── Bulk Action Bar ──────────────────────────────────────

class _BulkActionBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback? onBanSelected;
  final VoidCallback? onExportSelected;

  const _BulkActionBar({
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onClearSelection,
    this.onBanSelected,
    this.onExportSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(LucideIcons.squareCheck, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            '$selectedCount of $totalCount selected',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onSelectAll,
            style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Text(
              selectedCount == totalCount ? 'Deselect All' : 'Select All',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          if (selectedCount > 0)
            TextButton(
              onPressed: onClearSelection,
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Clear', style: TextStyle(fontSize: 11)),
            ),
          const Spacer(),
          if (onExportSelected != null)
            OutlinedButton.icon(
              onPressed: onExportSelected,
              icon: const Icon(LucideIcons.download, size: 13),
              label: const Text('Export Selected', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          const SizedBox(width: 6),
          if (onBanSelected != null)
            ElevatedButton.icon(
              onPressed: onBanSelected,
              icon: const Icon(LucideIcons.ban, size: 13),
              label: const Text('Ban Selected', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── User Table ───────────────────────────────────────────

class _UserTable extends ConsumerWidget {
  final AdminState state;
  final bool bulkMode;
  final Set<String> selectedIds;
  final ScrollController scrollCtrl;
  final ValueChanged<AdminUserEntry> onSelect;
  final ValueChanged<String> onToggleSelect;

  const _UserTable({
    required this.state,
    required this.bulkMode,
    required this.selectedIds,
    required this.scrollCtrl,
    required this.onSelect,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(12),
      itemCount: state.users.length + (state.isLoading ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        if (i == state.users.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
            ),
          );
        }
        final user = state.users[i];
        return _UserRow(
          user: user,
          bulkMode: bulkMode,
          isSelected: selectedIds.contains(user.id),
          onTap: bulkMode ? () => onToggleSelect(user.id) : () => onSelect(user),
          onBan: user.isBanned
              ? () => _confirmUnban(context, ref, user)
              : () => _confirmBan(context, ref, user),
          onRoleChange: (role) => _confirmRoleChange(context, ref, user, role),
          onResetPassword: () => _resetPassword(context, ref, user),
          onDelete: () => _confirmDelete(context, ref, user),
          delay: Duration(milliseconds: i * 25),
        );
      },
    );
  }

  void _confirmBan(BuildContext ctx, WidgetRef ref, AdminUserEntry user) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Text('Ban ${user.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will prevent ${user.email} from accessing MindBridge.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Ban User'),
          ),
        ],
      ),
    );
    if (confirmed == true && reasonCtrl.text.trim().isNotEmpty) {
      await ref.read(adminProvider.notifier).banUser(user.id, reasonCtrl.text.trim());
    }
  }

  void _confirmUnban(BuildContext ctx, WidgetRef ref, AdminUserEntry user) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Text('Unban ${user.name}?'),
        content: Text('This will restore access for ${user.email}.',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success, foregroundColor: Colors.white),
            child: const Text('Unban'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(adminProvider.notifier).unbanUser(user.id);
    }
  }

  void _confirmRoleChange(BuildContext ctx, WidgetRef ref, AdminUserEntry user, String newRole) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Text('Change Role'),
        content: Text(
          'Change ${user.name}\'s role to "${newRole.toUpperCase()}"?\n\nThis affects their access and permissions.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(adminProvider.notifier).changeUserRole(user.id, newRole);
    }
  }

  void _resetPassword(BuildContext ctx, WidgetRef ref, AdminUserEntry user) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Text('Reset Password'),
        content: Text(
          'Send a password reset link to ${user.email}?',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info, foregroundColor: Colors.white),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await ref.read(adminProvider.notifier).resetUserPassword(user.email);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(ok ? 'Reset link sent to ${user.email}' : 'Failed to send reset link'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
        ));
      }
    }
  }

  void _confirmDelete(BuildContext ctx, WidgetRef ref, AdminUserEntry user) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Text('Delete ${user.name}?'),
        content: const Text(
          'This permanently deletes the user and all their data. This cannot be undone.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(adminProvider.notifier).deleteUser(user.id);
    }
  }
}

class _UserRow extends ConsumerWidget {
  final AdminUserEntry user;
  final bool bulkMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onBan;
  final ValueChanged<String> onRoleChange;
  final VoidCallback onResetPassword;
  final VoidCallback onDelete;
  final Duration delay;

  const _UserRow({
    required this.user,
    required this.bulkMode,
    required this.isSelected,
    required this.onTap,
    required this.onBan,
    required this.onRoleChange,
    required this.onResetPassword,
    required this.onDelete,
    required this.delay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleColor = _roleColor(user.role);
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    if (isMobile) {
      return _buildMobileCard(context, ref, roleColor);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer
                : user.isBanned
                    ? AppColors.errorContainer
                    : Colors.white,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : user.isBanned
                      ? AppColors.error.withValues(alpha: 0.3)
                      : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              // Checkbox or Avatar
              if (bulkMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],

              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.pillAll,
                ),
                child: Center(
                  child: Text(
                    user.initials,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: roleColor,
                        fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Name + email
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isBanned) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: AppRadius.xsAll,
                            ),
                            child: const Text('BANNED',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // University
              Expanded(
                flex: 2,
                child: Text(
                  user.university ?? '—',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Stats row (mood, journal, streak)
              SizedBox(
                width: 120,
                child: Row(
                  children: [
                    _MiniStat(
                        icon: LucideIcons.heart,
                        value: user.moodCount.toString(),
                        color: AppColors.secondary),
                    const SizedBox(width: 8),
                    _MiniStat(
                        icon: LucideIcons.bookOpen,
                        value: user.journalCount.toString(),
                        color: AppColors.tertiary),
                    const SizedBox(width: 8),
                    _MiniStat(
                        icon: LucideIcons.flame,
                        value: '${user.streakDays}d',
                        color: AppColors.warning),
                  ],
                ),
              ),

              // Joined
              SizedBox(
                width: 78,
                child: Text(
                  DateFormat('d MMM yy').format(user.createdAt),
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ),

              // Role badge
              SizedBox(
                width: 100,
                child: _RoleDropdown(
                  currentRole: user.role,
                  onChanged: onRoleChange,
                  color: roleColor,
                ),
              ),

              // Actions
              if (!bulkMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionIcon(
                      icon: LucideIcons.eye,
                      color: AppColors.textMuted,
                      tooltip: 'View Details',
                      onTap: onTap,
                    ),
                    _ActionIcon(
                      icon: LucideIcons.mail,
                      color: AppColors.info,
                      tooltip: 'Email User',
                      onTap: () => _showEmailDialog(context, ref, user),
                    ),
                    _ActionIcon(
                      icon: LucideIcons.keyRound,
                      color: AppColors.warning,
                      tooltip: 'Reset Password',
                      onTap: onResetPassword,
                    ),
                    _ActionIcon(
                      icon: user.isBanned ? LucideIcons.lockOpen : LucideIcons.ban,
                      color: user.isBanned ? AppColors.success : AppColors.error,
                      tooltip: user.isBanned ? 'Unban' : 'Ban User',
                      onTap: onBan,
                    ),
                    _ActionIcon(
                      icon: LucideIcons.trash2,
                      color: AppColors.error,
                      tooltip: 'Delete User',
                      onTap: onDelete,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ).animate(delay: delay).fadeIn(duration: 180.ms).slideY(begin: 0.04);
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'superadmin':
        return const Color(0xFF8B5CF6);
      case 'admin':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildMobileCard(BuildContext context, WidgetRef ref, Color roleColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer
                : user.isBanned
                    ? AppColors.errorContainer
                    : Colors.white,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : user.isBanned
                      ? AppColors.error.withValues(alpha: 0.3)
                      : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              if (bulkMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  activeColor: AppColors.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
              ],
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.pillAll,
                ),
                child: Center(
                  child: Text(
                    user.initials,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: roleColor,
                        fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name + email + role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isBanned) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: AppRadius.xsAll,
                            ),
                            child: const Text('BANNED',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    _RoleBadge(role: user.role),
                  ],
                ),
              ),
              // Compact actions
              if (!bulkMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionIcon(
                      icon: LucideIcons.eye,
                      color: AppColors.textMuted,
                      tooltip: 'View',
                      onTap: onTap,
                    ),
                    _ActionIcon(
                      icon: user.isBanned ? LucideIcons.lockOpen : LucideIcons.ban,
                      color: user.isBanned ? AppColors.success : AppColors.error,
                      tooltip: user.isBanned ? 'Unban' : 'Ban',
                      onTap: onBan,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ).animate(delay: delay).fadeIn(duration: 180.ms).slideY(begin: 0.04);
  }

  static Future<void> _showEmailDialog(
      BuildContext ctx, WidgetRef ref, AdminUserEntry user) async {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    bool sending = false;

    await showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: const Icon(LucideIcons.mail, size: 16, color: AppColors.info),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Email User',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(user.email,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectCtrl,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(borderRadius: AppRadius.smAll),
                    prefixIcon: const Icon(LucideIcons.tag, size: 16),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: AppRadius.smAll),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.infoContainer,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: const Row(
                    children: [
                      Icon(LucideIcons.info, size: 13, color: AppColors.info),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Logged in broadcast history.',
                          style: TextStyle(fontSize: 11, color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: sending
                  ? null
                  : () async {
                      if (subjectCtrl.text.trim().isEmpty ||
                          messageCtrl.text.trim().isEmpty) return;
                      setState(() => sending = true);
                      final ok =
                          await ref.read(adminProvider.notifier).emailUser(
                                toEmail: user.email,
                                toName: user.name,
                                subject: subjectCtrl.text.trim(),
                                message: messageCtrl.text.trim(),
                                fromAdminName: 'MindBridge Admin',
                              );
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(ok
                              ? 'Email sent to ${user.name}'
                              : 'Failed to send email'),
                          backgroundColor:
                              ok ? AppColors.success : AppColors.error,
                        ));
                      }
                    },
              icon: sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.send, size: 14),
              label: Text(sending ? 'Sending…' : 'Send'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _MiniStat({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.9))),
        ],
      );
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: AppRadius.xsAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 14, color: color),
          ),
        ),
      );
}

class _RoleDropdown extends StatelessWidget {
  final String currentRole;
  final ValueChanged<String> onChanged;
  final Color color;

  const _RoleDropdown({
    required this.currentRole,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.xsAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentRole,
          isDense: true,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color),
          icon: Icon(Icons.keyboard_arrow_down, size: 13, color: color),
          items: const [
            DropdownMenuItem(value: 'user', child: Text('USER')),
            DropdownMenuItem(value: 'admin', child: Text('ADMIN')),
            DropdownMenuItem(value: 'superadmin', child: Text('SUPERADMIN')),
          ],
          onChanged: (v) {
            if (v != null && v != currentRole) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ─── User Detail Panel ────────────────────────────────────

class _UserDetailPanel extends ConsumerStatefulWidget {
  final AdminUserEntry user;
  final VoidCallback onClose;

  const _UserDetailPanel({required this.user, required this.onClose});

  @override
  ConsumerState<_UserDetailPanel> createState() => _UserDetailPanelState();
}

class _UserDetailPanelState extends ConsumerState<_UserDetailPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  Map<String, dynamic> _detail = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await ref
        .read(adminProvider.notifier)
        .loadUserDetail(widget.user.id);
    if (mounted) setState(() { _detail = d; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final roleColor = user.role == 'superadmin'
        ? const Color(0xFF8B5CF6)
        : user.role == 'admin'
            ? AppColors.primary
            : AppColors.textSecondary;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  roleColor.withValues(alpha: 0.08),
                  Colors.white,
                ],
              ),
              border: const Border(
                  bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                // Close + actions row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      const Text(
                        'User Profile',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      _ActionIcon(
                        icon: LucideIcons.mail,
                        color: AppColors.info,
                        tooltip: 'Email User',
                        onTap: () => _UserRow._showEmailDialog(
                            context, ref, widget.user),
                      ),
                      _ActionIcon(
                        icon: LucideIcons.keyRound,
                        color: AppColors.warning,
                        tooltip: 'Reset Password',
                        onTap: () async {
                          final ok = await ref
                              .read(adminProvider.notifier)
                              .resetUserPassword(user.email);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(ok
                                  ? 'Reset link sent to ${user.email}'
                                  : 'Failed to send reset link'),
                              backgroundColor:
                                  ok ? AppColors.success : AppColors.error,
                            ));
                          }
                        },
                      ),
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(LucideIcons.x, size: 16),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),

                // Avatar + identity
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [roleColor, roleColor.withValues(alpha: 0.6)],
                          ),
                          borderRadius: AppRadius.pillAll,
                          boxShadow: [
                            BoxShadow(
                                color: roleColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user.initials,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.textPrimary),
                            ),
                            Text(
                              user.email,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _RoleBadge(role: user.role),
                                const SizedBox(width: 6),
                                if (user.isBanned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      borderRadius: AppRadius.pillAll,
                                    ),
                                    child: const Text('BANNED',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700)),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.successContainer,
                                      borderRadius: AppRadius.pillAll,
                                    ),
                                    child: const Text('ACTIVE',
                                        style: TextStyle(
                                            color: AppColors.success,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick stats row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.border),
                      bottom: BorderSide(color: AppColors.border),
                    ),
                    color: AppColors.surfaceVariant,
                  ),
                  child: Row(
                    children: [
                      _QuickStat(
                          label: 'Moods',
                          value: user.moodCount.toString(),
                          icon: LucideIcons.heart,
                          color: AppColors.secondary),
                      _QuickStatDivider(),
                      _QuickStat(
                          label: 'Journals',
                          value: user.journalCount.toString(),
                          icon: LucideIcons.bookOpen,
                          color: AppColors.tertiary),
                      _QuickStatDivider(),
                      _QuickStat(
                          label: 'Streak',
                          value: '${user.streakDays}d',
                          icon: LucideIcons.flame,
                          color: AppColors.warning),
                    ],
                  ),
                ),

                // Tabs
                TabBar(
                  controller: _tab,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 12),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Activity'),
                    Tab(text: 'Moderation'),
                  ],
                ),
              ],
            ),
          ),

          // ── Tab Content ────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2))
                : TabBarView(
                    controller: _tab,
                    children: [
                      _OverviewTab(user: user, detail: _detail),
                      _ActivityTab(detail: _detail),
                      _ModerationTab(
                        user: user,
                        detail: _detail,
                        onBan: () async {
                          final reasonCtrl = TextEditingController();
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text('Ban ${user.name}?'),
                              content: TextField(
                                controller: reasonCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Reason',
                                    border: OutlineInputBorder()),
                                maxLines: 2,
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(_, false),
                                    child: const Text('Cancel')),
                                ElevatedButton(
                                    onPressed: () => Navigator.pop(_, true),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.error,
                                        foregroundColor: Colors.white),
                                    child: const Text('Ban')),
                              ],
                            ),
                          );
                          if (confirmed == true &&
                              reasonCtrl.text.trim().isNotEmpty) {
                            await ref
                                .read(adminProvider.notifier)
                                .banUser(user.id, reasonCtrl.text.trim());
                            _load();
                          }
                        },
                        onUnban: () async {
                          await ref
                              .read(adminProvider.notifier)
                              .unbanUser(user.id);
                          _load();
                        },
                        onWarn: () async {
                          final reasonCtrl = TextEditingController();
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Warn User'),
                              content: TextField(
                                controller: reasonCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Warning reason',
                                    border: OutlineInputBorder()),
                                maxLines: 2,
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(_, false),
                                    child: const Text('Cancel')),
                                ElevatedButton(
                                    onPressed: () => Navigator.pop(_, true),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.warning,
                                        foregroundColor: Colors.white),
                                    child: const Text('Issue Warning')),
                              ],
                            ),
                          );
                          if (confirmed == true &&
                              reasonCtrl.text.trim().isNotEmpty) {
                            await ref
                                .read(adminProvider.notifier)
                                .warnUser(user.id, reasonCtrl.text.trim());
                            _load();
                          }
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final AdminUserEntry user;
  final Map<String, dynamic> detail;

  const _OverviewTab({required this.user, required this.detail});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Personal Info'),
          _InfoRow('Email', user.email),
          _InfoRow('University', user.university ?? 'Not set'),
          _InfoRow('Faculty', user.faculty ?? 'Not set'),
          _InfoRow('Year', user.yearOfStudy?.toString() ?? 'Not set'),
          _InfoRow('Joined', DateFormat('MMM d, yyyy').format(user.createdAt)),
          _InfoRow('Onboarding',
              user.onboardingCompleted ? 'Completed' : 'Pending'),

          const SizedBox(height: 16),
          const _SectionLabel('Streaks'),
          if ((_detail_list(detail, 'streaks')).isEmpty)
            const Text('No streak data',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted))
          else
            ..._detail_list(detail, 'streaks').map((s) => _InfoRow(
                  _capitalize(
                      (s['streak_type'] as String? ?? '').replaceAll('_', ' ')),
                  '${s['current_streak'] ?? 0} days (best: ${s['longest_streak'] ?? 0})',
                )),

          const SizedBox(height: 16),
          const _SectionLabel('Achievements'),
          if ((_detail_list(detail, 'achievements')).isEmpty)
            const Text('No achievements yet',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _detail_list(detail, 'achievements')
                  .map((a) => _AchievementChip(
                        name: a['achievement_type'] as String? ?? '?',
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ─── Activity Tab ─────────────────────────────────────────

class _ActivityTab extends StatelessWidget {
  final Map<String, dynamic> detail;

  const _ActivityTab({required this.detail});

  @override
  Widget build(BuildContext context) {
    final moodLogs = _detail_list(detail, 'moodLogs');
    final chatSessions = _detail_list(detail, 'chatSessions');
    final journalCount = (detail['journalCount'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mood sparkline
          if (moodLogs.isNotEmpty) ...[
            const _SectionLabel('Mood History (last 30 logs)'),
            Container(
              height: 80,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.smAll,
              ),
              child: _MoodSparkline(logs: moodLogs),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${moodLogs.length} logs',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
                Text(
                  moodLogs.isNotEmpty
                      ? 'Latest: ${_moodLabel((moodLogs.last['mood_score'] as num?)?.toInt() ?? 5)}'
                      : '',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Summary stats
          const _SectionLabel('Content Summary'),
          Row(
            children: [
              Expanded(
                child: _ContentCard(
                  icon: LucideIcons.heart,
                  label: 'Mood Logs',
                  value: moodLogs.length.toString(),
                  sub: 'last 30',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ContentCard(
                  icon: LucideIcons.bookOpen,
                  label: 'Journal',
                  value: journalCount.toString(),
                  sub: 'entries',
                  color: AppColors.tertiary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ContentCard(
                  icon: LucideIcons.messageCircle,
                  label: 'Chats',
                  value: chatSessions.length.toString(),
                  sub: 'recent',
                  color: AppColors.info,
                ),
              ),
            ],
          ),

          if (chatSessions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionLabel('Recent Chat Sessions'),
            ...chatSessions.take(5).map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.messageCircle,
                          size: 13, color: AppColors.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Session · ${_formatDate(s['created_at'] as String?)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ─── Moderation Tab ───────────────────────────────────────

class _ModerationTab extends StatelessWidget {
  final AdminUserEntry user;
  final Map<String, dynamic> detail;
  final VoidCallback onBan;
  final VoidCallback onUnban;
  final VoidCallback onWarn;

  const _ModerationTab({
    required this.user,
    required this.detail,
    required this.onBan,
    required this.onUnban,
    required this.onWarn,
  });

  @override
  Widget build(BuildContext context) {
    final flags = _detail_list(detail, 'flags');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick actions
          const _SectionLabel('Quick Actions'),
          Row(
            children: [
              Expanded(
                child: _ModActionBtn(
                  icon: LucideIcons.triangleAlert,
                  label: 'Warn User',
                  color: AppColors.warning,
                  onTap: onWarn,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: user.isBanned
                    ? _ModActionBtn(
                        icon: LucideIcons.lockOpen,
                        label: 'Unban User',
                        color: AppColors.success,
                        onTap: onUnban,
                      )
                    : _ModActionBtn(
                        icon: LucideIcons.ban,
                        label: 'Ban User',
                        color: AppColors.error,
                        onTap: onBan,
                      ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Current status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: user.isBanned
                  ? AppColors.errorContainer
                  : AppColors.successContainer,
              borderRadius: AppRadius.smAll,
              border: Border.all(
                color: user.isBanned
                    ? AppColors.error.withValues(alpha: 0.3)
                    : AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  user.isBanned ? LucideIcons.ban : LucideIcons.circleCheck,
                  size: 16,
                  color: user.isBanned ? AppColors.error : AppColors.success,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.isBanned ? 'Account Banned' : 'Account Active',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: user.isBanned
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                      Text(
                        user.isBanned
                            ? 'User cannot log in or access the app.'
                            : 'User has full access to MindBridge.',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const _SectionLabel('Flag History'),

          if (flags.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(LucideIcons.shieldCheck,
                        size: 32, color: AppColors.success),
                    SizedBox(height: 8),
                    Text('No flags on record',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            )
          else
            ...flags.map((f) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: AppRadius.smAll,
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: AppRadius.pillAll,
                        ),
                        child: const Icon(LucideIcons.circleAlert,
                            size: 14, color: AppColors.error),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _capitalize(
                                      f['flag_type'] as String? ?? ''),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error),
                                ),
                                const Spacer(),
                                if (f['is_active'] == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      borderRadius: AppRadius.pillAll,
                                    ),
                                    child: const Text('Active',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700)),
                                  ),
                              ],
                            ),
                            if (f['reason'] != null)
                              Text(f['reason'] as String,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                            if (f['created_at'] != null)
                              Text(
                                _formatDate(f['created_at'] as String?),
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.textMuted),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────

class _MoodSparkline extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const _MoodSparkline({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) return const SizedBox.shrink();
    final scores = logs
        .map((l) => (l['mood_score'] as num?)?.toDouble() ?? 5.0)
        .toList();
    return CustomPaint(
      painter: _SparklinePainter(scores: scores),
      size: const Size(double.infinity, 60),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> scores;
  const _SparklinePainter({required this.scores});

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2) return;
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.3),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final minScore = 1.0;
    final maxScore = 10.0;
    final xStep = size.width / (scores.length - 1);

    Offset toPoint(int i) {
      final x = i * xStep;
      final y = size.height -
          ((scores[i] - minScore) / (maxScore - minScore)) * size.height;
      return Offset(x, y);
    }

    final path = Path();
    path.moveTo(toPoint(0).dx, toPoint(0).dy);
    for (int i = 1; i < scores.length; i++) {
      path.lineTo(toPoint(i).dx, toPoint(i).dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Dots for first and last
    final dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(toPoint(0), 3, dotPaint);
    canvas.drawCircle(toPoint(scores.length - 1), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.scores != scores;
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _QuickStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      );
}

class _QuickStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 32,
        color: AppColors.border,
      );
}

class _ContentCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _ContentCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.smAll,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            Text(sub,
                style:
                    const TextStyle(fontSize: 9, color: AppColors.textMuted)),
          ],
        ),
      );
}

class _ModActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: AppRadius.smAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: AppRadius.smAll,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      );
}

class _AchievementChip extends StatelessWidget {
  final String name;
  const _AchievementChip({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: AppRadius.pillAll,
        ),
        child: Text(
          _capitalize(name.replaceAll('_', ' ')),
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.primary),
        ),
      );
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = role == 'superadmin'
        ? const Color(0xFF8B5CF6)
        : role == 'admin'
            ? AppColors.primary
            : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.8),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}

// ─── Helper functions ─────────────────────────────────────

List<Map<String, dynamic>> _detail_list(Map<String, dynamic> d, String key) =>
    ((d[key] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _moodLabel(int score) {
  if (score >= 9) return 'Excellent ($score)';
  if (score >= 7) return 'Good ($score)';
  if (score >= 5) return 'Okay ($score)';
  if (score >= 3) return 'Low ($score)';
  return 'Critical ($score)';
}

String _formatDate(String? iso) {
  if (iso == null) return '—';
  try {
    return DateFormat('MMM d, yyyy').format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

// ─── Empty / Error States ─────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.users, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('No users found',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            SizedBox(height: 4),
            Text('Try adjusting your search or filters',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.circleAlert,
                    size: 32, color: AppColors.error),
                const SizedBox(height: 12),
                const Text('Failed to load users',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.error)),
                const SizedBox(height: 6),
                Text(message,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
}
