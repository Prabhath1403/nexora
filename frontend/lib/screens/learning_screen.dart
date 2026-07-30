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

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    final res = await ApiService.fetchLearningResources();
    if (!mounted) return;
    setState(() => resources = res);
  }

  void _showAddSheet() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: const BoxDecoration(color: AppTheme.secondaryBg, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.tertiaryLabel, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text("Add Resource", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            CupertinoTextField(controller: titleController, placeholder: "Title / Course", padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)), style: const TextStyle(color: AppTheme.label)),
            const SizedBox(height: 10),
            CupertinoTextField(controller: urlController, placeholder: "URL (optional)", padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)), style: const TextStyle(color: AppTheme.label)),
            const SizedBox(height: 20),
            CupertinoButton.filled(borderRadius: BorderRadius.circular(12), onPressed: () async {
              if (titleController.text.trim().isNotEmpty) {
                await ApiService.createLearningResource({'title': titleController.text.trim(), 'url': urlController.text.trim(), 'resource_type': 'article'});
                if (context.mounted) Navigator.pop(context);
                _loadResources();
              }
            }, child: const Text("Save")),
          ],
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
                  const Text("Learning", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                  GestureDetector(
                    onTap: _showAddSheet,
                    child: Container(width: 32, height: 32,
                      decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.add, color: AppTheme.accent, size: 20)),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (resources.isEmpty)
          SliverFillRemaining(
            child: Center(child: Text("No learning resources yet", style: TextStyle(color: AppTheme.secondaryLabel))),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            sliver: SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(color: AppTheme.secondaryBg, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: List.generate(resources.length, (i) {
                    final item = resources[i];
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.bookmark_border_rounded, color: AppTheme.accent, size: 20),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                    if (item['url'] != null && item['url'].toString().isNotEmpty)
                                      Text(item['url'], style: const TextStyle(fontSize: 11, color: AppTheme.secondaryLabel), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                child: Text(item['status'] ?? 'to_read', style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                        if (i < resources.length - 1)
                          const Padding(padding: EdgeInsets.only(left: 52), child: Divider(height: 0.5, thickness: 0.3, color: AppTheme.separator)),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
