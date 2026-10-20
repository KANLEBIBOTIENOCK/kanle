import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';

const _days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const _dayFullNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  // 0 = Semaine complète classée par jour, 1 = Lun, 2 = Mar, ... 7 = Dim
  int _selectedDay = 0;

  void _confirmDeleteRoutine(BuildContext context, Routine r) {
    final s = context.read<AppState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Supprimer "${r.title}" ?',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Text(
          'Cette routine et tous ses blocs associés dans votre planning seront supprimés.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text('Supprimer'),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              final deletedBlocks = s.deleteRoutine(r.id, deletePlanningBlocks: true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    'Routine supprimée et $deletedBlocks bloc(s) retiré(s) du planning.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _edit(BuildContext context, [Routine? r]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _RoutineEditor(
          routine: r,
          onDelete: r != null ? () => _confirmDeleteRoutine(context, r) : null,
        ),
      ),
    );
  }

  void _showRoutinePacksDialog(BuildContext context) {
    final s = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.82,
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C5CE7), size: 22),
                SizedBox(width: 8),
                Text(
                  'Packs de Routines IA',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Installez en un clic un ensemble cohérent d\'habitudes adaptées à votre mode de vie.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: kBuiltinRoutinePacks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final pack = kBuiltinRoutinePacks[idx];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.18)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                pack.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C5CE7).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                pack.badge,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6C5CE7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          pack.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: pack.items.map((item) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.title} (${fmtMin(item.startMin)})',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: const Icon(Icons.download_done_rounded, size: 16),
                            label: Text('Installer ce pack (${pack.items.length} routines)'),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(ctx);
                              final installed = s.installRoutinePack(pack);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  content: Text(
                                    installed > 0
                                        ? '✨ Pack "${pack.title}" installé ($installed routines ajoutées et synchronisées) !'
                                        : 'Les routines de ce pack sont déjà présentes.',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Routines & Habitudes',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 15, color: Color(0xFF6C5CE7)),
            label: const Text(
              'Packs IA',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7)),
            ),
            onPressed: () => _showRoutinePacksDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 4,
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle routine', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Barre de filtre par jour de la semaine
          Container(
            height: 48,
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _buildDayChip(0, 'Toute la semaine (${s.routines.length})', theme),
                for (var d = 1; d <= 7; d++) ...[
                  const SizedBox(width: 6),
                  _buildDayChip(
                    d,
                    '${_days[d - 1]} (${s.routines.where((r) => r.weekdays.contains(d)).length})',
                    theme,
                  ),
                ],
              ],
            ),
          ),

          // Liste des routines
          Expanded(
            child: Builder(
              builder: (ctx) {
                final planningHabitBlocks = s.blocks
                    .where((b) => b.categoryId == 'routine' && b.routineId == null)
                    .toList();

                if (s.routines.isEmpty && planningHabitBlocks.isEmpty) {
                  return _buildEmptyState(theme, 'Aucune routine configurée');
                }

                if (s.routines.isEmpty) {
                  return _buildPlanningHabitsOnlyView(context, s, theme, planningHabitBlocks);
                }

                return _selectedDay == 0
                    ? _buildGroupedWeekView(context, s, theme)
                    : _buildSingleDayView(context, s, theme, _selectedDay);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _convertBlockToRoutine(BuildContext context, TimeBlock b, AppState s) {
    final r = Routine(
      id: s.newId(),
      title: b.title,
      colorValue: b.colorValue,
      startMin: b.startMin,
      endMin: b.endMin,
      weekdays: {1, 2, 3, 4, 5, 6, 7},
      categoryId: b.categoryId,
      reminderMin: b.reminderMin,
    );
    b.routineId = r.id;
    s.upsertRoutine(r);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ "${b.title}" enregistrée comme routine récurrente !'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF00B894),
      ),
    );
  }

  Widget _buildPlanningHabitsOnlyView(
      BuildContext context, AppState s, ThemeData theme, List<TimeBlock> habitBlocks) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE17055).withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE17055).withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFFE17055), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Habitudes créées par l\'IA dans votre planning. Vous pouvez les transformer en routines récurrentes :',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final b in habitBlocks)
          _buildHabitBlockCard(context, b, s, theme),
      ],
    );
  }

  Widget _buildHabitBlockCard(BuildContext context, TimeBlock b, AppState s, ThemeData theme) {
    final cat = getCategoryById(b.categoryId, s.categories);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: b.color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(cat.icon, color: b.color, size: 20),
        ),
        title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          '${fmtMin(b.startMin)} – ${fmtMin(b.endMin)} · Date : ${b.date}',
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.repeat_rounded, size: 16),
          label: const Text('Répéter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          onPressed: () => _convertBlockToRoutine(context, b, s),
        ),
      ),
    );
  }

  Widget _buildGroupedWeekView(BuildContext context, AppState s, ThemeData theme) {
    final daysWithRoutines = <int>[];
    for (var d = 1; d <= 7; d++) {
      if (s.routines.any((r) => r.weekdays.contains(d))) {
        daysWithRoutines.add(d);
      }
    }

    final unlinkedHabitBlocks = s.blocks
        .where((b) => b.categoryId == 'routine' && b.routineId == null)
        .toList();

    if (daysWithRoutines.isEmpty && unlinkedHabitBlocks.isEmpty) {
      return _buildEmptyState(theme, 'Aucune routine configurée');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        for (final d in daysWithRoutines) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8, left: 2),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _dayFullNames[d - 1],
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${s.routines.where((r) => r.weekdays.contains(d)).length} routine(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          for (final r in (s.routines.where((r) => r.weekdays.contains(d)).toList()
            ..sort((a, b) => a.startMin.compareTo(b.startMin))))
            _buildRoutineCard(context, r, theme, highlightDay: d),
        ],

        if (unlinkedHabitBlocks.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'Habitudes dans l\'agenda (créées par l\'IA)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          for (final b in unlinkedHabitBlocks)
            _buildHabitBlockCard(context, b, s, theme),
        ],
      ],
    );
  }

  Widget _buildSingleDayView(BuildContext context, AppState s, ThemeData theme, int day) {
    final routines = s.routines.where((r) => r.weekdays.contains(day)).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    if (routines.isEmpty) {
      return _buildEmptyState(theme, 'Aucune routine pour ${_dayFullNames[day - 1]}');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      itemCount: routines.length,
      itemBuilder: (_, i) => _buildRoutineCard(context, routines[i], theme, highlightDay: day),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.repeat_rounded,
                size: 30,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Créez une routine récurrente qui s\'appliquera automatiquement lors de la synchronisation de la semaine.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineCard(
    BuildContext context,
    Routine r,
    ThemeData theme, {
    int? highlightDay,
  }) {
    final cat = r.category;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          onTap: () => _edit(context, r),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: r.color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(cat.icon, color: r.color, size: 22),
          ),
          title: Text(
            r.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${fmtMin(r.startMin)} – ${fmtMin(r.endMin)} · ${cat.name}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: [
                  for (var d = 1; d <= 7; d++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: r.weekdays.contains(d)
                            ? (d == highlightDay
                                ? r.color.withOpacity(0.3)
                                : r.color.withOpacity(0.18))
                            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6),
                        border: d == highlightDay && r.weekdays.contains(d)
                            ? Border.all(color: r.color, width: 1)
                            : null,
                      ),
                      child: Text(
                        _days[d - 1],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: r.weekdays.contains(d)
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: r.weekdays.contains(d)
                              ? r.color
                              : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
            onPressed: () => _confirmDeleteRoutine(context, r),
          ),
        ),
      ),
    );
  }

  Widget _buildDayChip(int dayIndex, String label, ThemeData theme) {
    final sel = _selectedDay == dayIndex;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
          color: sel ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
      selected: sel,
      selectedColor: theme.colorScheme.primary,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (v) {
        if (v) {
          HapticFeedback.selectionClick();
          setState(() => _selectedDay = dayIndex);
        }
      },
    );
  }
}

