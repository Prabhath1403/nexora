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
  List<dynamic> habits = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    setState(() => isLoading = true);
    final fetched = await ApiService.fetchHabits();
    if (!mounted) return;
    setState(() { habits = fetched; isLoading = false; });
  }

  void _showAddHabitSheet() {
    final titleController = TextEditingController();
    final categoryController = TextEditingController(text: "Productivity");

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
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppTheme.tertiaryLabel, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("New Habit", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _buildIOSTextField(titleController, "Habit name", "e.g., 30m Reading"),
            const SizedBox(height: 10),
            _buildIOSTextField(categoryController, "Category", "Health, Mindset, Coding"),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              borderRadius: BorderRadius.circular(12),
              onPressed: () async {
                if (titleController.text.trim().isNotEmpty) {
                  await ApiService.createHabit({
                    'title': titleController.text.trim(),
                    'category': categoryController.text.trim(),
                    'frequency': 'daily',
                    'target_count': 1,
                  });
                  if (context.mounted) Navigator.pop(context);
                  _loadHabits();
                }
              },
              child: const Text("Add Habit"),
            ),
          ],
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
        child: Text(label, style: const TextStyle(color: AppTheme.secondaryLabel, fontSize: 14)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.tertiaryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      style: const TextStyle(color: AppTheme.label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // iOS Large Title
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Habits", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                  GestureDetector(
                    onTap: _showAddHabitSheet,
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

        // Stats Row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text("${habits.length} active habits · Daily tracking",
                style: const TextStyle(color: AppTheme.secondaryLabel, fontSize: 14)),
          ),
        ),

        if (isLoading)
          const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
        else if (habits.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: AppTheme.tertiaryLabel),
                  const SizedBox(height: 12),
                  const Text("No habits yet", style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text("Tap + to create your first habit", style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 13)),
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
                  children: List.generate(habits.length, (index) {
                    final habit = habits[index];
                    return Column(
                      children: [
                        _buildHabitRow(habit),
                        if (index < habits.length - 1)
                          const Padding(
                            padding: EdgeInsets.only(left: 56),
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

  Widget _buildHabitRow(dynamic habit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon with color accent
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _categoryColor(habit['category']).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.repeat, color: _categoryColor(habit['category']), size: 18),
          ),
          const SizedBox(width: 14),

          // Title & category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(habit['category'] ?? 'General',
                        style: const TextStyle(fontSize: 12, color: AppTheme.secondaryLabel)),
                    const SizedBox(width: 8),
                    const Icon(Icons.local_fire_department, size: 12, color: AppTheme.accentOrange),
                    const Text(" 5", style: TextStyle(fontSize: 12, color: AppTheme.accentOrange)),
                  ],
                ),
              ],
            ),
          ),

          // Check button
          GestureDetector(
            onTap: () async {
              await ApiService.logHabit(habit['id'], 1);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("✓ ${habit['title']} completed"),
                    backgroundColor: AppTheme.accentGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.4), width: 1.5),
              ),
              child: const Icon(Icons.check, color: AppTheme.accentGreen, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'health': return AppTheme.accentGreen;
      case 'mindset': return AppTheme.accentPurple;
      case 'coding': return AppTheme.accent;
      default: return AppTheme.accentTeal;
    }
  }
}
