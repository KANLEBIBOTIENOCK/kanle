import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import 'ai_assistant_screen.dart';
import 'block_editor.dart';

const double kHourHeight = 68;
const double kGutter = 54;

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  void _showConflictResolver(BuildContext context, DateTime date) {
    final s = context.read<AppState>();
    final conflicts = s.getConflictingBlockIds(date);
    if (conflicts.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final curConflicts = s.getConflictingBlockIds(date);
          final dayBlocks = s.blocksFor(date);

          final pairs = <(TimeBlock, TimeBlock)>[];
          for (var i = 0; i < dayBlocks.length; i++) {
            for (var j = i + 1; j < dayBlocks.length; j++) {
              final a = dayBlocks[i];
              final b = dayBlocks[j];
              if (a.startMin < b.endMin && a.endMin > b.startMin) {
                pairs.add((a, b));
              }
            }
          }

          if (curConflicts.isEmpty || pairs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF00B894), size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Tous les conflits sont résolus !',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            );
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          '${curConflicts.length} bloc(s) en conflit',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        s.resolveAllConflicts(date);
                        setModalState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('Tous les créneaux ont été décalés en ordre sans conflit !'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text('Tout décaler', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pairs.length,
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (ctx, idx) {
                      final (a, b) = pairs[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: a.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${a.title} (${fmtMin(a.startMin)} – ${fmtMin(a.endMin)})',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: b.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${b.title} (${fmtMin(b.startMin)} – ${fmtMin(b.endMin)})',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    s.resolveConflictShiftAfter(b.id, a.id);
                                    setModalState(() {});
                                  },
                                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                                  label: Text('Décaler "${b.title}" après ${fmtMin(a.endMin)}'),
                                ),
                                if (b.startMin > a.startMin)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      s.resolveConflictAdjustDuration(a.id, b.id);
                                      setModalState(() {});
                                    },
                                    icon: const Icon(Icons.content_cut_rounded, size: 14),
                                    label: Text('Ajuster fin de "${a.title}" à ${fmtMin(b.startMin)}'),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  tooltip: 'Supprimer ce bloc',
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    s.deleteBlock(b.id);
                                    setModalState(() {});
                                  },
                                ),
                              ],
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
    final date = s.selectedDate;
    final blocks = s.blocksFor(date);
    final planned = blocks.fold<int>(0, (a, b) => a + b.duration);
    final done = blocks.where((b) => b.done).fold<int>(0, (a, b) => a + b.duration);
    final isToday = dateKey(date) == dateKey(DateTime.now());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final conflictIds = s.getConflictingBlockIds(date);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            // Logo avec lueur mystique
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.3) : const Color(0xFF6C5CE7).withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFF6C5CE7).withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Titre flexible évitant les dépassements de pixels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Kanlé',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Timebloc',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat('EEEE d MMMM', 'fr_FR').format(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Aujourd\'hui',
            icon: const Icon(Icons.today_rounded),
            onPressed: () {
              HapticFeedback.selectionClick();
              s.selectDate(DateTime.now());
            },
          ),
          IconButton(
            tooltip: 'Synchroniser les routines',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () {
              HapticFeedback.mediumImpact();
              final n = s.applyWeek(date);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  content: Text(n > 0
                      ? '$n bloc(s) de routine synchronisé(s)'
                      : 'Planning à jour (aucun doublon)'),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _DateStrip(selected: date, onSelect: s.selectDate),
          _TasksDaySection(date: date),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${blocks.length} blocs · ${(planned / 60).toStringAsFixed(1)}h planifiées',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (conflictIds.isNotEmpty)
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => _showConflictResolver(context, date),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.shade700, width: 1.2),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber.shade800),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${conflictIds.length} en conflit · Régler',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (planned > 0)
                            Text(
                              '${((done / planned) * 100).toInt()}% accompli',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: planned > 0 ? (done / planned) : 0,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _Timeline(
              blocks: blocks,
              showNow: isToday,
              conflictIds: conflictIds,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  final DateTime selected;
  final void Function(DateTime) onSelect;
  const _DateStrip({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final start = selected.subtract(Duration(days: selected.weekday - 1));

    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              HapticFeedback.selectionClick();
              onSelect(selected.subtract(const Duration(days: 7)));
            },
          ),
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(
                builder: (_) {
                  final d = start.add(Duration(days: i));
                  final sel = dateKey(d) == dateKey(selected);
                  final isToday = dateKey(d) == dateKey(DateTime.now());

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(d);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel
                            ? cs.primary
                            : isToday
                                ? cs.primary.withOpacity(0.12)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: isToday && !sel
                            ? Border.all(color: cs.primary.withOpacity(0.5), width: 1.5)
                            : null,
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: cs.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('E', 'fr_FR').format(d).substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: sel ? cs.onPrimary : cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: sel ? cs.onPrimary : cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () {
              HapticFeedback.selectionClick();
              onSelect(selected.add(const Duration(days: 7)));
            },
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatefulWidget {
  final List<TimeBlock> blocks;
  final bool showNow;
  final Set<String> conflictIds;
  const _Timeline({
    required this.blocks,
    required this.showNow,
    required this.conflictIds,
  });

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  final _ctrl = ScrollController();
  double _hourHeight = 68.0;
  Timer? _ticker;
  DateTime _currentTime = DateTime.now();

  // Variables de gestion du pincement (pinch-to-zoom)
  final Map<int, Offset> _pointers = {};
  double _pinchBaseDistance = 0.0;
  double _pinchBaseHourHeight = 68.0;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    if (widget.showNow) {
      _startTicker();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      double target = 0.0;
      if (widget.showNow) {
        final nowMin = _currentTime.hour * 60.0 + _currentTime.minute;
        target = ((nowMin / 60.0) * _hourHeight - 80).clamp(0.0, 24 * _hourHeight);
      } else if (widget.blocks.isNotEmpty) {
        final minStart = widget.blocks.map((b) => b.startMin).reduce((a, b) => a < b ? a : b);
        target = ((minStart / 60.0) * _hourHeight - 40).clamp(0.0, 24 * _hourHeight);
      } else {
        target = (7.0 * _hourHeight).clamp(0.0, 24 * _hourHeight);
      }
      if (_ctrl.hasClients) {
        _ctrl.jumpTo(target);
      }
    });
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _Timeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showNow && _ticker == null) {
      _currentTime = DateTime.now();
      _startTicker();
    } else if (!widget.showNow && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Map<String, (int, int)> _computeColumns(List<TimeBlock> blocks) {
    final layout = <String, (int, int)>{};
    if (blocks.isEmpty) return layout;

    // Durée visuelle minimale en minutes pour garantir la séparation et lisibilité sans chevauchement
    final minVisualMinutes = ((24.0 / _hourHeight) * 60).ceil().clamp(10, 45);

    final sorted = List<TimeBlock>.from(blocks)
      ..sort((a, b) {
        final c = a.startMin.compareTo(b.startMin);
        return c != 0 ? c : b.duration.compareTo(a.duration);
      });

    var cluster = <TimeBlock>[];
    var clusterVisualEnd = -1;

    void processCluster(List<TimeBlock> cl) {
      if (cl.isEmpty) return;
      if (cl.length == 1) {
        layout[cl[0].id] = (0, 1);
        return;
      }
      final colEnds = <int>[];
      final colAssignments = <String, int>{};

      for (final b in cl) {
        final bVisualEnd = math.max(b.endMin, b.startMin + minVisualMinutes);
        var assigned = -1;
        for (var i = 0; i < colEnds.length; i++) {
          if (b.startMin >= colEnds[i]) {
            assigned = i;
            colEnds[i] = bVisualEnd;
            break;
          }
        }
        if (assigned == -1) {
          assigned = colEnds.length;
          colEnds.add(bVisualEnd);
        }
        colAssignments[b.id] = assigned;
      }

      final totalCols = colEnds.length;
      for (final b in cl) {
        layout[b.id] = (colAssignments[b.id] ?? 0, totalCols);
      }
    }

    for (final b in sorted) {
      final bVisualEnd = math.max(b.endMin, b.startMin + minVisualMinutes);
      if (cluster.isEmpty) {
        cluster.add(b);
        clusterVisualEnd = bVisualEnd;
      } else if (b.startMin < clusterVisualEnd) {
        cluster.add(b);
        if (bVisualEnd > clusterVisualEnd) clusterVisualEnd = bVisualEnd;
      } else {
        processCluster(cluster);
        cluster = [b];
        clusterVisualEnd = bVisualEnd;
      }
    }
    processCluster(cluster);
    return layout;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Listener(
      onPointerDown: (event) {
        _pointers[event.pointer] = event.position;
        if (_pointers.length == 2) {
          final pts = _pointers.values.toList();
          _pinchBaseDistance = (pts[0] - pts[1]).distance;
          _pinchBaseHourHeight = _hourHeight;
        }
      },
      onPointerMove: (event) {
        _pointers[event.pointer] = event.position;
        if (_pointers.length >= 2 && _pinchBaseDistance > 15) {
          final pts = _pointers.values.toList();
          final currentDist = (pts[0] - pts[1]).distance;
          final scale = currentDist / _pinchBaseDistance;
          final newH = (_pinchBaseHourHeight * scale).clamp(38.0, 140.0);
          if ((newH - _hourHeight).abs() > 0.8) {
            setState(() => _hourHeight = newH);
          }
        }
      },
      onPointerUp: (event) {
        _pointers.remove(event.pointer);
        if (_pointers.length < 2) _pinchBaseDistance = 0.0;
      },
      onPointerCancel: (event) {
        _pointers.remove(event.pointer);
        if (_pointers.length < 2) _pinchBaseDistance = 0.0;
      },
      child: SingleChildScrollView(
          controller: _ctrl,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 110),
          child: SizedBox(
            height: 24 * _hourHeight,
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth - kGutter - 14;
                final layout = _computeColumns(widget.blocks);

                  return Stack(
                    children: [
                      // Grille horaire
                      for (var h = 0; h < 24; h++)
                        Positioned(
                          top: h * _hourHeight,
                          left: 0,
                          right: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => showBlockEditor(context, startMin: h * 60),
                            child: SizedBox(
                              height: _hourHeight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: kGutter,
                                    child: Text(
                                      '${h.toString().padLeft(2, '0')}:00',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurfaceVariant.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      height: 1,
                                      color: cs.outlineVariant.withOpacity(0.25),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Blocs de temps
                      for (final b in widget.blocks)
                        () {
                          final colInfo = layout[b.id] ?? (0, 1);
                          final colIndex = colInfo.$1;
                          final totalCols = colInfo.$2;
                          final colWidth = w / totalCols;
                          final leftOffset = kGutter + colIndex * colWidth;
                          final blockWidth = colWidth - (totalCols > 1 ? 3 : 0);

                          final rawHeight = (b.duration / 60.0) * _hourHeight;
                          final cardHeight = (rawHeight - 2.0).clamp(22.0, 24.0 * _hourHeight);

                          return Positioned(
                            top: b.startMin / 60 * _hourHeight + 1,
                            left: leftOffset,
                            width: blockWidth,
                            height: cardHeight,
                            child: _BlockCard(
                              block: b,
                              isConflict: widget.conflictIds.contains(b.id),
                            ),
                          );
                        }(),

                      // Ligne du temps présent haute précision
                      if (widget.showNow)
                        () {
                          final exactMinutes = _currentTime.hour * 60.0 +
                              _currentTime.minute +
                              (_currentTime.second / 60.0);
                          final lineY = (exactMinutes / 60.0) * _hourHeight;

                          return Positioned(
                            top: lineY - 9.0,
                            left: 2,
                            right: 0,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.redAccent.withOpacity(0.35),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    DateFormat('HH:mm').format(_currentTime),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.redAccent.withOpacity(0.6),
                                        blurRadius: 5,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.redAccent,
                                          Colors.redAccent.withOpacity(0.2),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }(),
                    ],
                  );
                },
              ),
            ),
          ),

    );
  }
}

class _BlockCard extends StatelessWidget {
  final TimeBlock block;
  final bool isConflict;
  const _BlockCard({required this.block, this.isConflict = false});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final cat = block.category;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;
        final isShort = cardHeight < 44;
        final isTiny = cardHeight < 28;

        return ClipRRect(
          borderRadius: BorderRadius.circular(isTiny ? 5 : (isShort ? 7 : 10)),
          child: Container(
            decoration: BoxDecoration(
              color: block.color.withOpacity(block.done ? 0.40 : 0.92),
              borderRadius: BorderRadius.circular(isTiny ? 5 : (isShort ? 7 : 10)),
              border: isConflict
                  ? Border.all(color: Colors.amberAccent, width: 2)
                  : null,
              boxShadow: block.done || isShort
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(isTiny ? 5 : (isShort ? 7 : 10)),
                onTap: () => showBlockEditor(context, block: block),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTiny ? 4 : (isShort ? 6 : 8),
                    vertical: 1,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icône de catégorie
                      if (isTiny)
                        Icon(cat.icon, size: 11, color: Colors.white)
                      else if (isShort)
                        Icon(cat.icon, size: 13, color: Colors.white)
                      else
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(cat.icon, size: 13, color: Colors.white),
                        ),
                      SizedBox(width: isTiny ? 3 : (isShort ? 5 : 7)),

                      // Titre et détails
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    block.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isTiny ? 10.0 : (isShort ? 11.5 : 12.5),
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                      decoration: block.done ? TextDecoration.lineThrough : null,
                                      decorationColor: Colors.white70,
                                      decorationThickness: 2,
                                    ),
                                  ),
                                ),
                                if (isConflict)
                                  Container(
                                    margin: const EdgeInsets.only(left: 3),
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade700,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text(
                                      '!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.0,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (!isShort && cardHeight >= 50 && block.duration >= 45)
                              Text(
                                '${fmtMin(block.startMin)} – ${fmtMin(block.endMin)} · ${cat.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9.5,
                                  height: 1.1,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Checkbox personnalisée anti-overflow
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          s.toggleDone(block);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Container(
                            width: isTiny ? 14 : (isShort ? 17 : 22),
                            height: isTiny ? 14 : (isShort ? 17 : 22),
                            decoration: BoxDecoration(
                              color: block.done ? Colors.white.withOpacity(0.9) : Colors.transparent,
                              borderRadius: BorderRadius.circular(isTiny ? 3 : 4),
                              border: Border.all(
                                color: Colors.white,
                                width: isTiny ? 1.2 : 1.6,
                              ),
                            ),
                            child: block.done
                                ? Icon(
                                    Icons.check_rounded,
                                    size: isTiny ? 10 : (isShort ? 13 : 17),
                                    color: block.color,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TasksDaySection extends StatefulWidget {
  final DateTime date;
  const _TasksDaySection({required this.date});

  @override
  State<_TasksDaySection> createState() => _TasksDaySectionState();
}

class _TasksDaySectionState extends State<_TasksDaySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final dayTasks = s.tasksFor(widget.date);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doneCount = dayTasks.where((t) => t.isDoneForDate(widget.date)).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dayTasks.isNotEmpty
              ? const Color(0xFF6C5CE7).withOpacity(0.25)
              : Colors.grey.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête rétractable
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      size: 15,
                      color: Color(0xFF6C5CE7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Tâches du jour',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (dayTasks.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: doneCount == dayTasks.length
                            ? Colors.green.withOpacity(0.15)
                            : const Color(0xFF6C5CE7).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$doneCount/${dayTasks.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: doneCount == dayTasks.length
                              ? Colors.green
                              : const Color(0xFF6C5CE7),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00CEC9).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 10, color: Color(0xFF00CEC9)),
                        SizedBox(width: 3),
                        Text(
                          'IA',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00CEC9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // Contenu de la liste des tâches
          if (_expanded) ...[
            const Divider(height: 1, indent: 12, endIndent: 12),
            if (dayTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Aucune tâche pour ce jour. Demandez à votre Assistant IA d\'en ajouter une !',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF6C5CE7)),
                      label: const Text('Assistant', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: dayTasks.map((t) {
                    final isDone = t.isDoneForDate(widget.date);
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        s.toggleTaskDone(t.id, widget.date);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone ? const Color(0xFF00B894) : Colors.transparent,
                                border: Border.all(
                                  color: isDone ? const Color(0xFF00B894) : Colors.grey.shade400,
                                  width: 1.8,
                                ),
                              ),
                              child: isDone
                                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                      color: isDone
                                          ? Colors.grey
                                          : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                  if (t.isRecurring)
                                    Text(
                                      t.recurrenceLabel,
                                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                                    ),
                                ],
                              ),
                            ),
                            if (t.timeMin != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  fmtMin(t.timeMin!),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            if (t.isDaily)
                              const Icon(Icons.repeat_rounded, size: 14, color: Color(0xFF6C5CE7)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

