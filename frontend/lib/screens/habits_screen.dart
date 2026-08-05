import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  List<dynamic> headers = [];
  List<dynamic> habits = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGrid();
  }

  Future<void> _loadGrid() async {
    setState(() => isLoading = true);
    final data = await ApiService.fetchWeeklyHabitGrid();
    if (!mounted) return;
    if (data != null) {
      setState(() {
        headers = (data['headers'] as List?) ?? [];
        habits = (data['habits'] as List?) ?? [];
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void _showAddHabitSheet() {
    final titleController = TextEditingController();
    final categoryController = TextEditingController(text: "Productivity");
    final targetValueController = TextEditingController(text: "3.0");
    String targetType = "work_hours"; // manual, work_hours, learning_hours

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        color: Colors.transparent,
        child: StatefulBuilder(
          builder: (context, setModalState) => Container(
            padding: EdgeInsets.only(
              top: 20, left: 20, right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.secondaryBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppTheme.tertiaryLabel, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text("New Habit & Goal", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _buildIOSTextField(titleController, "Habit Name", "e.g., Work 3 Hours"),
              const SizedBox(height: 10),
              _buildIOSTextField(categoryController, "Category", "Productivity, Health, Learning"),
              const SizedBox(height: 14),

              const Text("AUTO-CHECK CRITERIA", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
              const SizedBox(height: 8),

              // Segmented Target Type Selector
              Container(
                decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildSegmentOption("Auto Work", "work_hours", targetType, (val) => setModalState(() => targetType = val)),
                    _buildSegmentOption("Auto Learn", "learning_hours", targetType, (val) => setModalState(() => targetType = val)),
                    _buildSegmentOption("Manual", "manual", targetType, (val) => setModalState(() => targetType = val)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (targetType != "manual") ...[
                _buildIOSTextField(targetValueController, "Target Hours", "e.g. 3.0"),
                const SizedBox(height: 6),
                Text(
                  targetType == "work_hours"
                      ? "⚡ Daemon will auto-check off this habit when tracked laptop work >= target hours."
                      : "⚡ Daemon will auto-check off this habit when tracked laptop learning >= target hours.",
                  style: const TextStyle(fontSize: 11, color: AppTheme.accentGreen, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 14),
              ],

              CupertinoButton.filled(
                borderRadius: BorderRadius.circular(12),
                onPressed: () async {
                  if (titleController.text.trim().isNotEmpty) {
                    final targetVal = double.tryParse(targetValueController.text.trim()) ?? 1.0;
                    await ApiService.createHabit({
                      'title': titleController.text.trim(),
                      'category': categoryController.text.trim(),
                      'frequency': 'daily',
                      'target_type': targetType,
                      'target_value': targetVal,
                      'color_hex': targetType == 'work_hours' ? '#6366F1' : (targetType == 'learning_hours' ? '#EC4899' : '#10B981'),
                      'icon_name': targetType == 'work_hours' ? 'work' : (targetType == 'learning_hours' ? 'school' : 'check_circle'),
                    });
                    if (context.mounted) Navigator.pop(context);
                    _loadGrid();
                  }
                },
                child: const Text("Create Habit"),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSegmentOption(String label, String value, String current, Function(String) onSelect) {
    final isSelected = value == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppTheme.secondaryLabel,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIOSTextField(TextEditingController controller, String label, String placeholder) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      prefix: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(label, style: const TextStyle(color: AppTheme.secondaryLabel, fontSize: 13)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.tertiaryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      style: const TextStyle(color: AppTheme.label, fontSize: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Title Bar
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Habit Tracker", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: const Text("⚡ Auto Telemetry Sync", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accentGreen)),
                          ),
                          const SizedBox(width: 8),
                          const Text("Google Sheets Grid View", style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _showAddHabitSheet,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.add_rounded, color: AppTheme.accent, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        if (isLoading)
          const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
        else if (habits.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.grid_on_rounded, size: 48, color: AppTheme.tertiaryLabel),
                  const SizedBox(height: 12),
                  const Text("No habits created yet", style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text("Tap + to add your first daily goal", style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.tertiaryBg, width: 1),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Spreadsheet Table Header
                        _buildSpreadsheetHeaderRow(),

                        const Divider(height: 1, thickness: 1, color: AppTheme.tertiaryBg),

                        // Spreadsheet Table Rows
                        ...List.generate(habits.length, (index) {
                          final habit = habits[index];
                          return Column(
                            children: [
                              _buildSpreadsheetHabitRow(habit),
                              if (index < habits.length - 1)
                                const Divider(height: 1, thickness: 0.5, color: AppTheme.tertiaryBg),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildSpreadsheetHeaderRow() {
    return Container(
      color: AppTheme.tertiaryBg.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Left Fixed Habit Info Column
          Container(
            width: 170,
            padding: const EdgeInsets.only(left: 16),
            child: const Text(
              "HABIT / GOAL",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.secondaryLabel, letterSpacing: 0.5),
            ),
          ),

          // 7 Day Headers (Mon - Sun)
          ...List.generate(headers.length, (i) {
            final h = headers[i];
            final dayName = h['day_name'] ?? '';
            final dayNum = h['day_number'] ?? 0;
            final isToday = h['is_today'] == true;

            return Container(
              width: 48,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: isToday
                  ? BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 1),
                    )
                  : null,
              child: Column(
                children: [
                  Text(
                    dayName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isToday ? AppTheme.accent : AppTheme.secondaryLabel,
                    ),
                  ),
                  Text(
                    "$dayNum",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isToday ? AppTheme.accent : AppTheme.label,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSpreadsheetHabitRow(dynamic habit) {
    final title = (habit['title'] ?? '').toString();
    final category = (habit['category'] ?? 'General').toString();
    final targetType = (habit['target_type'] ?? 'manual').toString();
    final targetVal = (habit['target_value'] ?? 1.0).toDouble();
    final cells = (habit['weekly_cells'] as List?) ?? [];
    final color = _habitColor(targetType, habit['color_hex']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Left Habit Title & Metadata Column
          Container(
            width: 170,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_habitIcon(targetType), size: 14, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(category, style: const TextStyle(fontSize: 10, color: AppTheme.secondaryLabel)),
                    const SizedBox(width: 6),
                    if (targetType != 'manual')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text("⚡ Auto ${targetVal.toStringAsFixed(0)}h", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.accentGreen)),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 7 Day Grid Cells (Mon - Sun)
          ...List.generate(cells.length, (i) {
            final cell = cells[i];
            final dateStr = (cell['date'] ?? '').toString();
            final completed = cell['completed'] == true;
            final autoChecked = cell['auto_checked'] == true;
            final isToday = cell['is_today'] == true;
            final isFuture = cell['is_future'] == true;
            final progress = (cell['progress'] ?? 0.0).toDouble();

            return GestureDetector(
              onTap: () async {
                if (isFuture) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Future dates cannot be checked off yet!"),
                      backgroundColor: AppTheme.secondaryBg,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  return;
                }
                await ApiService.toggleHabitDate(habit['id'], dateStr);
                _loadGrid();
              },
              child: Opacity(
                opacity: isFuture ? 0.4 : 1.0,
                child: Container(
                  width: 48, height: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: completed
                        ? (autoChecked ? AppTheme.accentGreen.withValues(alpha: 0.2) : color.withValues(alpha: 0.18))
                        : (isToday ? AppTheme.tertiaryBg : AppTheme.background.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: completed
                          ? (autoChecked ? AppTheme.accentGreen : color.withValues(alpha: 0.6))
                          : (isToday ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.tertiaryBg),
                      width: isToday ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: completed
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: autoChecked ? AppTheme.accentGreen : color,
                                size: 18,
                              ),
                              if (autoChecked)
                                const Text("AUTO", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppTheme.accentGreen)),
                            ],
                          )
                        : (progress > 0
                            ? Text(
                                "${progress.toStringAsFixed(1)}h",
                                style: const TextStyle(fontSize: 10, color: AppTheme.secondaryLabel, fontWeight: FontWeight.w600),
                              )
                            : const SizedBox.shrink()),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  IconData _habitIcon(String targetType) {
    if (targetType == 'work_hours') return Icons.laptop_mac_rounded;
    if (targetType == 'learning_hours') return Icons.school_rounded;
    return Icons.check_circle_outline_rounded;
  }

  Color _habitColor(String targetType, String? hex) {
    if (targetType == 'work_hours') return AppTheme.accentPurple;
    if (targetType == 'learning_hours') return AppTheme.accentPink;
    return AppTheme.accentGreen;
  }
}
