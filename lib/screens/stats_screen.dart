import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _days = 7;

  void _showAddCategoryDialog(BuildContext context, VoidCallback onAdded) {
    final textController = TextEditingController();
    Color selectedColor = kPalette[1]; // Indigo
    IconData selectedIcon = Icons.category_rounded;

    final availableIcons = kAvailableCategoryIcons;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6C5CE7)),
                SizedBox(width: 8),
                Text('Nouvelle Catégorie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Nom de la catégorie',
                      hintText: 'Ex: Musique, Lecture, Projet...',
                      prefixIcon: Icon(selectedIcon, color: selectedColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Couleur :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kPalette.map((col) {
                      final isSelected = col.value == selectedColor.value;
                      return GestureDetector(
                        onTap: () => setDlgState(() => selectedColor = col),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black87 : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: col.withOpacity(0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Icône :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: GridView.builder(
                      itemCount: availableIcons.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (_, i) {
                        final ic = availableIcons[i];
                        final isSel = ic == selectedIcon;
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setDlgState(() => selectedIcon = ic),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSel ? selectedColor.withOpacity(0.18) : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSel ? selectedColor : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(ic, size: 20, color: isSel ? selectedColor : Colors.grey.shade700),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                ),
                onPressed: () {
                  final name = textController.text.trim();
                  if (name.isEmpty) return;
                  final s = context.read<AppState>();
                  final id = 'cat_${DateTime.now().millisecondsSinceEpoch}';
                  final newCat = CategoryInfo(
                    id: id,
                    name: name,
                    icon: selectedIcon,
                    defaultColor: selectedColor,
                    isCustom: true,
                  );
                  s.addCategory(newCat);
                  Navigator.pop(dlgCtx);
                  onAdded();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Catégorie "$name" créée avec succès !'),
                    ),
                  );
                },
                child: const Text('Créer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCategoryManager(BuildContext context) {
    HapticFeedback.selectionClick();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final s = context.watch<AppState>();
          final categories = s.categories;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.8,
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.category_rounded, color: Color(0xFF6C5CE7), size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Gestion des Catégories',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Ajouter une catégorie', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    _showAddCategoryDialog(context, () => setSheetState(() {}));
                  },
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final cat = categories[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF28283C) : const Color(0xFFF7F8FC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: cat.defaultColor.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(cat.icon, size: 18, color: cat.defaultColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    cat.isCustom ? 'Personnalisée' : 'Par défaut',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cat.isCustom ? const Color(0xFF6C5CE7) : Colors.grey,
                                      fontWeight: cat.isCustom ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (cat.isCustom)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  showDialog(
                                    context: ctx,
                                    builder: (delCtx) => AlertDialog(
                                      title: const Text('Supprimer la catégorie ?'),
                                      content: Text(
                                        'Voulez-vous supprimer "${cat.name}" ? Les créneaux associés seront automatiquement réassignés.',
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(delCtx), child: const Text('Annuler')),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(delCtx);
                                            s.deleteCategory(cat.id);
                                            setSheetState(() {});
                                          },
                                          child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final theme = Theme.of(context);
    final now = DateTime.now();
    final daily = s.dailyStats(now, days: _days);
    final byCat = s.minutesByCategory(now, days: _days).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalPlannedMinutes = daily.fold<int>(0, (a, e) => a + e.$2);
    final totalDoneMinutes = daily.fold<int>(0, (a, e) => a + e.$3);
    final completionRate = totalPlannedMinutes > 0
        ? ((totalDoneMinutes / totalPlannedMinutes) * 100).toInt()
        : 0;

    final maxH = daily
        .map((e) => e.$2 / 60)
        .fold<double>(1, (a, b) => b > a ? b : a);

    final periodLabel = _days == 1
        ? 'Aujourd\'hui'
        : _days == 7
            ? 'Cette semaine'
            : '30 jours';

    final activeRoutinesCount = s.routines.length;
    final activeTasksCount = s.tasks.length;
    final doneTasksCount = s.tasks.where((t) => t.isDoneForDate(now)).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Statistiques & Suivi',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'Gérer les catégories',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showCategoryManager(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          // Sélecteur de période
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                for (final opt in [
                  (1, 'Aujourd\'hui'),
                  (7, 'Cette semaine'),
                  (30, '30 jours'),
                ])
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_days != opt.$1) {
                          HapticFeedback.selectionClick();
                          setState(() => _days = opt.$1);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _days == opt.$1
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _days == opt.$1
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          opt.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _days == opt.$1 ? FontWeight.w800 : FontWeight.w500,
                            color: _days == opt.$1
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Cartes KPI
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: 'Planifié ($periodLabel)',
                  value: '${(totalPlannedMinutes / 60).toStringAsFixed(1)} h',
                  icon: Icons.calendar_today_rounded,
                  color: const Color(0xFF6C5CE7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiCard(
                  title: 'Accompli',
                  value: '${(totalDoneMinutes / 60).toStringAsFixed(1)} h',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF00B894),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiCard(
                  title: 'Succès',
                  value: '$completionRate%',
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFFE2B93B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Mini bandeau Tâches IA & Routines
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.repeat_rounded, size: 18, color: Color(0xFFE17055)),
                const SizedBox(width: 6),
                Text(
                  'Routines : $activeRoutinesCount',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const Spacer(),
                Container(width: 1, height: 16, color: Colors.grey.withOpacity(0.2)),
                const Spacer(),
                const Icon(Icons.task_alt_rounded, size: 18, color: Color(0xFF00B894)),
                const SizedBox(width: 6),
                Text(
                  'Tâches : $doneTasksCount/$activeTasksCount faites',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Graphique
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Activité ($periodLabel)',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Row(
                      children: [
                        _LegendDot(
                          color: theme.colorScheme.primary.withOpacity(0.35),
                          label: 'Prévu',
                        ),
                        const SizedBox(width: 10),
                        const _LegendDot(color: Color(0xFF00B894), label: 'Fait'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      maxY: maxH + 0.8,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(),
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= daily.length) {
                                return const SizedBox.shrink();
                              }
                              // Éviter la surcharge textuelle si 30 jours
                              if (_days == 30 && idx % 5 != 0 && idx != daily.length - 1) {
                                return const SizedBox.shrink();
                              }
                              final d = daily[idx].$1;
                              final rawDay = DateFormat('E', 'fr_FR').format(d).replaceAll('.', '').trim();
                              final txt = _days == 1
                                  ? 'Aujourd\'hui'
                                  : _days == 30
                                      ? '${d.day}/${d.month}'
                                      : (rawDay.isNotEmpty
                                          ? rawDay[0].toUpperCase() + (rawDay.length > 2 ? rawDay.substring(1, 3) : rawDay.substring(1))
                                          : '');
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  txt,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < daily.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: daily[i].$2 / 60,
                                width: _days == 30 ? 4 : (_days == 1 ? 24 : 9),
                                color: theme.colorScheme.primary.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              BarChartRodData(
                                toY: daily[i].$3 / 60,
                                width: _days == 30 ? 4 : (_days == 1 ? 24 : 9),
                                color: const Color(0xFF00B894),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Répartition par Catégorie
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
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
                        'Répartition par catégorie ($periodLabel)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 15, color: Color(0xFF6C5CE7)),
                      label: const Text(
                        'Gérer',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7)),
                      ),
                      onPressed: () => _showCategoryManager(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (byCat.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Aucune activité enregistrée sur cette période.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  for (final item in byCat)
                    Builder(
                      builder: (_) {
                        final cat = getCategoryById(item.key, s.categories);
                        final pct = totalPlannedMinutes > 0
                            ? (item.value / totalPlannedMinutes).clamp(0.0, 1.0)
                            : 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: cat.defaultColor.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(cat.icon, size: 15, color: cat.defaultColor),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      cat.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(item.value / 60).toStringAsFixed(1)} h (${(pct * 100).toInt()}%)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  minHeight: 7,
                                  value: pct,
                                  color: cat.defaultColor,
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
