import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';

/// Édition/création d'un bloc de temps.
Future<void> showBlockEditor(
  BuildContext context, {
  TimeBlock? block,
  int? startMin,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _BlockEditor(block: block, startMin: startMin),
    ),
  );
}

class _BlockEditor extends StatefulWidget {
  final TimeBlock? block;
  final int? startMin;
  const _BlockEditor({this.block, this.startMin});

  @override
  State<_BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<_BlockEditor> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late int _start;
  late int _end;
  late int _color;
  late int _reminder;
  late String _categoryId;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    final b = widget.block;
    _categoryId = b?.categoryId ?? 'work';
    _title = TextEditingController(text: b?.title ?? '');
    _note = TextEditingController(text: b?.note ?? '');
    _start = b?.startMin ?? widget.startMin ?? 9 * 60;
    _end = b?.endMin ?? (_start + 60).clamp(0, 24 * 60);
    final defaultRem = context.read<AppState>().defaultReminder;
    _reminder = b?.reminderMin ?? defaultRem;
    _color = b?.colorValue ?? getCategoryById(_categoryId).defaultColor.toARGB32();
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
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
        final dur = (_end > _start) ? (_end - _start) : 60;
        _start = m;
        _end = (_start + dur).clamp(0, 24 * 60);
      } else {
        _end = m <= _start ? (_start + 15).clamp(0, 24 * 60) : m;
      }
    });
  }

  void _applyDuration(int minutes) {
    HapticFeedback.selectionClick();
    setState(() {
      _end = (_start + minutes).clamp(0, 24 * 60);
    });
  }

  void _save() {
    final titleText = _title.text.trim();
    if (titleText.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _titleError = 'Veuillez saisir un titre pour le bloc';
      });
      return;
    }
    HapticFeedback.lightImpact();
    final s = context.read<AppState>();
    s.upsertBlock(
      TimeBlock(
        id: widget.block?.id ?? s.newId(),
        notifId: widget.block?.notifId,
        title: titleText,
        note: _note.text.trim(),
        colorValue: _color,
        startMin: _start,
        endMin: _end,
        date: widget.block?.date ?? dateKey(s.selectedDate),
        done: widget.block?.done ?? false,
        routineId: widget.block?.routineId,
        reminderMin: _reminder,
        categoryId: _categoryId,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.watch<AppState>();
    final targetDate = widget.block?.date ?? dateKey(s.selectedDate);
    final conflicts = s.findConflicts(
      targetDate,
      _start,
      _end,
      ignoreBlockId: widget.block?.id,
    );

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
                widget.block == null ? 'Nouveau bloc' : 'Modifier le bloc',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Choix de la catégorie
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
            autofocus: widget.block == null,
            onChanged: (val) {
              if (_titleError != null) {
                setState(() => _titleError = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Titre de l\'activité',
              hintText: 'ex: Prière du matin, Réunion projet...',
              errorText: _titleError,
              prefixIcon: const Icon(Icons.edit_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),

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
          const SizedBox(height: 10),

          // Raccourcis de durée rapide
          Row(
            children: [
              Text(
                'Durée :',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in [
                        (15, '15m'),
                        (30, '30m'),
                        (45, '45m'),
                        (60, '1h'),
                        (90, '1h30'),
                        (120, '2h'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _applyDuration(entry.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: (_end - _start == entry.$1)
                                    ? theme.colorScheme.primary.withOpacity(0.18)
                                    : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: (_end - _start == entry.$1)
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                entry.$2,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: (_end - _start == entry.$1)
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: (_end - _start == entry.$1)
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Alerte de conflit d'horaire en temps réel
          if (conflicts.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.amber.shade700.withOpacity(0.6),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade800),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Chevauchement avec : "${conflicts.first.title}" (${fmtMin(conflicts.first.startMin)} – ${fmtMin(conflicts.first.endMin)})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.amber.shade900,
                      side: BorderSide(color: Colors.amber.shade700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      final dur = (_end - _start).clamp(15, 24 * 60);
                      final newStart = conflicts.first.endMin;
                      setState(() {
                        _start = newStart;
                        _end = (newStart + dur).clamp(0, 24 * 60);
                      });
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                    label: Text('Décaler après (${fmtMin(conflicts.first.endMin)})'),
                  ),
                ],
              ),
            ),
          ],

          // Rappel
          DropdownButtonFormField<int>(
            initialValue: _reminder,
            decoration: InputDecoration(
              labelText: 'Rappel',
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
              DropdownMenuItem(value: 60, child: Text('1 h avant')),
            ],
            onChanged: (v) => setState(() => _reminder = v ?? 10),
          ),
          const SizedBox(height: 12),

          // Notes
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notes ou sous-objectifs (optionnel)',
              prefixIcon: const Icon(Icons.notes_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),

          // Palette de couleurs
          Text(
            'Couleur du bloc',
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

          // Actions
          Row(
            children: [
              if (widget.block != null)
                TextButton.icon(
                  onPressed: () {
                    context.read<AppState>().deleteBlock(widget.block!.id);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Supprimer'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                onPressed: _save,
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
