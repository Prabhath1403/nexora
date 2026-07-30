import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<dynamic> tasks = [];
  bool isLoading = true;
  int _segmentIndex = 0;

  // Mock tasks fallback for offline UI mode
  final List<Map<String, dynamic>> _mockTasks = [
    {"id": "1", "title": "Implement GitHub Heatmap Grid", "status": "done", "priority": "high"},
    {"id": "2", "title": "Refactor FastAPI Postgres migrations", "status": "in_progress", "priority": "high"},
    {"id": "3", "title": "Add Laptop Window Telemetry Daemon", "status": "todo", "priority": "medium"},
    {"id": "4", "title": "Setup Automated Learning Scraper", "status": "todo", "priority": "medium"},
    {"id": "5", "title": "Configure Google Calendar OAuth2", "status": "todo", "priority": "low"},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final t = await ApiService.fetchTasks();
    if (!mounted) return;
    setState(() {
      tasks = t.isNotEmpty ? t : _mockTasks;
      isLoading = false;
    });
  }

  void _showAddTaskSheet() {
    final titleController = TextEditingController();
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          top: 20, left: 20, right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.secondaryBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppTheme.tertiaryLabel, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text("New Task", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: titleController,
              placeholder: "What needs to be done?",
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)),
              style: const TextStyle(color: AppTheme.label),
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(12),
              onPressed: () async {
                if (titleController.text.trim().isNotEmpty) {
                  final newT = {'title': titleController.text.trim(), 'priority': 'high', 'status': 'todo'};
                  await ApiService.createTask(newT);
                  if (context.mounted) Navigator.pop(context);
                  setState(() => tasks.add(newT));
                }
              },
              child: const Text("Add Task"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todoTasks = tasks.where((t) => (t['status'] ?? 'todo') == 'todo').toList();
    final progressTasks = tasks.where((t) => t['status'] == 'in_progress').toList();
    final doneTasks = tasks.where((t) => t['status'] == 'done').toList();
    final displayTasks = [todoTasks, progressTasks, doneTasks][_segmentIndex.clamp(0, 2)];

    return CustomScrollView(
      slivers: [
        // Large Title + Add Button
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Tasks", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                  GestureDetector(
                    onTap: _showAddTaskSheet,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.add, color: AppTheme.accent, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Custom Apple iOS Segmented Control
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.secondaryBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildSegmentItem(0, "To Do (${todoTasks.length})")),
                  Expanded(child: _buildSegmentItem(1, "In Progress (${progressTasks.length})")),
                  Expanded(child: _buildSegmentItem(2, "Done (${doneTasks.length})")),
                ],
              ),
            ),
          ),
        ),

        if (isLoading)
          const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
        else if (displayTasks.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: AppTheme.tertiaryLabel),
                  const SizedBox(height: 12),
                  Text(_emptyMessage(), style: const TextStyle(color: AppTheme.secondaryLabel, fontSize: 16)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: List.generate(displayTasks.length, (index) {
                    final item = displayTasks[index];
                    return Column(
                      children: [
                        _buildTaskRow(item),
                        if (index < displayTasks.length - 1)
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

  String _emptyMessage() {
    switch (_segmentIndex) {
      case 0: return "Nothing to do — add a task";
      case 1: return "No tasks in progress";
      case 2: return "No completed tasks yet";
      default: return "No tasks";
    }
  }

  Widget _buildTaskRow(dynamic item) {
    final priority = item['priority'] ?? 'medium';
    final priorityColor = priority == 'high' ? AppTheme.accentRed
        : priority == 'medium' ? AppTheme.accentOrange
        : AppTheme.accentGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 4, height: 36,
            decoration: BoxDecoration(color: priorityColor, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(priority, style: TextStyle(fontSize: 10, color: priorityColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.tertiaryLabel, size: 18),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(int index, String label) {
    final bool isSelected = _segmentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _segmentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.tertiaryBg : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppTheme.label : AppTheme.secondaryLabel,
          ),
        ),
      ),
    );
  }
}
