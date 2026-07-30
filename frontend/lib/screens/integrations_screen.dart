import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> with WidgetsBindingObserver {
  bool isLoading = true;
  bool isGitHubConnected = false;
  String? githubUsername;
  
  bool isGoogleConnected = false;
  String? googleEmail;

  bool isDaemonConnected = false;
  String? daemonLastSeen;
  String? daemonLastApp;
  String? daemonLastProject;
  String? daemonLastCategory;
  double daemonWorkHours = 0.0;
  double daemonLearningHours = 0.0;

  // Detailed telemetry for modal popup
  Map<String, dynamic>? recentPingDetail;
  List<dynamic> appBreakdown = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchStatus();
    }
  }

  Future<void> _fetchStatus() async {
    setState(() => isLoading = true);
    final status = await ApiService.fetchIntegrationStatus();
    final daemon = await ApiService.fetchDaemonStatus();
    final trackerSummary = await ApiService.fetchTrackerSummary();
    final breakdownData = await ApiService.fetchAppBreakdown();
    
    if (!mounted) return;
    setState(() {
      if (status != null) {
        final gh = status['github'] ?? {};
        isGitHubConnected = gh['connected'] == true;
        githubUsername = gh['username'];

        final goog = status['google'] ?? {};
        isGoogleConnected = goog['connected'] == true;
        googleEmail = goog['email'];
      }
      if (daemon != null) {
        isDaemonConnected = daemon['active'] == true;
        daemonLastSeen = daemon['last_seen'];
        daemonLastApp = daemon['last_app'];
        daemonLastProject = daemon['last_project'];
        daemonLastCategory = daemon['last_category'];
      }
      if (trackerSummary != null) {
        daemonWorkHours = (trackerSummary['work_hours_today'] ?? 0.0).toDouble();
        daemonLearningHours = (trackerSummary['learning_hours_today'] ?? 0.0).toDouble();
        if (trackerSummary['recent_activity'] != null && (trackerSummary['recent_activity'] as List).isNotEmpty) {
          recentPingDetail = trackerSummary['recent_activity'][0];
        }
      }
      if (breakdownData != null && breakdownData['breakdown'] != null) {
        appBreakdown = breakdownData['breakdown'];
      }
      isLoading = false;
    });
  }

  Future<void> _connectGitHub() async {
    final urlStr = await ApiService.getGitHubAuthUrl();
    if (urlStr != null) {
      final Uri url = Uri.parse(urlStr);
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        print("Error launching GitHub URL: $e");
      }
    }
  }

  Future<void> _connectGoogle() async {
    final urlStr = await ApiService.getGoogleAuthUrl();
    if (urlStr != null) {
      final Uri url = Uri.parse(urlStr);
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        print("Error launching Google URL: $e");
      }
    }
  }

  Future<void> _disconnectService(String service) async {
    if (service == 'github') {
      await ApiService.disconnectGitHub();
    } else if (service == 'google') {
      await ApiService.disconnectGoogle();
    }
    _fetchStatus();
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
                        decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.apps_rounded, color: AppTheme.accent, size: 24),
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
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.accent)),
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
                                    appName.toLowerCase().contains('brave') || appName.toLowerCase().contains('chrome')
                                        ? Icons.public_rounded
                                        : Icons.folder_open_rounded,
                                    color: AppTheme.accent, size: 20,
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

  void _showLaptopTelemetryModal(BuildContext context) {
    final activeApp = daemonLastApp ?? (recentPingDetail?['app_name'] ?? 'Unknown');
    final activeTitle = recentPingDetail?['window_title'] ?? 'No active window details';
    final project = daemonLastProject ?? recentPingDetail?['project_hint'] ?? '';
    final category = daemonLastCategory ?? recentPingDetail?['category'] ?? 'work';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),

              // Title Header
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: (isDaemonConnected ? AppTheme.accentGreen : AppTheme.accentOrange).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.laptop_mac_rounded, color: isDaemonConnected ? AppTheme.accentGreen : AppTheme.accentOrange, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Laptop Live Telemetry", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                color: isDaemonConnected ? AppTheme.accentGreen : AppTheme.accentOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isDaemonConnected ? "Active · Pinging every 30s" : "Offline · Start nucleus-daemon",
                              style: TextStyle(fontSize: 12, color: isDaemonConnected ? AppTheme.accentGreen : AppTheme.accentOrange, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // CURRENTLY ACTIVE SECTION CARD
              const Text("CURRENTLY ACTIVE ON LAPTOP", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.separator, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (category == 'work' ? AppTheme.accent : (category == 'learning' ? AppTheme.accentPurple : AppTheme.accentOrange)).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(category.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: category == 'work' ? AppTheme.accent : (category == 'learning' ? AppTheme.accentPurple : AppTheme.accentOrange))),
                        ),
                        const Spacer(),
                        Text(activeApp, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Website or Project Context Details
                    if (activeApp.toLowerCase().contains('brave') || activeApp.toLowerCase().contains('chrome') || activeApp.toLowerCase().contains('firefox')) ...[
                      const Text("Active Website / Web Page:", style: TextStyle(fontSize: 11, color: AppTheme.secondaryLabel, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        activeTitle.isNotEmpty ? activeTitle : "Browser Active",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else if (activeApp.toLowerCase().contains('antigravity') || activeApp.toLowerCase().contains('code') || activeApp.toLowerCase().contains('cursor')) ...[
                      const Text("Active Project & Workspace:", style: TextStyle(fontSize: 11, color: AppTheme.secondaryLabel, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        project.isNotEmpty ? "Project: $project" : activeTitle,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.accentPurple),
                      ),
                    ] else ...[
                      const Text("Active Window Title:", style: TextStyle(fontSize: 11, color: AppTheme.secondaryLabel, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        activeTitle.isNotEmpty ? activeTitle : "$activeApp Session",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // TODAY'S APP BREAKDOWN LIST
              const Text("TODAY'S USAGE BREAKDOWN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              if (appBreakdown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text("No app usage logged yet today", style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 13)),
                )
              else
                Container(
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: List.generate(appBreakdown.take(5).length, (i) {
                      final item = appBreakdown[i];
                      final name = (item['app'] ?? 'App').toString();
                      final hours = (item['hours'] ?? 0.0).toDouble();
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          dense: true,
                          onTap: () {
                            Navigator.pop(context);
                            _showAppDetailsModal(context, name);
                          },
                          title: Row(
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded, size: 14, color: AppTheme.secondaryLabel),
                            ],
                          ),
                          subtitle: Text(item['category'] ?? 'Work', style: const TextStyle(fontSize: 11, color: AppTheme.secondaryLabel)),
                          trailing: Text("${hours.toStringAsFixed(1)}h", style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.accent, fontSize: 14)),
                        ),
                      );
                    }),
                  ),
                ),
              const SizedBox(height: 20),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: AppTheme.tertiaryBg,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Done", style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.label)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Apple Large Title Header
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
                      Text("SYSTEM TELEMETRY", style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      SizedBox(height: 2),
                      Text("Integrations", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppTheme.accent),
                    onPressed: _fetchStatus,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Live Laptop Telemetry Card (Clickable to open popup sheet)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("AUTOMATED DAEMON", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _showLaptopTelemetryModal(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: (isDaemonConnected ? AppTheme.accentGreen : AppTheme.accentOrange).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.laptop_mac_rounded, color: isDaemonConnected ? AppTheme.accentGreen : AppTheme.accentOrange, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text("Laptop Activity Daemon", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.secondaryLabel),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isDaemonConnected
                                  ? "Active · ${daemonLastApp ?? 'Tracking'}${daemonLastProject != null && daemonLastProject!.isNotEmpty ? ' · $daemonLastProject' : ''}"
                                  : "Offline · Run install_daemon.sh",
                                style: TextStyle(fontSize: 12, color: isDaemonConnected ? AppTheme.accentGreen : AppTheme.secondaryLabel),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isDaemonConnected && (daemonWorkHours > 0 || daemonLearningHours > 0))
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    "Today: ${daemonWorkHours.toStringAsFixed(1)}h Work, ${daemonLearningHours.toStringAsFixed(1)}h Learning",
                                    style: const TextStyle(fontSize: 11, color: AppTheme.secondaryLabel),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: isDaemonConnected ? AppTheme.accentGreen : AppTheme.accentOrange,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isDaemonConnected ? AppTheme.accentGreen : AppTheme.accentOrange).withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Connected Services Grouped Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("CLOUD SERVICES", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                _buildIOSGroupedSection([
                  // GitHub Row
                  _buildServiceRow(
                    title: "GitHub",
                    subtitle: isGitHubConnected ? "Signed in as @${githubUsername ?? ''}" : "Sync commits, repos & heatmap",
                    icon: Icons.code_rounded,
                    color: AppTheme.accentTeal,
                    isConnected: isGitHubConnected,
                    onTap: isGitHubConnected ? () => _disconnectService('github') : _connectGitHub,
                  ),
                  // Google Calendar Row
                  _buildServiceRow(
                    title: "Google Calendar",
                    subtitle: isGoogleConnected ? "Connected as ${googleEmail ?? ''}" : "Sync events & focus blocks",
                    icon: Icons.calendar_month_rounded,
                    color: AppTheme.accentOrange,
                    isConnected: isGoogleConnected,
                    onTap: isGoogleConnected ? () => _disconnectService('google') : _connectGoogle,
                  ),
                  // Gmail Row
                  _buildServiceRow(
                    title: "Gmail",
                    subtitle: isGoogleConnected ? "Connected via Google OAuth" : "Inbox triage & auto-tasks",
                    icon: Icons.mail_outline_rounded,
                    color: AppTheme.accentRed,
                    isConnected: isGoogleConnected,
                    onTap: isGoogleConnected ? () => _disconnectService('google') : _connectGoogle,
                  ),
                ]),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildIOSGroupedSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.secondaryBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              children[i],
              if (i < children.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: 56),
                  child: Divider(height: 0.5, thickness: 0.3, color: AppTheme.separator),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildServiceRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isConnected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppTheme.secondaryLabel, fontSize: 12)),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: isConnected ? AppTheme.tertiaryBg : AppTheme.accent,
            borderRadius: BorderRadius.circular(20),
            onPressed: onTap,
            child: Text(
              isConnected ? "Connected" : "Connect",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isConnected ? AppTheme.accentGreen : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
