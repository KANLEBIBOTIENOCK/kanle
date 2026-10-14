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
            ? '7 jours'
            : '30 jours';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Statistiques & Suivi',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
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
                  (7, '7 jours'),
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
                              final txt = _days == 1
                                  ? 'Aujourd\'hui'
                                  : _days == 30
                                      ? '${d.day}/${d.month}'
                                      : DateFormat('E', 'fr_FR').format(d).substring(0, 2);
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
                Text(
                  'Répartition par catégorie ($periodLabel)',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
                        final cat = getCategoryById(item.key);
                        final pct = totalPlannedMinutes > 0
                            ? (item.value / totalPlannedMinutes)
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
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
