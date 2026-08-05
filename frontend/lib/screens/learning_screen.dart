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
  String selectedFilter = "all"; // all, course, documentation, article, book

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
    final tagsController = TextEditingController();
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

                // Resource Type Selector
                Row(
                  children: [
                    _typeChip("course", "Course", Icons.school_rounded, resourceType, (val) => setModalState(() => resourceType = val)),
                    const SizedBox(width: 6),
                    _typeChip("documentation", "Docs", Icons.menu_book_rounded, resourceType, (val) => setModalState(() => resourceType = val)),
                    const SizedBox(width: 6),
                    _typeChip("article", "Article", Icons.article_rounded, resourceType, (val) => setModalState(() => resourceType = val)),
                  ],
                ),
                const SizedBox(height: 14),

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
                  placeholder: "URL (e.g. https://flutter.dev)",
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)),
                  style: const TextStyle(color: AppTheme.label),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: notesController,
                  placeholder: "Notes / Description",
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)),
                  style: const TextStyle(color: AppTheme.label),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: tagsController,
                  placeholder: "Tags (comma separated, e.g. Flutter, Dart)",
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)),
                  style: const TextStyle(color: AppTheme.label),
                ),
                const SizedBox(height: 20),

                CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () async {
                    if (titleController.text.trim().isNotEmpty) {
                      final tags = tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                      await ApiService.createLearningResource({
                        'title': titleController.text.trim(),
                        'url': urlController.text.trim(),
                        'notes': notesController.text.trim(),
                        'resource_type': resourceType,
                        'status': 'in_progress',
                        'progress_percentage': 0.0,
                        'tags': tags,
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

  Widget _typeChip(String type, String label, IconData icon, String selectedType, Function(String) onSelect) {
    final isSelected = selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.tertiaryBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppTheme.accent : Colors.transparent, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppTheme.accent : AppTheme.secondaryLabel),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppTheme.accent : AppTheme.secondaryLabel)),
            ],
          ),
        ),
      ),
    );
  }

  List<dynamic> get filteredResources {
    if (selectedFilter == "all") return resources;
    return resources.where((r) => (r['resource_type'] ?? '').toString() == selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = filteredResources;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
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
                      Text("SKILL ROADMAP & GOALS", style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      SizedBox(height: 2),
                      Text("Learning Roadmap", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: AppTheme.label)),
                    ],
                  ),
                  GestureDetector(
                    onTap: _showAddSheet,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.add_rounded, color: AppTheme.accent, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Filter Chips Bar
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _filterChip("all", "All Resources"),
                _filterChip("course", "Courses"),
                _filterChip("documentation", "Documentation"),
                _filterChip("article", "Articles"),
              ],
            ),
          ),
        ),

        if (isLoading)
          const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
        else if (list.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 52, color: AppTheme.tertiaryLabel),
                  const SizedBox(height: 12),
                  const Text("No learning resources found", style: TextStyle(color: AppTheme.secondaryLabel, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text("Tap + to add your first study roadmap goal", style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final res = list[i];
                  final id = res['id'] ?? '';
                  final title = res['title'] ?? '';
                  final type = (res['resource_type'] ?? 'course').toString();
                  final url = res['url'] ?? '';
                  final progress = (res['progress_percentage'] ?? 0.0).toDouble();
                  final notes = res['notes'] ?? '';
                  final tags = (res['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];

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
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: _resourceColor(type).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(_resourceIcon(type), color: _resourceColor(type), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.label),
                                  ),
                                  Text(
                                    type.toUpperCase(),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _resourceColor(type)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: progress >= 100.0 ? AppTheme.accentGreen.withValues(alpha: 0.15) : AppTheme.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                progress >= 100.0 ? "DONE 🎉" : "${progress.toInt()}%",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: progress >= 100.0 ? AppTheme.accentGreen : AppTheme.accent,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.secondaryLabel, size: 20),
                              onPressed: () async {
                                await ApiService.deleteLearningResource(id);
                                _loadResources();
                              },
                            ),
                          ],
                        ),

                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(notes, style: const TextStyle(fontSize: 13, color: AppTheme.secondaryLabel)),
                        ],

                        // Tags List
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: tags.map((t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.tertiaryBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text("#$t", style: const TextStyle(fontSize: 11, color: AppTheme.secondaryLabel, fontWeight: FontWeight.w600)),
                            )).toList(),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Interactive Progress Slider
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            activeTrackColor: progress >= 100.0 ? AppTheme.accentGreen : AppTheme.accent,
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
                              await ApiService.updateLearningResourceProgress(id, newVal);
                              _loadResources();
                            },
                          ),
                        ),

                        if (url.isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              url,
                              style: const TextStyle(fontSize: 11, color: AppTheme.accent, decoration: TextDecoration.underline),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  );
                },
                childCount: list.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _filterChip(String filter, String label) {
    final isSelected = selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = filter),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : AppTheme.secondaryBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.accent : AppTheme.tertiaryBg, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.secondaryLabel,
          ),
        ),
      ),
    );
  }

  IconData _resourceIcon(String type) {
    if (type == 'course') return Icons.school_rounded;
    if (type == 'documentation') return Icons.menu_book_rounded;
    return Icons.article_rounded;
  }

  Color _resourceColor(String type) {
    if (type == 'course') return AppTheme.accentPurple;
    if (type == 'documentation') return AppTheme.accentTeal;
    return AppTheme.accentOrange;
  }
}