class _RoutineEditor extends StatefulWidget {
  final Routine? routine;
  final VoidCallback? onDelete;
  const _RoutineEditor({this.routine, this.onDelete});

  @override
  State<_RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<_RoutineEditor> {
  late final TextEditingController _title;
  late int _start, _end, _color;
  late Set<int> _wd;
  late int _reminder;
  late String _categoryId;

  @override
  void initState() {
    super.initState();
    final r = widget.routine;
    _categoryId = r?.categoryId ?? 'routine';
    _title = TextEditingController(text: r?.title ?? '');
    _start = r?.startMin ?? 8 * 60;
    _end = r?.endMin ?? 9 * 60;
    _color = r?.colorValue ?? getCategoryById(_categoryId).defaultColor.toARGB32();
    _wd = r != null ? Set<int>.from(r.weekdays) : {1, 2, 3, 4, 5};
    final defaultRem = context.read<AppState>().defaultReminder;
    _reminder = r?.reminderMin ?? defaultRem;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isStart) async {
    final cur = isStart ? _start : _end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (cur ~/ 60) % 24, minute: cur % 60),
    );
    if (t == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      final m = t.hour * 60 + t.minute;
      if (isStart) {
        _start = m;
        if (_end <= _start) _end = (_start + 30).clamp(0, 24 * 60);
      } else {
        _end = m <= _start ? 24 * 60 : m;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(_color).withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  getCategoryById(_categoryId).icon,
                  color: Color(_color),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.routine == null ? 'Nouvelle routine' : 'Modifier la routine',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Catégories
          Text(
            'Catégorie',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = kCategories[i];
                final sel = cat.id == _categoryId;
                return ChoiceChip(
                  avatar: Icon(
                    cat.icon,
                    size: 16,
                    color: sel ? Colors.white : cat.defaultColor,
                  ),
                  label: Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                  selected: sel,
                  selectedColor: cat.defaultColor,
                  showCheckmark: false,
                  onSelected: (v) {
                    if (v) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _categoryId = cat.id;
                        _color = cat.defaultColor.toARGB32();
                      });
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Titre
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: 'Titre de la routine',
              prefixIcon: const Icon(Icons.edit_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),

          // Horaires
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _pick(true),
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text('Début ${fmtMin(_start)}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _pick(false),
                  icon: const Icon(Icons.schedule_send, size: 18),
                  label: Text('Fin ${fmtMin(_end)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Jours de la semaine
          Text(
            'Jours de répétition',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(_days[d - 1]),
                  selected: _wd.contains(d),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => v ? _wd.add(d) : _wd.remove(d));
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Rappel
          DropdownButtonFormField<int>(
            initialValue: _reminder,
            decoration: InputDecoration(
              labelText: 'Rappel par défaut',
              prefixIcon: const Icon(Icons.notifications_active_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: const [
              DropdownMenuItem(value: -1, child: Text('Aucun')),
              DropdownMenuItem(value: 0, child: Text('À l\'heure du début')),
              DropdownMenuItem(value: 5, child: Text('5 min avant')),
              DropdownMenuItem(value: 10, child: Text('10 min avant')),
              DropdownMenuItem(value: 15, child: Text('15 min avant')),
              DropdownMenuItem(value: 30, child: Text('30 min avant')),
            ],
            onChanged: (v) => setState(() => _reminder = v ?? 0),
          ),
          const SizedBox(height: 14),

          // Palette de couleurs
          Text(
            'Couleur',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final c in kPalette)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _color = c.toARGB32());
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: _color == c.toARGB32()
                          ? Border.all(color: Colors.white, width: 2.5)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: c.withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _color == c.toARGB32()
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Boutons d'action
          Row(
            children: [
              if (widget.routine != null && widget.onDelete != null)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete!();
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Supprimer'),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                onPressed: () {
                  if (_title.text.trim().isEmpty || _wd.isEmpty) return;
                  HapticFeedback.lightImpact();
                  final s = context.read<AppState>();
                  s.upsertRoutine(
                    Routine(
                      id: widget.routine?.id ?? s.newId(),
                      title: _title.text.trim(),
                      colorValue: _color,
                      startMin: _start,
                      endMin: _end,
                      weekdays: _wd,
                      reminderMin: _reminder,
                      categoryId: _categoryId,
                    ),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
