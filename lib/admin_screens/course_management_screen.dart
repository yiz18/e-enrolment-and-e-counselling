import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import '../data/riasec_tags_seed.dart';
import '../data/tarumt_course_seeder.dart';
import '../navigation/logout_navigation.dart';

// =============================================================================
// Main Screen
// =============================================================================

class CourseManagementScreen extends StatefulWidget {
  const CourseManagementScreen({super.key});

  @override
  State<CourseManagementScreen> createState() => _CourseManagementScreenState();
}

class _CourseManagementScreenState extends State<CourseManagementScreen> {
  final _service = CourseService();
  bool _seedingRiasec = false;
  bool _seedingTarumt = false;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Course Management'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          if (MediaQuery.of(context).size.width >= 768)
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle, color: Colors.white),
              onSelected: (value) {
                if (value == 'logout') {
                  logoutToRoleSelection(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'logout', child: Text('Logout')),
              ],
            )
          else
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () => Navigator.pushNamed(context, '/adminProfile'),
            ),
        ],
      ),
      body: StreamBuilder<List<Course>>(
        stream: _service.getCoursesStream(),
        builder: (context, snapshot) {
          // ---- Error state --------------------------------------------------
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load courses.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          // ---- Loading state ------------------------------------------------
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ---- Data state ---------------------------------------------------
          final courses = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildStatRow(courses),
                const SizedBox(height: 24),
                _buildCourseTable(context, courses),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RIASEC seed — temporary admin tool
  // ---------------------------------------------------------------------------

  Future<void> _seedRiasecTags(BuildContext context) async {
    setState(() => _seedingRiasec = true);

    try {
      final result = await seedRiasecTags();

      // Print full report to debug console.
      debugPrint(result.toString());
      for (final name in result.updated) {
        debugPrint('  [RIASEC SEED] ✓ updated: $name');
      }
      for (final name in result.notFound) {
        debugPrint('  [RIASEC SEED] ✗ not found: $name');
      }

      if (!context.mounted) return;

      final message = result.allUpdated
          ? 'RIASEC tags seeded for all ${result.updated.length} courses.'
          : '${result.updated.length} updated, '
              '${result.notFound.length} not found — check debug console.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              result.allUpdated ? Colors.green[700] : Colors.orange[700],
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e, st) {
      debugPrint('[RIASEC SEED] error: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seed failed: $e'),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _seedingRiasec = false);
    }
  }

  // ---------------------------------------------------------------------------
  // TARUMT course seed — temporary admin tool
  // ---------------------------------------------------------------------------

  Future<void> _seedTarumtCourses(BuildContext context) async {
    setState(() => _seedingTarumt = true);

    try {
      final result = await seedTarumtCourses();

      debugPrint(result.toString());

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _TarumtSeedResultDialog(result: result),
      );
    } catch (e, st) {
      debugPrint('[TARUMT SEED] error: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('TARUMT seed failed: $e'),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _seedingTarumt = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Course Management',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage courses and recommendation requirements.',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
        // ── Temporary admin seed tool — TARUMT courses ───────────────────
        OutlinedButton.icon(
          onPressed:
              _seedingTarumt ? null : () => _seedTarumtCourses(context),
          icon: _seedingTarumt
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_outlined, size: 18),
          label: const Text('Seed TARUMT Courses'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.teal[700],
            side: BorderSide(color: Colors.teal[600]!),
          ),
        ),
        const SizedBox(width: 8),
        // ── Temporary admin seed tool — RIASEC tags ──────────────────────
        OutlinedButton.icon(
          onPressed:
              _seedingRiasec ? null : () => _seedRiasecTags(context),
          icon: _seedingRiasec
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.label_outline, size: 18),
          label: const Text('Seed RIASEC Tags'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.amber[800],
            side: BorderSide(color: Colors.amber[700]!),
          ),
        ),
        const SizedBox(width: 8),
        // ─────────────────────────────────────────────────────────────────
        ElevatedButton.icon(
          onPressed: () => _showCourseFormDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Add Course'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Stats row — derived from the live Firestore snapshot
  // ---------------------------------------------------------------------------

  Widget _buildStatRow(List<Course> courses) {
    final active = courses.where((c) => c.isActive).length;
    final faculties = courses.map((c) => c.faculty).toSet().length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Courses',
            value: '${courses.length}',
            icon: Icons.menu_book,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            label: 'Active Courses',
            value: '$active',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            label: 'Faculties',
            value: '$faculties',
            icon: Icons.account_balance_outlined,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Course table — populated from the live Firestore snapshot
  // ---------------------------------------------------------------------------

  Widget _buildCourseTable(BuildContext context, List<Course> courses) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All Courses',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${courses.length} course${courses.length == 1 ? '' : 's'} found',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  Colors.blueAccent.withValues(alpha: 0.07),
                ),
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                columns: const [
                  DataColumn(
                    label: Text('Course Code',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  DataColumn(
                    label: Text('Course Name',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  DataColumn(
                    label: Text('Faculty',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  DataColumn(
                    label: Text('Level',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  DataColumn(
                    label: Text('Status',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  DataColumn(
                    label: Text('Actions',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
                rows: courses.map((course) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          course.code,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 260,
                          child: Text(
                            course.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(course.faculty)),
                      DataCell(Text(course.level)),
                      DataCell(_StatusBadge(isActive: course.isActive)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionButton(
                              label: 'View',
                              color: Colors.blueAccent,
                              onTap: () => _showViewDialog(context, course),
                            ),
                            const SizedBox(width: 6),
                            _ActionButton(
                              label: 'Edit',
                              color: Colors.orange,
                              onTap: () => _showCourseFormDialog(
                                context,
                                course: course,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _ActionButton(
                              label: 'Delete',
                              color: Colors.red,
                              onTap: () =>
                                  _showDeleteDialog(context, course),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // View dialog — read-only, displays admission pathways with OR separators
  // ---------------------------------------------------------------------------

  void _showViewDialog(BuildContext context, Course course) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.menu_book, color: Colors.blueAccent, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${course.code} — ${course.name}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Faculty', value: course.faculty),
                _DetailRow(label: 'Level', value: course.level),
                _DetailRow(
                  label: 'Status',
                  value: course.isActive ? 'Active' : 'Inactive',
                ),
                _DetailRow(
                  label: 'Interest Tags',
                  value: course.interestTags.isEmpty
                      ? '—'
                      : course.interestTags.join(', '),
                ),

                // ── Admission Pathways ─────────────────────────────────────
                if (course.admissionPathways.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const _SectionLabel('Admission Pathways'),
                  const SizedBox(height: 4),
                  Text(
                    'Satisfying any one pathway below qualifies for this course.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 12),
                  ...course.admissionPathways.asMap().entries.expand((entry) {
                    final idx = entry.key;
                    final pathway = entry.value;
                    final pathwayName = pathway['pathwayName'] as String? ??
                        'Pathway ${idx + 1}';
                    final routes = Map<String, dynamic>.from(
                        pathway['qualificationRoutes'] as Map? ?? {});

                    return [
                      // OR divider between pathways
                      if (idx > 0) const _OrDivider(),

                      // Pathway header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.route,
                                size: 15, color: Colors.blueAccent),
                            const SizedBox(width: 6),
                            Text(
                              pathwayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Qualification routes inside this pathway
                      ...routes.entries.map(
                        (e) => _RequirementCard(
                          qualType: e.key,
                          requirements:
                              Map<String, dynamic>.from(e.value as Map),
                        ),
                      ),
                    ];
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Add / Edit dialog (unified) — writes to Firestore via CourseService
  // ---------------------------------------------------------------------------

  void _showCourseFormDialog(BuildContext context, {Course? course}) {
    showDialog(
      context: context,
      builder: (_) => _CourseFormDialog(
        course: course,
        onSave: (saved) {
          final op = (course != null)
              ? _service.updateCourse(saved)
              : _service.addCourse(saved);

          op.catchError((e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error saving course: $e')),
              );
            }
          });
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Delete dialog — writes to Firestore via CourseService
  // ---------------------------------------------------------------------------

  void _showDeleteDialog(BuildContext context, Course course) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text(
          'Are you sure you want to delete "${course.name}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _service.deleteCourse(course.id).catchError((e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting course: $e')),
                  );
                }
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Course Form Dialog — shared by Add and Edit flows
// =============================================================================

class _CourseFormDialog extends StatefulWidget {
  /// Null = Add mode, non-null = Edit mode.
  final Course? course;
  final void Function(Course) onSave;

  const _CourseFormDialog({this.course, required this.onSave});

  @override
  State<_CourseFormDialog> createState() => _CourseFormDialogState();
}

class _CourseFormDialogState extends State<_CourseFormDialog> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _facultyCtrl;
  late final TextEditingController _levelCtrl;
  late final TextEditingController _tagsCtrl;
  late bool _isActive;

  // ── Pathway state ──────────────────────────────────────────────────────────

  /// Fully committed pathways — each `{ pathwayName, qualificationRoutes }`.
  late List<Map<String, dynamic>> _draftPathways;

  /// Routes staged for the pathway currently being configured.
  /// Keyed by qualification type — committed into [_draftPathways] via
  /// [_addPathway].
  Map<String, Map<String, dynamic>> _draftPathwayRoutes = {};

  /// Name for the pathway currently being configured.
  final _pathwayNameCtrl = TextEditingController();

  // ── Route builder state ───────────────────────────────────────────────────

  static const _qualOptions = [
    'Foundation',
    'Diploma',
    'STPM',
    'A-Level',
    'UEC',
    'SPM',
  ];

  static const _condQualOptions = [
    'SPM',
    'O-Level',
    'UEC',
    'STPM',
    'A-Level',
    'Foundation',
    'Diploma',
    'TAR UMT',
  ];

  static const _gradeOptions = ['A', 'B', 'C', 'D', 'E', 'Pass', 'Credit'];

  String _selectedQual = 'Foundation';
  final _cgpaCtrl = TextEditingController();

  final _minRelevantSubjectsCtrl = TextEditingController();
  String? _selectedMinGrade;
  List<String> _draftRelevantSubjects = [];
  final _relevantSubjectCtrl = TextEditingController();

  /// Condition groups staged for the route currently being built.
  /// Each entry: `{ 'operator': 'AND'|'OR', 'conditions': List<Map> }`
  List<Map<String, dynamic>> _draftConditionGroups = [];

  /// Parallel stable widget-key IDs for [_draftConditionGroups].
  /// Kept separate so the group data maps remain Firestore-clean.
  List<int> _draftConditionGroupIds = [];
  int _nextGroupId = 0;

  // ── Route editing state ───────────────────────────────────────────────────

  /// Route key (qualification type) currently being edited inside a committed
  /// pathway.  `null` = Route Builder is in "add new route" mode.
  String? _editingRouteKey;

  /// Index into [_draftPathways] of the pathway that owns [_editingRouteKey].
  int? _editingPathwayIndex;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _codeCtrl = TextEditingController(text: c?.code ?? '');
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _facultyCtrl = TextEditingController(text: c?.faculty ?? '');
    _levelCtrl = TextEditingController(text: c?.level ?? '');
    _tagsCtrl =
        TextEditingController(text: c?.interestTags.join(', ') ?? '');
    _isActive = c?.isActive ?? true;

    // Deep-copy admissionPathways so editing does not mutate the original.
    // Also normalises conditionGroups within each route for the new schema.
    _draftPathways = c != null
        ? c.admissionPathways.map((p) {
            final rawRoutes =
                Map<String, dynamic>.from(p['qualificationRoutes'] as Map? ?? {});
            final routes = <String, dynamic>{};
            rawRoutes.forEach((key, value) {
              final routeMap = Map<String, dynamic>.from(value as Map);
              final rawGroups =
                  (routeMap['conditionGroups'] as List?) ?? [];
              routeMap['conditionGroups'] = rawGroups.map((g) {
                final gMap = Map<String, dynamic>.from(g as Map);
                gMap['conditions'] = List<Map<String, dynamic>>.from(
                  (gMap['conditions'] as List? ?? [])
                      .map((cond) => Map<String, dynamic>.from(cond as Map)),
                );
                return gMap;
              }).toList();
              routes[key] = routeMap;
            });
            return <String, dynamic>{
              'pathwayName':
                  p['pathwayName'] as String? ?? 'Default Pathway',
              'qualificationRoutes': routes,
            };
          }).toList()
        : [];
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _facultyCtrl.dispose();
    _levelCtrl.dispose();
    _tagsCtrl.dispose();
    _pathwayNameCtrl.dispose();
    _cgpaCtrl.dispose();
    _minRelevantSubjectsCtrl.dispose();
    _relevantSubjectCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Route staging helpers
  // ---------------------------------------------------------------------------

  void _addConditionGroup() {
    setState(() {
      _draftConditionGroups.add({
        'operator': 'AND',
        'conditions': <Map<String, dynamic>>[],
      });
      _draftConditionGroupIds.add(_nextGroupId++);
    });
  }

  void _removeConditionGroup(int index) {
    setState(() {
      _draftConditionGroups.removeAt(index);
      _draftConditionGroupIds.removeAt(index);
    });
  }

  void _setConditionGroupOperator(int index, String operator) {
    setState(() {
      _draftConditionGroups[index] = {
        ..._draftConditionGroups[index],
        'operator': operator,
      };
    });
  }

  void _addConditionToGroup(int groupIndex, Map<String, dynamic> condition) {
    setState(() {
      final group =
          Map<String, dynamic>.from(_draftConditionGroups[groupIndex]);
      final conditions = List<Map<String, dynamic>>.from(
        (group['conditions'] as List? ?? [])
            .map((c) => Map<String, dynamic>.from(c as Map)),
      );
      conditions.add(condition);
      group['conditions'] = conditions;
      _draftConditionGroups[groupIndex] = group;
    });
  }

  void _removeConditionFromGroup(int groupIndex, int conditionIndex) {
    setState(() {
      final group =
          Map<String, dynamic>.from(_draftConditionGroups[groupIndex]);
      final conditions = List<Map<String, dynamic>>.from(
        (group['conditions'] as List? ?? [])
            .map((c) => Map<String, dynamic>.from(c as Map)),
      );
      conditions.removeAt(conditionIndex);
      group['conditions'] = conditions;
      _draftConditionGroups[groupIndex] = group;
    });
  }

  void _addRelevantSubject() {
    final subject = _relevantSubjectCtrl.text.trim();
    if (subject.isEmpty) return;
    if (_draftRelevantSubjects.contains(subject)) {
      _relevantSubjectCtrl.clear();
      return;
    }
    setState(() {
      _draftRelevantSubjects.add(subject);
      _relevantSubjectCtrl.clear();
    });
  }

  void _removeRelevantSubject(int index) {
    setState(() => _draftRelevantSubjects.removeAt(index));
  }

  /// Commits the current route into [_draftPathwayRoutes] and resets the
  /// per-route staging area.
  void _addRoute() {
    setState(() {
      _draftPathwayRoutes[_selectedQual] = {
        'minimumCgpa': double.tryParse(_cgpaCtrl.text.trim()),
        'minimumRelevantSubjects':
            int.tryParse(_minRelevantSubjectsCtrl.text.trim()),
        'minimumGrade': _selectedMinGrade,
        'relevantSubjects': List<String>.from(_draftRelevantSubjects),
        'conditionGroups':
            List<Map<String, dynamic>>.from(_draftConditionGroups),
      };
      _draftConditionGroups = [];
      _draftConditionGroupIds = [];
      _draftRelevantSubjects = [];
      _cgpaCtrl.clear();
      _minRelevantSubjectsCtrl.clear();
      _selectedMinGrade = null;
    });
  }

  /// Commits [_draftPathwayRoutes] as a new pathway into [_draftPathways] and
  /// resets all staging state for the next pathway.
  void _addPathway() {
    if (_draftPathwayRoutes.isEmpty) return;
    final name = _pathwayNameCtrl.text.trim();
    setState(() {
      _draftPathways.add({
        'pathwayName': name.isEmpty
            ? 'Pathway ${_draftPathways.length + 1}'
            : name,
        'qualificationRoutes': Map<String, dynamic>.from(_draftPathwayRoutes),
      });
      _draftPathwayRoutes = {};
      _pathwayNameCtrl.clear();
      _draftConditionGroups = [];
      _draftConditionGroupIds = [];
      _draftRelevantSubjects = [];
      _cgpaCtrl.clear();
      _minRelevantSubjectsCtrl.clear();
      _selectedMinGrade = null;
      _selectedQual = 'Foundation';
    });
  }

  // ---------------------------------------------------------------------------
  // Route editing helpers
  // ---------------------------------------------------------------------------

  /// Populates the Route Builder form from an existing committed route and
  /// enters editing mode.  The qual dropdown becomes read-only (locked to
  /// [routeKey]) so the map key cannot change accidentally.
  void _loadRouteForEditing(int pathwayIndex, String routeKey) {
    final rawRoute =
        (_draftPathways[pathwayIndex]['qualificationRoutes'] as Map)[routeKey]
            as Map;
    final route = Map<String, dynamic>.from(rawRoute);

    final rawGroups = (route['conditionGroups'] as List?) ?? [];
    final groups = rawGroups.map((g) {
      final gMap = Map<String, dynamic>.from(g as Map);
      gMap['conditions'] = List<Map<String, dynamic>>.from(
        (gMap['conditions'] as List? ?? [])
            .map((c) => Map<String, dynamic>.from(c as Map)),
      );
      return gMap;
    }).toList();

    setState(() {
      _editingRouteKey = routeKey;
      _editingPathwayIndex = pathwayIndex;
      _selectedQual = routeKey;
      _cgpaCtrl.text = route['minimumCgpa']?.toString() ?? '';
      _minRelevantSubjectsCtrl.text =
          route['minimumRelevantSubjects']?.toString() ?? '';
      _selectedMinGrade = route['minimumGrade'] as String?;
      _draftRelevantSubjects =
          List<String>.from((route['relevantSubjects'] as List?) ?? []);
      _draftConditionGroups = groups;
      _draftConditionGroupIds =
          List.generate(groups.length, (_) => _nextGroupId++);
    });
  }

  /// Writes the Route Builder's current state back into the target route
  /// inside the committed pathway, then exits editing mode.
  void _updateRoute() {
    if (_editingRouteKey == null || _editingPathwayIndex == null) return;
    setState(() {
      final pathway =
          Map<String, dynamic>.from(_draftPathways[_editingPathwayIndex!]);
      final routes =
          Map<String, dynamic>.from(pathway['qualificationRoutes'] as Map);

      routes[_editingRouteKey!] = {
        'minimumCgpa': double.tryParse(_cgpaCtrl.text.trim()),
        'minimumRelevantSubjects':
            int.tryParse(_minRelevantSubjectsCtrl.text.trim()),
        'minimumGrade': _selectedMinGrade,
        'relevantSubjects': List<String>.from(_draftRelevantSubjects),
        'conditionGroups':
            List<Map<String, dynamic>>.from(_draftConditionGroups),
      };

      pathway['qualificationRoutes'] = routes;
      _draftPathways[_editingPathwayIndex!] = pathway;
      _cancelEditing();
    });
  }

  /// Discards any in-progress edits and resets the Route Builder to default
  /// "add new route" state.
  void _cancelEditing() {
    setState(() {
      _editingRouteKey = null;
      _editingPathwayIndex = null;
      _draftConditionGroups = [];
      _draftConditionGroupIds = [];
      _draftRelevantSubjects = [];
      _cgpaCtrl.clear();
      _minRelevantSubjectsCtrl.clear();
      _selectedMinGrade = null;
      _selectedQual = 'Foundation';
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.course != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Course' : 'Add Course'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Basic Information ────────────────────────────────────────
              const _SectionLabel('Basic Information'),
              const SizedBox(height: 10),
              _FormField(controller: _codeCtrl, label: 'Course Code'),
              _FormField(controller: _nameCtrl, label: 'Course Name'),
              _FormField(controller: _facultyCtrl, label: 'Faculty'),
              _FormField(controller: _levelCtrl, label: 'Level'),
              _FormField(
                controller: _tagsCtrl,
                label: 'Interest Tags (comma separated)',
              ),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                activeThumbColor: Colors.blueAccent,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _isActive = v),
              ),

              const Divider(height: 28),

              // ── Admission Pathways ───────────────────────────────────────
              const _SectionLabel('Admission Pathways'),
              const SizedBox(height: 4),
              Text(
                'Add one or more pathways. A student satisfying ANY pathway is eligible.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),

              // Committed pathways list
              if (_draftPathways.isNotEmpty) ...[
                ..._draftPathways.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final pathway = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (idx > 0) const _OrDivider(),
                      _DraftPathwayBlock(
                        index: idx,
                        pathway: pathway,
                        onRemove: () {
                          if (_editingPathwayIndex == idx) _cancelEditing();
                          setState(() => _draftPathways.removeAt(idx));
                        },
                        onRemoveRoute: (routeKey) {
                          if (_editingPathwayIndex == idx &&
                              _editingRouteKey == routeKey) {
                            _cancelEditing();
                          }
                          setState(() {
                            final updatedRoutes = Map<String, dynamic>.from(
                                pathway['qualificationRoutes'] as Map);
                            updatedRoutes.remove(routeKey);
                            _draftPathways[idx] = {
                              'pathwayName': pathway['pathwayName'],
                              'qualificationRoutes': updatedRoutes,
                            };
                          });
                        },
                        onEditRoute: (routeKey) =>
                            _loadRouteForEditing(idx, routeKey),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                if (_editingRouteKey == null)
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'Add Another Pathway',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                const SizedBox(height: 12),
              ],

              // Pathway name field + staged routes — hidden while editing a
              // committed route to avoid mixing add and update flows.
              if (_editingRouteKey == null) ...[
                _FormField(
                  controller: _pathwayNameCtrl,
                  label: 'Pathway Name (e.g. Pathway 1)',
                ),
                if (_draftPathwayRoutes.isNotEmpty) ...[
                  ..._draftPathwayRoutes.entries.map(
                    (e) => _RouteChip(
                      qualType: e.key,
                      requirements: e.value,
                      onRemove: () =>
                          setState(() => _draftPathwayRoutes.remove(e.key)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],

              // Route builder
              _RouteBuilder(
                qualOptions: _qualOptions,
                selectedQual: _selectedQual,
                cgpaCtrl: _cgpaCtrl,
                minRelevantSubjectsCtrl: _minRelevantSubjectsCtrl,
                selectedMinGrade: _selectedMinGrade,
                gradeOptions: _gradeOptions,
                draftRelevantSubjects: _draftRelevantSubjects,
                relevantSubjectCtrl: _relevantSubjectCtrl,
                condQualOptions: _condQualOptions,
                draftConditionGroups: _draftConditionGroups,
                draftConditionGroupIds: _draftConditionGroupIds,
                // alreadyAdded only applies in add mode
                alreadyAdded: _editingRouteKey == null &&
                    _draftPathwayRoutes.containsKey(_selectedQual),
                onQualChanged: (v) => setState(() {
                  _selectedQual = v!;
                  _draftConditionGroups = [];
                  _draftConditionGroupIds = [];
                  _draftRelevantSubjects = [];
                  _cgpaCtrl.clear();
                  _minRelevantSubjectsCtrl.clear();
                  _selectedMinGrade = null;
                }),
                onMinGradeChanged: (v) =>
                    setState(() => _selectedMinGrade = v),
                onAddRelevantSubject: _addRelevantSubject,
                onRemoveRelevantSubject: _removeRelevantSubject,
                onAddConditionGroup: _addConditionGroup,
                onRemoveConditionGroup: _removeConditionGroup,
                onConditionGroupOperatorChanged: _setConditionGroupOperator,
                onAddConditionToGroup: _addConditionToGroup,
                onRemoveConditionFromGroup: _removeConditionFromGroup,
                onAdd: _addRoute,
                editingRouteKey: _editingRouteKey,
                onUpdate: _updateRoute,
                onCancelEdit: _cancelEditing,
              ),

              const SizedBox(height: 10),

              // Add Pathway button — hidden while editing a committed route
              if (_editingRouteKey == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _draftPathwayRoutes.isNotEmpty ? _addPathway : null,
                    icon: const Icon(Icons.add_road, size: 16),
                    label: const Text('Add Pathway'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[200],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_codeCtrl.text.trim().isEmpty ||
                _nameCtrl.text.trim().isEmpty) {
              return;
            }
            final code = _codeCtrl.text.trim();
            widget.onSave(Course(
              id: widget.course?.id ?? code,
              code: code,
              name: _nameCtrl.text.trim(),
              faculty: _facultyCtrl.text.trim(),
              level: _levelCtrl.text.trim(),
              isActive: _isActive,
              interestTags: _tagsCtrl.text
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList(),
              admissionPathways: List.from(_draftPathways),
            ));
            Navigator.pop(context);
          },
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

// =============================================================================
// Route Builder widget — builds one qualification route with condition groups
// =============================================================================

class _RouteBuilder extends StatelessWidget {
  final List<String> qualOptions;
  final String selectedQual;
  final TextEditingController cgpaCtrl;
  final TextEditingController minRelevantSubjectsCtrl;
  final String? selectedMinGrade;
  final List<String> gradeOptions;
  final List<String> draftRelevantSubjects;
  final TextEditingController relevantSubjectCtrl;
  final List<String> condQualOptions;

  /// Condition groups staged for the route currently being built.
  final List<Map<String, dynamic>> draftConditionGroups;

  /// Stable widget-key IDs parallel to [draftConditionGroups].
  final List<int> draftConditionGroupIds;

  static const Map<String, List<String>> _condGradeOptions = {
    'SPM':        ['Pass', 'Credit'],
    'O-Level':    ['A', 'B', 'C', 'D', 'E'],
    'UEC':        ['A', 'B', 'C', 'D', 'E'],
    'STPM':       ['A', 'B', 'C', 'D', 'E'],
    'A-Level':    ['A', 'B', 'C', 'D', 'E'],
    'Foundation': ['Pass', 'Credit', 'Distinction'],
    'Diploma':    ['Pass', 'Credit', 'Distinction'],
    'TAR UMT':    ['Pass', 'Credit', 'Distinction'],
  };

  final bool alreadyAdded;
  final ValueChanged<String?> onQualChanged;
  final ValueChanged<String?> onMinGradeChanged;
  final VoidCallback onAddRelevantSubject;
  final void Function(int) onRemoveRelevantSubject;
  final VoidCallback onAddConditionGroup;
  final void Function(int) onRemoveConditionGroup;
  final void Function(int, String) onConditionGroupOperatorChanged;
  final void Function(int, Map<String, dynamic>) onAddConditionToGroup;
  final void Function(int, int) onRemoveConditionFromGroup;
  final VoidCallback onAdd;

  /// Non-null = edit mode.  The qual dropdown is locked to this key and
  /// the action button shows "Update Route" instead of "Add Route".
  final String? editingRouteKey;

  /// Called when "Update Route" is pressed in edit mode.
  final VoidCallback? onUpdate;

  /// Called when "Cancel" is pressed in edit mode.
  final VoidCallback? onCancelEdit;

  const _RouteBuilder({
    required this.qualOptions,
    required this.selectedQual,
    required this.cgpaCtrl,
    required this.minRelevantSubjectsCtrl,
    required this.selectedMinGrade,
    required this.gradeOptions,
    required this.draftRelevantSubjects,
    required this.relevantSubjectCtrl,
    required this.condQualOptions,
    required this.draftConditionGroups,
    required this.draftConditionGroupIds,
    required this.alreadyAdded,
    required this.onQualChanged,
    required this.onMinGradeChanged,
    required this.onAddRelevantSubject,
    required this.onRemoveRelevantSubject,
    required this.onAddConditionGroup,
    required this.onRemoveConditionGroup,
    required this.onConditionGroupOperatorChanged,
    required this.onAddConditionToGroup,
    required this.onRemoveConditionFromGroup,
    required this.onAdd,
    this.editingRouteKey,
    this.onUpdate,
    this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isEditing = editingRouteKey != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEditing
            ? Colors.orange.withValues(alpha: 0.04)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEditing
              ? Colors.orange.withValues(alpha: 0.35)
              : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row with optional edit-mode banner ──────────────────
          Row(
            children: [
              if (isEditing) ...[
                const Icon(Icons.edit_outlined,
                    size: 14, color: Colors.orange),
                const SizedBox(width: 6),
              ],
              Text(
                isEditing
                    ? 'Edit Route: $editingRouteKey'
                    : 'Add Qualification Route',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isEditing ? Colors.orange[800] : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Qualification type dropdown — locked in edit mode
          DropdownButtonFormField<String>(
            initialValue: selectedQual,
            decoration: InputDecoration(
              labelText: 'Qualification Type',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: isEditing
                  ? const Tooltip(
                      message:
                          'Qualification type is locked while editing.\n'
                          'Remove the route and add a new one to change it.',
                      child: Icon(Icons.lock_outline,
                          size: 16, color: Colors.orange),
                    )
                  : null,
            ),
            items: qualOptions
                .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                .toList(),
            onChanged: isEditing ? null : onQualChanged,
          ),
          const SizedBox(height: 10),

          _FormField(
            controller: cgpaCtrl,
            label: 'Minimum CGPA (leave blank if not required)',
          ),

          // ── Relevant Subjects ──────────────────────────────────────────
          _RouteBuilderSectionLabel('Relevant Subjects'),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _FormField(
                  controller: minRelevantSubjectsCtrl,
                  label: 'Minimum Relevant Subjects',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedMinGrade,
                  decoration: InputDecoration(
                    labelText: 'Minimum Grade',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('— None —'),
                    ),
                    ...gradeOptions.map(
                      (g) => DropdownMenuItem(value: g, child: Text(g)),
                    ),
                  ],
                  onChanged: onMinGradeChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (draftRelevantSubjects.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: draftRelevantSubjects.asMap().entries.map((e) {
                return InputChip(
                  label: Text(e.value,
                      style: const TextStyle(fontSize: 12)),
                  onDeleted: () => onRemoveRelevantSubject(e.key),
                  deleteIconColor: Colors.red,
                  backgroundColor:
                      Colors.blueAccent.withValues(alpha: 0.08),
                  side: BorderSide(
                      color: Colors.blueAccent.withValues(alpha: 0.3)),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],

          Row(
            children: [
              Expanded(
                child: _FormField(
                  controller: relevantSubjectCtrl,
                  label: 'Add Relevant Subject',
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onAddRelevantSubject,
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Add'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.blueAccent),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // ── Condition Groups ────────────────────────────────────────────
          _RouteBuilderSectionLabel('Condition Groups'),
          const SizedBox(height: 4),
          Text(
            'Use AND / OR groups to express complex entry requirements.'
            ' Leave empty if not required.',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),

          ...draftConditionGroups.asMap().entries.map((entry) {
            final idx = entry.key;
            final group = entry.value;
            return _ConditionGroupCard(
              key: ValueKey(draftConditionGroupIds[idx]),
              groupIndex: idx,
              operator: group['operator'] as String? ?? 'AND',
              conditions: (group['conditions'] as List?)
                      ?.map((c) => Map<String, dynamic>.from(c as Map))
                      .toList() ??
                  [],
              condQualOptions: condQualOptions,
              condGradeOptions: _condGradeOptions,
              onOperatorChanged: (op) =>
                  onConditionGroupOperatorChanged(idx, op),
              onAddCondition: (cond) => onAddConditionToGroup(idx, cond),
              onRemoveCondition: (condIdx) =>
                  onRemoveConditionFromGroup(idx, condIdx),
              onRemoveGroup: () => onRemoveConditionGroup(idx),
            );
          }),

          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAddConditionGroup,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Condition Group'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                side: const BorderSide(color: Colors.blueAccent),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Action row: edit mode vs add mode ──────────────────────────
          if (isEditing) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onUpdate,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Update Route'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: onCancelEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[400]!),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: alreadyAdded ? null : onAdd,
                icon: const Icon(Icons.check, size: 16),
                label: Text(
                  alreadyAdded
                      ? 'Already Added — Remove to Re-add'
                      : 'Add Route',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side: BorderSide(
                    color: alreadyAdded
                        ? Colors.grey[300]!
                        : Colors.blueAccent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// _ConditionGroupCard — one condition group with operator toggle and inline form
// =============================================================================

class _ConditionGroupCard extends StatefulWidget {
  final int groupIndex;
  final String operator;
  final List<Map<String, dynamic>> conditions;
  final List<String> condQualOptions;
  final Map<String, List<String>> condGradeOptions;
  final ValueChanged<String> onOperatorChanged;
  final void Function(Map<String, dynamic>) onAddCondition;
  final void Function(int) onRemoveCondition;
  final VoidCallback onRemoveGroup;

  const _ConditionGroupCard({
    super.key,
    required this.groupIndex,
    required this.operator,
    required this.conditions,
    required this.condQualOptions,
    required this.condGradeOptions,
    required this.onOperatorChanged,
    required this.onAddCondition,
    required this.onRemoveCondition,
    required this.onRemoveGroup,
  });

  @override
  State<_ConditionGroupCard> createState() => _ConditionGroupCardState();
}

class _ConditionGroupCardState extends State<_ConditionGroupCard> {
  String _selectedCondQual = 'SPM';
  final _subjectCtrl = TextEditingController();
  String? _selectedConditionGrade;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    super.dispose();
  }

  void _handleAdd() {
    final subject = _subjectCtrl.text.trim();
    if (subject.isEmpty || _selectedConditionGrade == null) return;
    widget.onAddCondition({
      'qualification': _selectedCondQual,
      'subject': subject,
      'grade': _selectedConditionGrade!,
    });
    setState(() {
      _subjectCtrl.clear();
      _selectedConditionGrade = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gradeOptions =
        widget.condGradeOptions[_selectedCondQual] ?? ['Pass', 'Credit'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Group header ───────────────────────────────────────────────
          Row(
            children: [
              Text(
                'Group ${widget.groupIndex + 1}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: widget.operator,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: ['AND', 'OR'].map((op) {
                  final isOr = op == 'OR';
                  return DropdownMenuItem(
                    value: op,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOr
                            ? Colors.orange.withValues(alpha: 0.12)
                            : Colors.blueAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        op,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOr
                              ? Colors.orange[800]
                              : Colors.blueAccent[700],
                        ),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (v) => widget.onOperatorChanged(v!),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Colors.red),
                onPressed: widget.onRemoveGroup,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Remove group',
              ),
            ],
          ),

          // ── Committed conditions ───────────────────────────────────────
          if (widget.conditions.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...widget.conditions.asMap().entries.map(
              (e) => _ConditionRow(
                qualification:
                    (e.value['qualification'] as String?) ?? 'SPM',
                subject: (e.value['subject'] as String?) ?? '',
                grade: (e.value['grade'] as String?) ?? '',
                onRemove: () => widget.onRemoveCondition(e.key),
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Add condition form ─────────────────────────────────────────
          DropdownButtonFormField<String>(
            initialValue: _selectedCondQual,
            decoration: InputDecoration(
              labelText: 'Qualification',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            items: widget.condQualOptions
                .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedCondQual = v ?? 'SPM';
              _selectedConditionGrade = null;
            }),
          ),
          const SizedBox(height: 8),
          _FormField(controller: _subjectCtrl, label: 'Subject'),
          DropdownButtonFormField<String>(
            key: ValueKey('grade_${widget.groupIndex}_$_selectedCondQual'),
            initialValue: _selectedConditionGrade,
            decoration: InputDecoration(
              labelText: 'Required Grade',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            items: gradeOptions
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _selectedConditionGrade = v),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _handleAdd,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Condition',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                side: const BorderSide(color: Colors.blueAccent),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _DraftPathwayBlock — committed pathway card in the form
// =============================================================================

class _DraftPathwayBlock extends StatelessWidget {
  final int index;
  final Map<String, dynamic> pathway;
  final VoidCallback onRemove;
  final void Function(String routeKey) onRemoveRoute;

  /// Called when the admin taps the edit icon on an individual route chip.
  final void Function(String routeKey) onEditRoute;

  const _DraftPathwayBlock({
    required this.index,
    required this.pathway,
    required this.onRemove,
    required this.onRemoveRoute,
    required this.onEditRoute,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        pathway['pathwayName'] as String? ?? 'Pathway ${index + 1}';
    final routes = Map<String, dynamic>.from(
        pathway['qualificationRoutes'] as Map? ?? {});

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route, size: 16, color: Colors.blueAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Colors.red),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Remove pathway',
              ),
            ],
          ),
          if (routes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...routes.entries.map(
              (e) => _RouteChip(
                qualType: e.key,
                requirements:
                    Map<String, dynamic>.from(e.value as Map),
                onRemove: () => onRemoveRoute(e.key),
                onEdit: () => onEditRoute(e.key),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// _OrDivider — "OR" separator between pathways
// =============================================================================

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Text(
              'OR',
              style: TextStyle(
                color: Colors.orange[800],
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// =============================================================================
// Reusable private widgets
// =============================================================================

class _RouteChip extends StatelessWidget {
  final String qualType;
  final Map<String, dynamic> requirements;
  final VoidCallback onRemove;

  /// When non-null an edit icon is shown and tapping it invokes this callback.
  final VoidCallback? onEdit;

  const _RouteChip({
    required this.qualType,
    required this.requirements,
    required this.onRemove,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cgpa = requirements['minimumCgpa'];
    final minRelevant = requirements['minimumRelevantSubjects'] as int?;
    final minGrade = requirements['minimumGrade'] as String?;
    final relevantSubjects =
        (requirements['relevantSubjects'] as List?)?.cast<String>() ?? [];
    final conditionGroups =
        (requirements['conditionGroups'] as List?) ?? [];
    final conditionCount = conditionGroups.fold<int>(
      0,
      (sum, g) =>
          sum + ((g as Map)['conditions'] as List? ?? []).length,
    );

    final summaryParts = <String>[
      if (cgpa != null)
        'Min CGPA: ${(cgpa as num).toStringAsFixed(2)}',
      if (minRelevant != null)
        '≥$minRelevant relevant${minGrade != null ? ' at $minGrade' : ''}',
      if (relevantSubjects.isNotEmpty)
        relevantSubjects.length == 1
            ? relevantSubjects.first
            : '${relevantSubjects.length} subjects',
      if (conditionGroups.isNotEmpty)
        '${conditionGroups.length} '
        'group${conditionGroups.length == 1 ? '' : 's'}'
        '${conditionCount > 0 ? ', $conditionCount condition${conditionCount == 1 ? '' : 's'}' : ''}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  qualType,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blueAccent,
                  ),
                ),
                if (summaryParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    summaryParts.join(' · '),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          if (onEdit != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 15, color: Colors.blueAccent),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Edit route',
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.red),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Remove route',
          ),
        ],
      ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  final String qualType;
  final Map<String, dynamic> requirements;

  const _RequirementCard({
    required this.qualType,
    required this.requirements,
  });

  @override
  Widget build(BuildContext context) {
    final cgpa = requirements['minimumCgpa'];
    final minRelevant = requirements['minimumRelevantSubjects'] as int?;
    final minGrade = requirements['minimumGrade'] as String?;
    final relevantSubjects =
        (requirements['relevantSubjects'] as List?)?.cast<String>() ?? [];
    final conditionGroups =
        (requirements['conditionGroups'] as List?) ?? [];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            qualType,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 6),

          if (cgpa != null)
            Text(
              'Minimum CGPA: ${(cgpa as num).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13),
            ),

          if (minRelevant != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Minimum Relevant Subjects: $minRelevant',
                style: const TextStyle(fontSize: 13),
              ),
            ),

          if (minGrade != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Minimum Grade: $minGrade',
                style: const TextStyle(fontSize: 13),
              ),
            ),

          if (relevantSubjects.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Relevant Subjects:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            ...relevantSubjects.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    const Icon(Icons.circle,
                        size: 6, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(s, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],

          if (conditionGroups.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Conditions:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            ...conditionGroups.asMap().entries.expand((groupEntry) {
              final group = groupEntry.value as Map;
              final operator =
                  (group['operator'] as String?) ?? 'AND';
              final conditions =
                  (group['conditions'] as List?) ?? [];
              final isOr = operator == 'OR';
              return <Widget>[
                if (groupEntry.key > 0) const SizedBox(height: 8),
                // Group header with operator badge
                Row(
                  children: [
                    Text(
                      'Group ${groupEntry.key + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOr
                            ? Colors.orange.withValues(alpha: 0.12)
                            : Colors.blueAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isOr
                              ? Colors.orange.withValues(alpha: 0.4)
                              : Colors.blueAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        operator,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isOr
                              ? Colors.orange[800]
                              : Colors.blueAccent[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...conditions.map((c) {
                  final condition = c as Map;
                  final qual =
                      (condition['qualification'] as String?) ?? 'SPM';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '$qual \u2192 ${condition["subject"]} : ${condition["grade"]}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }),
              ];
            }),
          ],
        ],
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  final String qualification;
  final String subject;
  final String grade;
  final VoidCallback onRemove;

  const _ConditionRow({
    required this.qualification,
    required this.subject,
    required this.grade,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$qualification: $subject = $grade',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14, color: Colors.red),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Remove condition',
          ),
        ],
      ),
    );
  }
}

class _RouteBuilderSectionLabel extends StatelessWidget {
  final String text;
  const _RouteBuilderSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: Colors.blueAccent[700],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.blueAccent,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _FormField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

// =============================================================================
// TARUMT Seed Result Dialog
// =============================================================================

class _TarumtSeedResultDialog extends StatelessWidget {
  final TarumtSeedResult result;

  const _TarumtSeedResultDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        decoration: BoxDecoration(
          color: result.allSkipped ? Colors.grey[100] : Colors.teal[50],
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              result.allSkipped
                  ? Icons.info_outline
                  : Icons.check_circle_outline,
              color: result.allSkipped ? Colors.grey[600] : Colors.teal[700],
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'TARUMT Course Seed Complete',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: result.allSkipped
                      ? Colors.grey[700]
                      : Colors.teal[800],
                ),
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary row
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    _SummaryChip(
                      label: 'Created',
                      count: result.created.length,
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 12),
                    _SummaryChip(
                      label: 'Skipped',
                      count: result.skipped.length,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    _SummaryChip(
                      label: 'Total',
                      count: result.total,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),

              // Created list
              if (result.created.isNotEmpty) ...[
                _SeedSectionHeader(
                  icon: Icons.add_circle_outline,
                  label: 'Created (${result.created.length})',
                  color: Colors.teal[700]!,
                ),
                const SizedBox(height: 6),
                ...result.created.map(
                  (name) => _SeedResultRow(
                    name: name,
                    icon: Icons.check,
                    iconColor: Colors.teal[600]!,
                    textColor: Colors.teal[900]!,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Skipped list
              if (result.skipped.isNotEmpty) ...[
                _SeedSectionHeader(
                  icon: Icons.remove_circle_outline,
                  label: 'Skipped — already exists (${result.skipped.length})',
                  color: Colors.grey[600]!,
                ),
                const SizedBox(height: 6),
                ...result.skipped.map(
                  (name) => _SeedResultRow(
                    name: name,
                    icon: Icons.remove,
                    iconColor: Colors.grey[400]!,
                    textColor: Colors.grey[600]!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final MaterialColor color;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color[700],
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color[400]),
        ),
      ],
    );
  }
}

class _SeedSectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SeedSectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SeedResultRow extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color iconColor;
  final Color textColor;

  const _SeedResultRow({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 8),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          Expanded(
            child: Text(
              name,
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
