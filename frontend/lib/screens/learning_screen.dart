import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  List<dynamic> resources = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    setState(() => isLoading = true);
    final res = await ApiService.fetchLearningResources();
    if (!mounted) return;
    setState(() {
      resources = res;
      isLoading = false;
    });
  }

  void _showAddSheet() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    final notesController = TextEditingController();
    String resourceType = "course";

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
                  child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.tertiaryLabel, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                const Text("Add Learning Resource", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.label)),
                const SizedBox(height: 16),

                CupertinoTextField(
                  controller: titleController,
                  placeholder: "Title / Course Name",
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)),
                  style: const TextStyle(color: AppTheme.label),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: urlController,
                  placeholder: "URL (optional)",
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)),
                  style: const TextStyle(color: AppTheme.label),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: notesController,
                  placeholder: "Notes",
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)),
                  style: const TextStyle(color: AppTheme.label),
                ),
                const SizedBox(height: 20),

                CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () async {
                    if (titleController.text.trim().isNotEmpty) {
                      await ApiService.createLearningResource({
                        'title': titleController.text.trim(),
                        'url': urlController.text.trim(),
                        'notes': notesController.text.trim(),
                        'resource_type': resourceType,
                        'status': 'in_progress',
                        'progress_percentage': 0.0,
                      });
                      if (context.mounted) Navigator.pop(context);
                      _loadResources();
                    }
                  },
                  child: const Text("Save Resource"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Learning Roadmap", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: AppTheme.label)),
                  GestureDetector(
                    onTap: _showAddSheet,
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

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        if (isLoading)
          const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
        else if (resources.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 48, color: AppTheme.tertiaryLabel),
                  const SizedBox(height: 12),
                  const Text("No learning resources yet", style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text("Tap + to add your first study roadmap goal", style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: List.generate(resources.length, (i) {
                  final res = resources[i];
                  final title = res['title'] ?? '';
                  final type = (res['resource_type'] ?? 'course').toString();
                  final url = res['url'] ?? '';
                  final progress = (res['progress_percentage'] ?? 0.0).toDouble();
                  final notes = res['notes'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.tertiaryBg, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_resourceIcon(type), color: AppTheme.accent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.label),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text("${progress.toInt()}%", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                            ),
                          ],
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(notes, style: const TextStyle(fontSize: 12, color: AppTheme.secondaryLabel)),
                        ],
                        const SizedBox(height: 12),

                        // Interactive Progress Slider
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            activeTrackColor: AppTheme.accent,
                            inactiveTrackColor: AppTheme.tertiaryBg,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: progress.clamp(0.0, 100.0),
                            min: 0.0,
                            max: 100.0,
                            onChanged: (newVal) {
                              setState(() {
                                res['progress_percentage'] = newVal;
                              });
                            },
                            onChangeEnd: (newVal) async {
                              await ApiService.updateLearningResourceProgress(res['id'], newVal);
                              _loadResources();
                            },
                          ),
                        ),
                        if (url.isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(url, style: const TextStyle(fontSize: 10, color: AppTheme.accent, decoration: TextDecoration.underline)),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }

  IconData _resourceIcon(String type) {
    if (type == 'course') return Icons.school_rounded;
    if (type == 'documentation') return Icons.menu_book_rounded;
    return Icons.article_rounded;
  }
}
