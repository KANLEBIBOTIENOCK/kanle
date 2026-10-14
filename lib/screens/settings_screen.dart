import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _exportBackup(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final s = context.read<AppState>();
    final content = s.exportToText();
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'kanle_sauvegarde_$dateStr.txt';

    String? savedPath;
    try {
      final candidates = [
        Directory('/storage/emulated/0/Download'),
        Directory('/sdcard/Download'),
      ];
      for (final dir in candidates) {
        if (await dir.exists()) {
          final file = File('${dir.path}/$fileName');
          await file.writeAsString(content);
          savedPath = file.path;
          break;
        }
      }
    } catch (e) {
      debugPrint('Export file write error: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.save_alt_rounded, color: Color(0xFF00B894)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sauvegarde (.txt)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (savedPath != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00B894).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF00B894), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Fichier enregistré dans :\n$savedPath',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Contenu : ${s.routines.length} routine(s) et ${s.blocks.length} créneau(x) inclus.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              Container(
                height: 160,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    content,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copier le texte'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: content));
              HapticFeedback.selectionClick();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('Texte copié dans le presse-papier !'),
                  ),
                );
              }
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _importBackup(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final s = context.read<AppState>();

    // Chercher s'il existe des fichiers de sauvegarde récents
    File? latestBackupFile;
    try {
      final candidates = [
        Directory('/storage/emulated/0/Download'),
        Directory('/sdcard/Download'),
      ];
      for (final dir in candidates) {
        if (await dir.exists()) {
          final files = dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.contains('kanle_sauvegarde_') && f.path.endsWith('.txt'))
              .toList()
            ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          if (files.isNotEmpty) {
            latestBackupFile = files.first;
            break;
          }
        }
      }
    } catch (_) {}

    final textCtrl = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.file_download_rounded, color: Color(0xFF6C5CE7)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Importer sauvegarde',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (latestBackupFile != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF6C5CE7).withOpacity(0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.history_rounded, size: 16, color: Color(0xFF6C5CE7)),
                            SizedBox(width: 6),
                            Text(
                              'Dernier fichier détecté :',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          latestBackupFile.path.split('/').last,
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Restaurer ce fichier'),
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            try {
                              final text = await latestBackupFile!.readAsString();
                              final (routines, blocks) = await s.importFromText(text);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    content: Text('Restauration réussie : $routines routine(s) et $blocks bloc(s) importés !'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    content: Text('Erreur lors de la lecture du fichier de sauvegarde.'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Ou coller le texte de sauvegarde :',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ] else ...[
                  const Text(
                    'Collez le texte du fichier de sauvegarde ci-dessous :',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: textCtrl,
                  maxLines: 5,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'Collez le contenu du fichier .txt ou JSON ici...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.paste_rounded, size: 16),
                    label: const Text('Coller du presse-papier'),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        textCtrl.text = data!.text!;
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final text = textCtrl.text.trim();
              if (text.isEmpty) return;
              HapticFeedback.mediumImpact();
              try {
                final (routines, blocks) = await s.importFromText(text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Importation réussie : $routines routine(s) et $blocks bloc(s) importés !'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Format de sauvegarde invalide ou corrompu.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Importer'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    final s = context.read<AppState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Tout réinitialiser ?'),
          ],
        ),
        content: const Text(
          'Attention : Toutes les données (blocs, routines, rappels) seront définitivement remises à zéro.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.pop(ctx);
              await s.resetAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('Réinitialisation d\'usine terminée.'),
                  ),
                );
              }
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Paramètres',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Section 1 : Notifications & Rappels
          _buildSectionHeader('Notifications & Rappels', Icons.notifications_active_outlined, theme),
          const SizedBox(height: 8),
          Container(
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
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined, color: Color(0xFF00B894)),
                  title: const Text('Autorisations Android', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  subtitle: const Text('Vérifier l\'accès aux notifications et alarmes exactes', style: TextStyle(fontSize: 12)),
                  trailing: TextButton(
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      await NotificationService.requestPermissions();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('Demande d\'autorisations transmise au système.'),
                          ),
                        );
                      }
                    },
                    child: const Text('Vérifier'),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.access_time_rounded, color: Color(0xFF0984E3)),
                  title: const Text('Rappel par défaut', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  subtitle: const Text('Délai appliqué par défaut lors de la création d\'un créneau', style: TextStyle(fontSize: 12)),
                  trailing: DropdownButton<int>(
                    value: s.defaultReminder,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('À l\'heure')),
                      DropdownMenuItem(value: 5, child: Text('5 min avant')),
                      DropdownMenuItem(value: 10, child: Text('10 min avant')),
                      DropdownMenuItem(value: 15, child: Text('15 min avant')),
                      DropdownMenuItem(value: 30, child: Text('30 min avant')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        HapticFeedback.selectionClick();
                        s.setDefaultReminder(v);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 2 : Sauvegarde & Données
          _buildSectionHeader('Gestion & Sauvegarde des Données', Icons.storage_rounded, theme),
          const SizedBox(height: 8),
          Container(
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
                ListTile(
                  leading: const Icon(Icons.save_as_rounded, color: Color(0xFF00B894)),
                  title: const Text('Sauvegarder en fichier texte (.txt)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  subtitle: const Text('Exporte votre planning complet et vos routines en .txt', style: TextStyle(fontSize: 12)),
                  trailing: FilledButton.tonal(
                    onPressed: () => _exportBackup(context),
                    child: const Text('Exporter'),
                  ),
                  onTap: () => _exportBackup(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.file_download_rounded, color: Color(0xFF6C5CE7)),
                  title: const Text('Importer une sauvegarde', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  subtitle: const Text('Restaure vos routines et votre planning depuis un fichier ou texte', style: TextStyle(fontSize: 12)),
                  trailing: FilledButton.tonal(
                    onPressed: () => _importBackup(context),
                    child: const Text('Importer'),
                  ),
                  onTap: () => _importBackup(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF6C5CE7)),
                  title: const Text('Nettoyer les doublons', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  subtitle: const Text('Détecte et purge les blocs dupliqués ou orphelins', style: TextStyle(fontSize: 12)),
                  trailing: FilledButton.tonal(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      final count = context.read<AppState>().cleanDuplicates();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(count > 0
                              ? '$count bloc(s) en double supprimé(s).'
                              : 'Aucun doublon : vos données sont déjà parfaitement optimisées !'),
                        ),
                      );
                    },
                    child: const Text('Optimiser'),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  title: const Text('Réinitialisation complète (Usine)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Colors.redAccent)),
                  subtitle: const Text('Efface tous les blocs, routines et remet l\'app à zéro', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showResetDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 3 : À propos
          _buildSectionHeader('À propos de Kanlé', Icons.info_outline_rounded, theme),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kanlé · Timebloc',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Version 1.2 · 100% Hors-ligne\nZéro compte · Respect absolu de la vie privée',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
