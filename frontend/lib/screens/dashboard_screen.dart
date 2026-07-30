import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  int habitCount = 4;
  int taskCount = 7;
  bool isLoading = false;

  // Mock data for Habit Line Chart (Daily % completion over past 7 days)
  final List<double> habitWeeklyTrend = [0.60, 0.80, 0.75, 1.00, 0.85, 0.90, 0.95];
  final List<String> weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  // GitHub Contribution Matrix
  List<List<int>> githubContributionGrid = [];
  int githubTotalContributions = 52;
  String githubUsername = "Prabhath1403";
  int githubCommitsToday = 3;

  // Tracked Hours & Projects
  double workHoursToday = 0.0;
  double learningHoursToday = 0.0;

  // Daemon Tracking State
  String? topApp;
  double topAppHours = 0.0;
  bool isDaemonActive = false;
  int currentSessionMinutes = 0;
  String? activeSince;
  List<dynamic> appBreakdown = [];

  // Unfinished Projects List
  List<Map<String, dynamic>> unfinishedProjects = [
    {
      "name": "Nucleus Hub Engine",
      "repo": "Prabhath1403/nucleus",
      "progress": 0.75,
      "completedTasks": 9,
      "totalTasks": 12,
      "color": AppTheme.accent,
      "priority": "High",
      "trackedHours": "14.2h"
    },
    {
      "name": "Facial AI Pipeline",
      "repo": "Prabhath1403/facial-ai",
      "progress": 0.40,
      "completedTasks": 4,
      "totalTasks": 10,
      "color": AppTheme.accentPurple,
      "priority": "Medium",
      "trackedHours": "8.5h"
    },
    {
      "name": "Fraud Controller",
      "repo": "Prabhath1403/Fruad-controller",
      "progress": 0.55,
      "completedTasks": 5,
      "totalTasks": 9,
      "color": AppTheme.accentTeal,
      "priority": "Medium",
      "trackedHours": "6.1h"
    },
  ];

  // Mock & Live GitHub Commit Activity Stream
  List<Map<String, String>> githubCommits = [
    {
      "repo": "Prabhath1403/nucleus",
      "message": "feat: add GitHub contribution heatmap grid",
      "time": "5m ago",
      "branch": "main"
    },
    {
      "repo": "Prabhath1403/nucleus",
      "message": "feat: add habit line chart & auto hours tracking",
      "time": "1h ago",
      "branch": "main"
    },
    {
      "repo": "Prabhath1403/cyphercite",
      "message": "refactor: optimize database query execution",
      "time": "4h ago",
      "branch": "dev"
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _generateGitHubMockMatrix();
    _loadStats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStats();
    }
  }

  void _generateGitHubMockMatrix() {
    final List<List<int>> matrix = [];
    final List<int> pattern = [0, 1, 2, 0, 3, 4, 2, 1, 0, 4, 3, 2, 1, 4, 2, 3, 4, 1];
    for (int w = 0; w < 18; w++) {
      final List<int> week = [];
      for (int d = 0; d < 7; d++) {
        final level = (pattern[(w + d) % pattern.length] + ((w * d) % 3)) % 5;
        week.add(level);
      }
      matrix.add(week);
    }
    githubContributionGrid = matrix;
  }

  Future<void> _loadStats() async {
    final habits = await ApiService.fetchHabits();
    final tasks = await ApiService.fetchTasks();
    final projects = await ApiService.fetchProjects();
    final ghActivity = await ApiService.fetchGitHubActivity();
    final trackerSummary = await ApiService.fetchTrackerSummary();
    final daemonStatus = await ApiService.fetchDaemonStatus();
    final breakdownData = await ApiService.fetchAppBreakdown();

    if (!mounted) return;
    setState(() {
      if (habits.isNotEmpty) habitCount = habits.length;
      if (tasks.isNotEmpty) taskCount = tasks.length;
      
      // Load live GitHub activity & GraphQL contribution grid
      if (ghActivity != null) {
        if (ghActivity['username'] != null) {
          githubUsername = ghActivity['username'];
        }
        if (ghActivity['total_contributions'] != null) {
          githubTotalContributions = ghActivity['total_contributions'];
        }
        if (ghActivity['contribution_grid'] != null && (ghActivity['contribution_grid'] as List).isNotEmpty) {
          final List<dynamic> gridData = ghActivity['contribution_grid'];
          githubContributionGrid = gridData.map((week) => (week as List).map((day) => (day as int)).toList()).toList();
        }
        if (ghActivity['recent_commits'] != null && (ghActivity['recent_commits'] as List).isNotEmpty) {
          githubCommits = (ghActivity['recent_commits'] as List).map((c) => {
            "repo": (c['repo'] ?? '') as String,
            "message": (c['message'] ?? '') as String,
            "time": (c['sha'] ?? 'commit') as String,
            "branch": (c['branch'] ?? 'main') as String,
          }).toList();
        }
        if (ghActivity['active_repos'] != null && (ghActivity['active_repos'] as List).isNotEmpty) {
          unfinishedProjects = (ghActivity['active_repos'] as List).take(4).map((r) => {
            "name": (r['name'] ?? '').toString().split('/').last,
            "repo": r['name'] ?? '',
            "progress": 0.60,
            "completedTasks": 6,
            "totalTasks": 10,
            "color": AppTheme.accent,
            "priority": (r['language'] ?? 'Active').toString(),
            "trackedHours": "Active",
          }).toList();
        }
        githubCommitsToday = ghActivity['total_commits_today'] ?? githubCommits.length;
      }

      // Load live tracker work & learning hours
      if (trackerSummary != null) {
        workHoursToday = (trackerSummary['work_hours_today'] ?? 0.0).toDouble();
        learningHoursToday = (trackerSummary['learning_hours_today'] ?? 0.0).toDouble();
        topApp = trackerSummary['top_app'];
        topAppHours = (trackerSummary['top_app_hours'] ?? 0.0).toDouble();
        currentSessionMinutes = (trackerSummary['current_session_minutes'] ?? 0).toInt();
        activeSince = trackerSummary['active_since'];
      }

      // Check daemon status
      if (daemonStatus != null) {
        isDaemonActive = daemonStatus['active'] == true;
      }

      // Load app breakdown
      if (breakdownData != null && breakdownData['breakdown'] != null) {
        appBreakdown = breakdownData['breakdown'];
      }

      // Load DB Projects if created
      if (projects.isNotEmpty) {
        unfinishedProjects = projects.map((p) => {
          "name": p['title'] ?? 'Untitled Project',
          "repo": p['description'] ?? 'Local Project',
          "progress": 0.50,
          "completedTasks": 3,
          "totalTasks": 6,
          "color": AppTheme.accentPurple,
          "priority": p['status'] ?? 'Active',
          "trackedHours": "${p['target_hours'] ?? 10}h goal",
        }).toList();
      }
      
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // iOS Large Title Header
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_getGreeting(),
                      style: const TextStyle(color: AppTheme.secondaryLabel, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  const Text("Summary", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                ],
              ),
            ),
          ),
        ),

        // Habit Streak Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.accentOrange.withValues(alpha: 0.25), AppTheme.accentRed.withValues(alpha: 0.15)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.3), width: 0.8),
              ),
              child: const Row(
                children: [
                  Text("🔥", style: TextStyle(fontSize: 28)),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("5 Day Habit Streak", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text("Keep your momentum going!", style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Automated Work & Learning Hours Cards
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("AUTOMATED TRACKING",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sensors, color: AppTheme.accentGreen, size: 12),
                          SizedBox(width: 4),
                          Text("LIVE LAPTOP", style: TextStyle(fontSize: 10, color: AppTheme.accentGreen, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildAutoHoursCard(
                        title: "Work Hours",
                        value: "${workHoursToday.toStringAsFixed(1)}h",
                        subtitle: topApp != null ? "$topApp · ${topAppHours.toStringAsFixed(1)}h" : "Start the daemon",
                        color: AppTheme.accent,
                        icon: Icons.laptop_mac_rounded,
                        progress: workHoursToday > 0 ? (workHoursToday / 8.0).clamp(0.0, 1.0) : 0.0,
                        isActive: isDaemonActive,
                        onTap: () => _showWorkHoursModal(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAutoHoursCard(
                        title: "Learning Hours",
                        value: "${learningHoursToday.toStringAsFixed(1)}h",
                        subtitle: currentSessionMinutes > 0 ? "Session: ${currentSessionMinutes}m" : "Browse docs & tutorials",
                        color: AppTheme.accentPurple,
                        icon: Icons.menu_book_rounded,
                        progress: learningHoursToday > 0 ? (learningHoursToday / 4.0).clamp(0.0, 1.0) : 0.0,
                        isActive: isDaemonActive,
                        onTap: () => widget.onNavigate(3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // GitHub Contribution Heatmap Grid Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("GITHUB CONTRIBUTIONS",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
                    const Spacer(),
                    const Text("482 in 2026", style: TextStyle(fontSize: 12, color: AppTheme.accentGreen, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.code_rounded, color: AppTheme.accentGreen, size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Prabhath1403", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              Text("12 Day Commit Streak 🔥", style: TextStyle(fontSize: 11, color: AppTheme.secondaryLabel)),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text("Top 5%", style: TextStyle(fontSize: 11, color: AppTheme.accentGreen, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Horizontal Scrollable GitHub Contribution Matrix
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(githubContributionGrid.length, (weekIdx) {
                                final week = githubContributionGrid[weekIdx];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Column(
                                    children: List.generate(7, (dayIdx) {
                                      final level = week[dayIdx];
                                      return Container(
                                        width: 12,
                                        height: 12,
                                        margin: const EdgeInsets.only(bottom: 3),
                                        decoration: BoxDecoration(
                                          color: _getGitHubHeatmapColor(level),
                                          borderRadius: BorderRadius.circular(2.5),
                                        ),
                                      );
                                    }),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Legend
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text("Less ", style: TextStyle(fontSize: 10, color: AppTheme.secondaryLabel)),
                          ...List.generate(5, (lvl) => Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: _getGitHubHeatmapColor(lvl),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          )),
                          const Text(" More", style: TextStyle(fontSize: 10, color: AppTheme.secondaryLabel)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Habit Consistency Line Chart
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("HABIT CONSISTENCY",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => widget.onNavigate(1),
                      child: const Text("View All", style: TextStyle(fontSize: 13, color: AppTheme.accent, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Weekly Completion Rate", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          Text("95% Today", style: TextStyle(fontSize: 13, color: AppTheme.accentGreen, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _HabitLineChartPainter(
                            data: habitWeeklyTrend,
                            lineColor: AppTheme.accentGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: weekDays
                            .map((day) => Text(day, style: const TextStyle(fontSize: 11, color: AppTheme.secondaryLabel)))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Unfinished Projects Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("UNFINISHED PROJECTS",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => widget.onNavigate(2),
                      child: const Text("Manage Tasks", style: TextStyle(fontSize: 13, color: AppTheme.accent, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildIOSGroupedSection(
                  unfinishedProjects.map((p) => _buildProjectRow(p)).toList(),
                ),
              ],
            ),
          ),
        ),

        // Recent Commits Feed
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("RECENT COMMITS",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
                    const Spacer(),
                    const Text("3 Commits Today", style: TextStyle(fontSize: 12, color: AppTheme.secondaryLabel)),
                  ],
                ),
                const SizedBox(height: 10),
                _buildIOSGroupedSection(
                  githubCommits.map((c) => _buildCommitRow(c)).toList(),
                ),
              ],
            ),
          ),
        ),

        // Connections & Telemetry Status
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("ACTIVE TELEMETRY",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                _buildIOSGroupedSection([
                  _buildConnectionRow("Laptop Activity Daemon", "Active (xdotool)", AppTheme.accentGreen),
                  _buildConnectionRow("Antigravity Assistant Logs", "Auto-Mining", AppTheme.accentGreen),
                  _buildConnectionRow("GitHub Webhook & API", "Connected", AppTheme.accentGreen),
                  _buildConnectionRow("Google Calendar Sync", "Synced", AppTheme.accentGreen),
                ]),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Color _getGitHubHeatmapColor(int level) {
    switch (level) {
      case 0: return AppTheme.tertiaryBg;
      case 1: return const Color(0xFF0E4429);
      case 2: return const Color(0xFF006D32);
      case 3: return const Color(0xFF26A641);
      case 4: return const Color(0xFF39D353);
      default: return AppTheme.tertiaryBg;
    }
  }

  void _showWorkHoursModal(BuildContext context) {
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
              // Handle Bar
              Center(
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),

              // Modal Header
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.laptop_mac_rounded, color: AppTheme.accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Today's Work Telemetry", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          isDaemonActive ? "🟢 Laptop Tracker Active" : "🟧 Laptop Daemon Offline",
                          style: TextStyle(fontSize: 12, color: isDaemonActive ? AppTheme.accentGreen : AppTheme.accentOrange, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Text("${workHoursToday.toStringAsFixed(1)}h",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                ],
              ),
              const SizedBox(height: 24),

              // CURRENT SESSION SUMMARY CARD
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
                    const Text("CURRENT FOCUS & SESSION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: AppTheme.accentPurple, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          topApp != null ? "Top Focus: $topApp (${topAppHours.toStringAsFixed(1)}h)" : "No activity logged yet",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (currentSessionMinutes > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 28),
                        child: Text("Active Session: ${currentSessionMinutes} minutes continuous work",
                            style: const TextStyle(fontSize: 12, color: AppTheme.secondaryLabel)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // TODAY'S APP BREAKDOWN LIST
              const Text("APPLICATION TIME BREAKDOWN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
              const SizedBox(height: 10),

              if (appBreakdown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text("No app usage logged yet today.\nDaemon automatically tracks active IDEs & apps.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 13)),
                )
              else
                Container(
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: List.generate(appBreakdown.length, (i) {
                      final item = appBreakdown[i];
                      final name = (item['app'] ?? 'App').toString();
                      final hours = (item['hours'] ?? 0.0).toDouble();
                      final category = (item['category'] ?? 'work').toString();
                      final maxH = workHoursToday > 0 ? workHoursToday : 1.0;
                      final ratio = (hours / maxH).clamp(0.0, 1.0);

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.apps_rounded, color: AppTheme.accent, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: ratio,
                                          backgroundColor: AppTheme.tertiaryBg,
                                          color: AppTheme.accent,
                                          minHeight: 4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text("${hours.toStringAsFixed(1)}h",
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                              ],
                            ),
                          ),
                          if (i < appBreakdown.length - 1)
                            const Padding(
                              padding: EdgeInsets.only(left: 44),
                              child: Divider(height: 0.5, thickness: 0.3, color: AppTheme.separator),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      color: AppTheme.tertiaryBg,
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close", style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.label)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onNavigate(2); // Go to Work Hours full tab
                      },
                      child: const Text("Full Timelogs", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning, Prabhath 👋";
    if (hour < 17) return "Good Afternoon, Prabhath 👋";
    return "Good Evening, Prabhath 👋";
  }

  Widget _buildAutoHoursCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required double progress,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    final dotColor = isActive ? AppTheme.accentGreen : AppTheme.accentOrange;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.secondaryBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: dotColor.withValues(alpha: 0.6), blurRadius: 6)]),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(subtitle, style: const TextStyle(color: AppTheme.secondaryLabel, fontSize: 11)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.tertiaryBg,
                color: color,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSGroupedSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.secondaryBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              children[i],
              if (i < children.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: 52),
                  child: Divider(height: 0.5, thickness: 0.3, color: AppTheme.separator),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildProjectRow(Map<String, dynamic> project) {
    final Color pColor = project['color'] as Color;
    final double progress = project['progress'] as double;
    final int completed = project['completedTasks'] as int;
    final int total = project['totalTasks'] as int;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: pColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  project['name'] as String,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                "${(progress * 100).toInt()}%",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: pColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Row(
              children: [
                Text(
                  "$completed/$total tasks · ${project['trackedHours']} logged",
                  style: const TextStyle(fontSize: 12, color: AppTheme.secondaryLabel),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: pColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    project['priority'] as String,
                    style: TextStyle(fontSize: 10, color: pColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.tertiaryBg,
                color: pColor,
                minHeight: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitRow(Map<String, String> commit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.commit_rounded, color: AppTheme.accentTeal, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(commit['message']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text("${commit['repo']} (${commit['branch']})", style: const TextStyle(fontSize: 11, color: AppTheme.secondaryLabel)),
              ],
            ),
          ),
          Text(commit['time']!, style: const TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel)),
        ],
      ),
    );
  }

  Widget _buildConnectionRow(String service, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(service, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
          Text(status, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// Custom Smooth Habit Line Chart Painter
class _HabitLineChartPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;

  _HabitLineChartPainter({required this.data, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double width = size.width;
    final double height = size.height;
    final double stepX = width / (data.length - 1);

    final List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      final double y = height - (data[i] * height);
      points.add(Offset(x, y));
    }

    // Grid lines background
    final Paint gridPaint = Paint()
      ..color = AppTheme.separator.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    for (int i = 1; i <= 3; i++) {
      final double y = height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // Gradient fill under curve
    final Path fillPath = Path()..moveTo(points.first.dx, height);
    for (var point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(points.last.dx, height);
    fillPath.close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [lineColor.withValues(alpha: 0.35), lineColor.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawPath(fillPath, fillPaint);

    // Smooth bezier curve
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
    }

    final Paint strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Draw glowing data dots
    final Paint dotBgPaint = Paint()..color = AppTheme.secondaryBg;
    final Paint dotBorderPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (var p in points) {
      canvas.drawCircle(p, 5, dotBgPaint);
      canvas.drawCircle(p, 5, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HabitLineChartPainter old) => old.data != data || old.lineColor != lineColor;
}
