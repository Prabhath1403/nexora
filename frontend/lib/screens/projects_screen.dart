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
  int _mainTab = 0; // 0 = Active Projects & Tasks, 1 = Learning Roadmap
  int _taskFilter = 0; // 0 = To Do, 1 = In Progress, 2 = Done

  List<dynamic> projects = [];
  List<dynamic> tasks = [];
  List<dynamic> learningResources = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    final pList = await ApiService.fetchProjects();
    final tList = await ApiService.fetchTasks();
    final lList = await ApiService.fetchLearningResources();
    if (!mounted) return;
    setState(() {
      projects = pList;
      tasks = tList;
      learningResources = lList;
      isLoading = false;
    });
  }

  void _showAddTaskSheet() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedPriority = "medium";
    String? selectedProjectId;

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
                const Text("New Task Milestone", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.label)),
                const SizedBox(height: 16),

                _buildTextField(titleController, "Title", "e.g., Integrate Google Calendar Sync"),
                const SizedBox(height: 10),
                _buildTextField(descriptionController, "Description", "Details (optional)"),
                const SizedBox(height: 14),

                const Text("PRIORITY", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      _buildPriorityOption("High 🔴", "high", selectedPriority, (p) => setModalState(() => selectedPriority = p)),
                      _buildPriorityOption("Medium 🟠", "medium", selectedPriority, (p) => setModalState(() => selectedPriority = p)),
                      _buildPriorityOption("Low 🟢", "low", selectedPriority, (p) => setModalState(() => selectedPriority = p)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () async {
                    if (titleController.text.trim().isNotEmpty) {
                      await ApiService.createTask({
                        'title': titleController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'priority': selectedPriority,
                        'project_id': selectedProjectId,
                        'status': 'todo',
                      });
                      if (context.mounted) Navigator.pop(context);
                      _loadAllData();
                    }
                  },
                  child: const Text("Create Task"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddProjectSheet() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final repoController = TextEditingController();

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
                const Text("New Software Project", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.label)),
                const SizedBox(height: 16),

                _buildTextField(nameController, "Name", "e.g., AI Finance Mobile"),
                const SizedBox(height: 10),
                _buildTextField(descriptionController, "Description", "Brief scope & tech stack"),
                const SizedBox(height: 10),
                _buildTextField(repoController, "GitHub Repo", "owner/repository-name (optional)"),
                const SizedBox(height: 20),

                CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      await ApiService.createProject({
                        'name': nameController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'github_repo': repoController.text.trim().isNotEmpty ? repoController.text.trim() : null,
                        'color_hex': '#6366F1',
                        'status': 'active',
                      });
                      if (context.mounted) Navigator.pop(context);
                      _loadAllData();
                    }
                  },
                  child: const Text("Create Project"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _importGitHubIssues() async {
    final count = await ApiService.importGitHubIssues();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(count > 0 ? "Imported $count GitHub issues into tasks! 🐙" : "No new GitHub issues found or GitHub not connected"),
        backgroundColor: count > 0 ? AppTheme.accentGreen : AppTheme.tertiaryBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    _loadAllData();
  }

  void _showAddLearningResourceSheet() {
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
                const Text("New Learning Goal", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.label)),
                const SizedBox(height: 16),

                _buildTextField(titleController, "Topic / Title", "e.g., Flutter Custom Animations"),
                const SizedBox(height: 10),
                _buildTextField(urlController, "URL Link", "https://flutter.dev/docs"),
                const SizedBox(height: 10),
                _buildTextField(notesController, "Notes", "Key topics to learn"),
                const SizedBox(height: 14),

                const Text("RESOURCE TYPE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.secondaryLabel, letterSpacing: 0.5)),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      _buildPriorityOption("Course 🎓", "course", resourceType, (t) => setModalState(() => resourceType = t)),
                      _buildPriorityOption("Docs 📖", "documentation", resourceType, (t) => setModalState(() => resourceType = t)),
                      _buildPriorityOption("Article 📰", "article", resourceType, (t) => setModalState(() => resourceType = t)),
                    ],
                  ),
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
                      _loadAllData();
                    }
                  },
                  child: const Text("Add Learning Goal"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String placeholder) {
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

  Widget _buildPriorityOption(String label, String value, String current, Function(String) onSelect) {
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

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Title Bar + Dual Tab Switcher
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Workspace", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: AppTheme.label)),
                      GestureDetector(
                        onTap: () => _mainTab == 0 ? _showAddTaskSheet() : _showAddLearningResourceSheet(),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.add_rounded, color: AppTheme.accent, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Main Dual Tab Selector (Projects vs Learning Roadmap)
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.tertiaryBg, width: 1),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(child: _buildMainTabItem(0, "📁 Active Projects", Icons.folder_open_rounded)),
                        Expanded(child: _buildMainTabItem(1, "📚 Learning Roadmap", Icons.auto_stories_rounded)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (isLoading)
          const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
        else if (_mainTab == 0)
          ..._buildProjectsAndTasksSlivers()
        else
          ..._buildLearningRoadmapSlivers(),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildMainTabItem(int index, String label, IconData icon) {
    final isSelected = _mainTab == index;
    return GestureDetector(
      onTap: () => setState(() => _mainTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.secondaryLabel),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TAB 1: PROJECTS & TASKS ====================
  List<Widget> _buildProjectsAndTasksSlivers() {
    final todoTasks = tasks.where((t) => (t['status'] ?? 'todo') == 'todo').toList();
    final progressTasks = tasks.where((t) => t['status'] == 'in_progress').toList();
    final doneTasks = tasks.where((t) => t['status'] == 'done').toList();
    final filteredTasks = [todoTasks, progressTasks, doneTasks][_taskFilter.clamp(0, 2)];

    return [
      // Projects Portfolio Overview
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "ACTIVE PROJECTS",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.secondaryLabel, letterSpacing: 0.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _importGitHubIssues,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download_rounded, size: 12, color: AppTheme.accentGreen),
                          SizedBox(width: 3),
                          Text("Import GH", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accentGreen)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _showAddProjectSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 12, color: AppTheme.accent),
                          SizedBox(width: 2),
                          Text("Project", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: List.generate(projects.length, (i) {
                    final p = projects[i];
                    final pColor = _hexToColor(p['color_hex']);
                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: pColor.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(color: pColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p['name'] ?? '',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.label),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(p['description'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.secondaryLabel), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: pColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                child: Text(p['status'] ?? 'active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: pColor)),
                              ),
                              if (p['github_repo'] != null)
                                const Icon(Icons.code_rounded, size: 14, color: AppTheme.secondaryLabel),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),

      // Task Filter Segmented Bar
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: AppTheme.secondaryBg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Expanded(child: _buildTaskFilterItem(0, "To Do (${todoTasks.length})")),
                Expanded(child: _buildTaskFilterItem(1, "In Progress (${progressTasks.length})")),
                Expanded(child: _buildTaskFilterItem(2, "Done (${doneTasks.length})")),
              ],
            ),
          ),
        ),
      ),

      // Task List Cards
      if (filteredTasks.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text("No tasks in this state", style: const TextStyle(color: AppTheme.secondaryLabel, fontSize: 14)),
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
                children: List.generate(filteredTasks.length, (index) {
                  final task = filteredTasks[index];
                  final priority = (task['priority'] ?? 'medium').toString();
                  final priorityColor = priority == 'high' ? AppTheme.accentRed : (priority == 'medium' ? AppTheme.accentOrange : AppTheme.accentGreen);
                  final isDone = task['status'] == 'done';

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final nextStatus = isDone ? 'todo' : 'done';
                                await ApiService.updateTaskStatus(task['id'], nextStatus);
                                _loadAllData();
                              },
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: isDone ? AppTheme.accentGreen : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDone ? AppTheme.accentGreen : AppTheme.tertiaryLabel, width: 2),
                                ),
                                child: isDone ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task['title'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                      color: isDone ? AppTheme.secondaryLabel : AppTheme.label,
                                    ),
                                  ),
                                  if (task['description'] != null && task['description'].toString().isNotEmpty)
                                    Text(task['description'], style: const TextStyle(fontSize: 11, color: AppTheme.secondaryLabel)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: priorityColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                              child: Text(priority.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: priorityColor)),
                            ),
                          ],
                        ),
                      ),
                      if (index < filteredTasks.length - 1)
                        const Padding(padding: EdgeInsets.only(left: 54), child: Divider(height: 0.5, thickness: 0.3, color: AppTheme.separator)),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildTaskFilterItem(int index, String label) {
    final isSelected = _taskFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _taskFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.tertiaryBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppTheme.label : AppTheme.secondaryLabel),
        ),
      ),
    );
  }

  // ==================== TAB 2: LEARNING ROADMAP ====================
  List<Widget> _buildLearningRoadmapSlivers() {
    return [
      if (learningResources.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text("No learning resources added yet", style: const TextStyle(color: AppTheme.secondaryLabel, fontSize: 14)),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: List.generate(learningResources.length, (i) {
                final res = learningResources[i];
                final title = res['title'] ?? '';
                final type = (res['resource_type'] ?? 'course').toString();
                final url = res['url'] ?? '';
                final progress = (res['progress_percentage'] ?? 0.0).toDouble();
                final notes = res['notes'] ?? '';
                final tags = (res['tags'] as List?) ?? [];

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
                            _loadAllData();
                          },
                        ),
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: tags.map((t) => Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.tertiaryBg, borderRadius: BorderRadius.circular(4)),
                              child: Text("#$t", style: const TextStyle(fontSize: 10, color: AppTheme.secondaryLabel)),
                            )).toList(),
                          ),
                          if (url.isNotEmpty)
                            Text(url, style: const TextStyle(fontSize: 10, color: AppTheme.accent, decoration: TextDecoration.underline)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
    ];
  }

  IconData _resourceIcon(String type) {
    if (type == 'course') return Icons.school_rounded;
    if (type == 'documentation') return Icons.menu_book_rounded;
    return Icons.article_rounded;
  }

  Color _hexToColor(String? hex) {
    if (hex == null || !hex.startsWith('#')) return AppTheme.accent;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.accent;
    }
  }
}
