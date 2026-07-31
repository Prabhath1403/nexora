import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class WorkHoursScreen extends StatefulWidget {
  const WorkHoursScreen({super.key});

  @override
  State<WorkHoursScreen> createState() => _WorkHoursScreenState();
}

class _WorkHoursScreenState extends State<WorkHoursScreen> {
  bool isClockedIn = false;
  String? activeLogId;
  int elapsedSeconds = 0;
  Timer? _timer;
  List<dynamic> logs = [];

  // Live Laptop Tracker Breakdown
  List<dynamic> appBreakdown = [];
  double totalWorkHours = 0.0;
  String? topApp;
  bool isDaemonActive = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    final fetchedLogs = await ApiService.fetchWorkLogs();
    final bdData = await ApiService.fetchAppBreakdown();
    final summaryData = await ApiService.fetchTrackerSummary();
    final daemonData = await ApiService.fetchDaemonStatus();

    if (!mounted) return;
    setState(() {
      logs = fetchedLogs;
      if (bdData != null && bdData['breakdown'] != null) {
        appBreakdown = bdData['breakdown'];
      }
      if (summaryData != null) {
        totalWorkHours = (summaryData['work_hours_today'] ?? 0.0).toDouble();
        topApp = summaryData['top_app'];
      }
      if (daemonData != null) {
        isDaemonActive = daemonData['active'] == true;
      }
      isLoading = false;
    });
  }

  void _toggleClock() async {
    if (!isClockedIn) {
      final log = await ApiService.startClock(null, "Work Session");
      if (log != null && mounted) {
        setState(() { isClockedIn = true; activeLogId = log['id']; elapsedSeconds = 0; });
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => elapsedSeconds++);
        });
      }
    } else {
      if (activeLogId != null) {
        await ApiService.stopClock(activeLogId!, "Session Complete");
        _timer?.cancel();
        if (mounted) setState(() { isClockedIn = false; activeLogId = null; });
        _loadData();
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    final h = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  IconData _getAppIcon(String appName) {
    final lower = appName.toLowerCase();
    if (lower.contains('antigravity') || lower.contains('code') || lower.contains('cursor') || lower.contains('pycharm')) {
      return Icons.code_rounded;
    } else if (lower.contains('terminal') || lower.contains('kitty') || lower.contains('alacritty')) {
      return Icons.terminal_rounded;
    } else if (lower.contains('chrome') || lower.contains('firefox') || lower.contains('brave') || lower.contains('edge')) {
      return Icons.language_rounded;
    } else if (lower.contains('docker')) {
      return Icons.view_in_ar_rounded;
    }
    return Icons.laptop_mac_rounded;
  }

  Color _getAppColor(String appName) {
    final lower = appName.toLowerCase();
    if (lower.contains('antigravity')) return AppTheme.accentPurple;
    if (lower.contains('code')) return AppTheme.accent;
    if (lower.contains('terminal')) return AppTheme.accentGreen;
    if (lower.contains('brave') || lower.contains('chrome')) return AppTheme.accentOrange;
    return AppTheme.accentTeal;
  }

  void _showAppDetailsModal(BuildContext context, String appName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: ApiService.fetchAppDetails(appName),
          builder: (context, snapshot) {
            final data = snapshot.data;
            final activities = (data?['activities'] as List?) ?? [];
            final totalHours = (data?['total_hours'] ?? 0.0).toDouble();

            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.secondaryBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 5,
                      decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: _getAppColor(appName).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                        child: Icon(_getAppIcon(appName), color: _getAppColor(appName), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(appName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                            Text(
                              appName.toLowerCase().contains('brave') || appName.toLowerCase().contains('chrome') || appName.toLowerCase().contains('firefox')
                                ? "Web Browsing & Research"
                                : "Development & Workspace",
                              style: const TextStyle(fontSize: 12, color: AppTheme.secondaryLabel),
                            ),
                          ],
                        ),
                      ),
                      Text("${totalHours.toStringAsFixed(1)}h",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _getAppColor(appName))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text(
                    appName.toLowerCase().contains('brave') || appName.toLowerCase().contains('chrome') || appName.toLowerCase().contains('firefox')
                        ? "OPEN WEBSITES & PAGES TODAY"
                        : "PROJECTS & WINDOW ACTIVITIES TODAY",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.secondaryLabel, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 10),

                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  else if (activities.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text("No detailed page activity recorded yet", style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 13))),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            children: List.generate(activities.length, (i) {
                              final act = activities[i];
                              final title = (act['title'] ?? 'Activity').toString();
                              final project = (act['project'] ?? '').toString();
                              final minutes = (act['minutes'] ?? 0).toInt();

                              return Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(
                                    _getAppIcon(appName),
                                    color: _getAppColor(appName), size: 20,
                                  ),
                                  title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  subtitle: project.isNotEmpty
                                      ? Text("Project: $project", style: const TextStyle(fontSize: 11, color: AppTheme.accentPurple, fontWeight: FontWeight.w600))
                                      : null,
                                  trailing: Text(minutes > 0 ? "${minutes}m" : "<1m",
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.secondaryLabel)),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: AppTheme.tertiaryBg,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close", style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.label)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TELEMETRY & TIMELOGS", style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      SizedBox(height: 2),
                      Text("Work Hours", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppTheme.accent),
                    onPressed: _loadData,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Stopwatch Display Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppTheme.secondaryBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isClockedIn ? AppTheme.accentGreen.withValues(alpha: 0.15) : AppTheme.tertiaryBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: isClockedIn || isDaemonActive ? AppTheme.accentGreen : AppTheme.accentOrange,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isClockedIn || isDaemonActive ? AppTheme.accentGreen : AppTheme.accentOrange).withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isClockedIn ? "Recording Manual Session" : (isDaemonActive ? "Laptop Daemon Active 🟢" : "Laptop Daemon Offline 🟧"),
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: isClockedIn || isDaemonActive ? AppTheme.accentGreen : AppTheme.accentOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _formatDuration(elapsedSeconds),
                    style: TextStyle(
                      fontSize: 52, fontWeight: FontWeight.w200, letterSpacing: 2,
                      fontFamily: '.SF UI Display',
                      color: isClockedIn ? AppTheme.label : AppTheme.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _toggleClock,
                    child: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isClockedIn ? AppTheme.accentRed : AppTheme.accentGreen,
                        boxShadow: [
                          BoxShadow(
                            color: (isClockedIn ? AppTheme.accentRed : AppTheme.accentGreen).withValues(alpha: 0.4),
                            blurRadius: 18, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Icon(isClockedIn ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Live Application Breakdown Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TODAY'S LAPTOP APP BREAKDOWN",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
                Text("${totalWorkHours.toStringAsFixed(1)}h Total",
                    style: const TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),

        if (appBreakdown.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppTheme.secondaryBg, borderRadius: BorderRadius.circular(14)),
                child: const Center(
                  child: Text("No laptop activity recorded yet today.\nDaemon runs automatically in background.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 13, height: 1.4)),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(color: AppTheme.secondaryBg, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: List.generate(appBreakdown.length, (i) {
                    final item = appBreakdown[i];
                    final appName = (item['app'] ?? 'Unknown').toString();
                    final hours = (item['hours'] ?? 0.0).toDouble();
                    final category = (item['category'] ?? 'work').toString();
                    final icon = _getAppIcon(appName);
                    final color = _getAppColor(appName);
                    final maxH = totalWorkHours > 0 ? totalWorkHours : 1.0;
                    final ratio = (hours / maxH).clamp(0.0, 1.0);

                    return GestureDetector(
                      onTap: () => _showAppDetailsModal(context, appName),
                      child: Container(
                        color: Colors.transparent,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 34, height: 34,
                                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                        child: Icon(icon, color: color, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(appName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                                const SizedBox(width: 6),
                                                const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.secondaryLabel),
                                              ],
                                            ),
                                            Text(category.toUpperCase(), style: const TextStyle(color: AppTheme.secondaryLabel, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                                          ],
                                        ),
                                      ),
                                      Text("${hours.toStringAsFixed(1)}h",
                                          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      backgroundColor: AppTheme.tertiaryBg,
                                      color: color,
                                      minHeight: 5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (i < appBreakdown.length - 1)
                              const Padding(
                                padding: EdgeInsets.only(left: 62),
                                child: Divider(height: 0.5, thickness: 0.3, color: AppTheme.separator),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

        // Recent Sessions Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: const Text("MANUAL SESSIONS",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
          ),
        ),

        if (logs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppTheme.secondaryBg, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text("No manual sessions logged yet", style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 13))),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(color: AppTheme.secondaryBg, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: List.generate(logs.take(8).length, (i) {
                    final item = logs[i];
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: AppTheme.accent, size: 20),
                              const SizedBox(width: 14),
                              Expanded(child: Text(item['description'] ?? 'Session',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                              Text("${item['duration_minutes'] ?? 0}m",
                                  style: const TextStyle(color: AppTheme.secondaryLabel, fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        if (i < logs.take(8).length - 1)
                          const Padding(
                            padding: EdgeInsets.only(left: 52),
                            child: Divider(height: 0.5, thickness: 0.3, color: AppTheme.separator),
                          ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}
