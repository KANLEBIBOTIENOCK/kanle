import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isComposing = false;

  int _suggestionOffset = 0;

  static const Map<int, List<String>> _weekdaySuggestions = {
    DateTime.monday: [
      'Planifie mes blocs de travail pour aujourd\'hui dès 9h',
      'Créer une routine sport chaque matin de 7h à 7h45',
      'Résous tous les conflits d\'horaires d\'aujourd\'hui',
      'Rappelle-moi de faire le point de début de semaine à 11h',
      'Créer un bloc Focus de 14h à 16h30',
    ],
    DateTime.tuesday: [
      'Planifie un bloc étude et lecture de 20h à 21h30',
      'Créer des blocs "manger" chaque jour de 11h à 11h40',
      'Ajoute un bloc sport de 18h à 19h15 aujourd\'hui',
      'Vérifie et résous les chevauchements de mon planning',
      'Rappelle-moi de prendre mes vitamines ce soir à 21h',
    ],
    DateTime.wednesday: [
      'Créer un bloc pause & détente de 13h à 14h',
      'Planifie ma routine révision pour cet après-midi',
      'Créer un bloc travail projet de 10h à 12h30',
      'Rappelle-moi d\'appeler la famille à 19h30',
      'Résous les conflits d\'horaires de cette journée',
    ],
    DateTime.thursday: [
      'Optimise mes créneaux pour avancer sur mes priorités',
      'Créer une routine prière & méditation chaque matin à 6h30',
      'Planifie un bloc sport intensif de 18h à 19h',
      'Ajoute un bloc Focus de 14h à 16h',
      'Rappelle-moi de finaliser mes tâches urgentes à 17h',
    ],
    DateTime.friday: [
      'Planifie mon créneau bilan de fin de semaine de 16h à 17h',
      'Créer une routine lecture tous les soirs de 21h à 22h',
      'Résous les conflits de planning avant le week-end',
      'Créer un bloc détente & social ce soir à 19h30',
      'Rappelle-moi de préparer mes objectifs à 18h',
    ],
    DateTime.saturday: [
      'Planifie une séance sport et santé de 9h à 10h30',
      'Créer un bloc famille & détente cet après-midi de 14h à 17h',
      'Créer des blocs "repas" chaque jour de 12h30 à 13h30',
      'Rappelle-moi d\'appeler mes proches aujourd\'hui à 19h',
      'Planifie un temps de repos de 13h30 à 15h',
    ],
    DateTime.sunday: [
      'Organise mes routines pour la semaine à venir',
      'Planifie ma journée de lundi matin dès 8h30',
      'Créer un bloc lecture & méditation de 20h à 21h30',
      'Vérifie mes disponibilités et résous les conflits',
      'Rappelle-moi de préparer mes affaires ce soir à 21h',
    ],
  };

  static const List<String> _bonusSuggestions = [
    'Créer des blocs "manger" chaque jour de 11h à 11h40',
    'Planifie un bloc Focus Deep Work de 9h à 11h30',
    'Créer une routine marche rapide du lundi au vendredi à 18h',
    'Résous les chevauchements dans mon agenda',
    'Rappelle-moi de boire de l\'eau toutes les 2 heures',
    'Ajoute un créneau de repos de 13h à 13h45 aujourd\'hui',
  ];

  String get _currentDayName {
    final now = DateTime.now();
    return const [
      '',
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ][now.weekday];
  }

  List<String> get _quickPrompts {
    final weekday = DateTime.now().weekday;
    final base = _weekdaySuggestions[weekday] ?? _weekdaySuggestions[DateTime.monday]!;
    if (_suggestionOffset == 0) return base;
    final all = [...base, ..._bonusSuggestions];
    final start = (_suggestionOffset * 2) % all.length;
    final res = <String>[];
    for (var i = 0; i < 5; i++) {
      res.add(all[(start + i) % all.length]);
    }
    return res;
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend([String? textToSend]) async {
    final text = (textToSend ?? _textController.text).trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() => _isComposing = false);

    final state = context.read<AppState>();
    _scrollToBottom();
    await state.askAi(text);
    _scrollToBottom();
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
              SizedBox(width: 8),
              Text('Message copié dans le presse-papier !'),
            ],
          ),
        ),
      );
    }
  }

  void _showHistorySheet(BuildContext context, AppState state, bool isDark) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final sessions = state.chatSessions;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.75,
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
                      const Icon(Icons.history_rounded, color: Color(0xFF6C5CE7), size: 24),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Historique des conversations',
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
                    icon: const Icon(Icons.add_comment_rounded, size: 18),
                    label: const Text('Nouvelle discussion', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      state.startNewChatSession();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('Nouvelle discussion démarrée.'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Expanded(
                    child: sessions.isEmpty
                        ? const Center(child: Text('Aucune conversation enregistrée.'))
                        : ListView.separated(
                            itemCount: sessions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final session = sessions[i];
                              final isCurrent = session.id == state.currentSessionId;
                              final dateStr = DateFormat('dd/MM à HH:mm').format(session.createdAt);

                              return Container(
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? const Color(0xFF6C5CE7).withOpacity(0.12)
                                      : (isDark ? const Color(0xFF28283C) : const Color(0xFFF7F8FC)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrent
                                        ? const Color(0xFF6C5CE7)
                                        : Colors.grey.withOpacity(0.15),
                                    width: isCurrent ? 1.5 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  leading: CircleAvatar(
                                    backgroundColor: isCurrent ? const Color(0xFF6C5CE7) : Colors.grey.shade400,
                                    radius: 16,
                                    child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 16),
                                  ),
                                  title: Text(
                                    session.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 14,
                                      color: isCurrent ? const Color(0xFF6C5CE7) : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${session.messages.length} message(s) · $dateStr',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                                    onPressed: () {
                                      showDialog(
                                        context: ctx,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Supprimer cette discussion ?'),
                                          content: Text('Voulez-vous supprimer "${session.title}" ?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(c);
                                                state.deleteChatSession(session.id);
                                                setSheetState(() {});
                                              },
                                              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  onTap: () {
                                    state.switchChatSession(session.id);
                                    Navigator.pop(ctx);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Assistant Kanlé IA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    state.activeChatSession.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle discussion',
            icon: const Icon(Icons.add_comment_outlined, size: 22),
            onPressed: () {
              state.startNewChatSession();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Nouvelle discussion démarrée.'),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Historique des conversations',
            icon: const Icon(Icons.history_rounded, size: 22),
            onPressed: () => _showHistorySheet(context, state, isDark),
          ),
          if (state.chatHistory.isNotEmpty)
            IconButton(
              tooltip: 'Effacer la discussion en cours',
              icon: const Icon(Icons.delete_sweep_outlined, size: 22),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Effacer la discussion ?'),
                    content: const Text('Tous les messages de cette discussion seront effacés.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                      TextButton(
                        onPressed: () {
                          state.clearChatHistory();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Effacer', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Indicateur de statut IA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? const Color(0xFF1B1B26) : const Color(0xFFF0F1FA),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF00B894),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'IA Autonome active (Google Gemini)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Zone des messages
            Expanded(
              child: state.chatHistory.isEmpty
                  ? _buildEmptyState(context, isDark)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      itemCount: state.chatHistory.length + (state.isAiLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.chatHistory.length && state.isAiLoading) {
                          return _buildLoadingBubble(isDark);
                        }
                        final msg = state.chatHistory[index];
                        return _buildMessageItem(context, msg, isDark, state);
                      },
                    ),
            ),

            // Suggestions de commandes rapides renouvelées chaque jour
            if (state.chatHistory.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text('Idées $_currentDayName',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                        avatar: const Icon(Icons.refresh_rounded,
                            size: 14, color: Color(0xFF6C5CE7)),
                        backgroundColor:
                            isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1EEFD),
                        side: BorderSide(
                            color: const Color(0xFF6C5CE7).withOpacity(0.3)),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _suggestionOffset++);
                        },
                      ),
                    ),
                    ..._quickPrompts.map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(p, style: const TextStyle(fontSize: 11)),
                          avatar: const Icon(Icons.bolt_rounded,
                              size: 14, color: Color(0xFF6C5CE7)),
                          backgroundColor:
                              isDark ? const Color(0xFF1E1E2C) : Colors.white,
                          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                          onPressed: () => _handleSend(p),
                        ),
                      );
                    }),
                  ],
                ),
              ),

            // Barre de saisie inférieure
            _buildInputBar(context, isDark, state),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C5CE7).withOpacity(0.18),
                    const Color(0xFF00CEC9).withOpacity(0.18),
                  ],
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 48, color: Color(0xFF6C5CE7)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Que souhaitez-vous organiser ?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'L\'IA Kanlé gère vos tâches exclusives, vos créneaux de planning et résout tous vos conflits horaires en langage naturel.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              textAlign: TextAlign.center,
            ),
            // En-tête des suggestions avec le jour actuel et bouton pour renouveler
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 15, color: Color(0xFF6C5CE7)),
                const SizedBox(width: 6),
                Text(
                  'Suggestions du $_currentDayName :',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _suggestionOffset++);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF6C5CE7)),
                        SizedBox(width: 4),
                        Text(
                          'Renouveler',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6C5CE7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              children: _quickPrompts.map((prompt) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isDark ? const Color(0xFF191924) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    elevation: 0.5,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _handleSend(prompt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.touch_app_rounded, size: 18, color: Color(0xFF6C5CE7)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                prompt,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(BuildContext context, ChatMessage msg, bool isDark, AppState state) {
    final isUser = msg.sender == 'user';
    final timeStr = DateFormat('HH:mm').format(msg.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    onLongPress: () => _copyToClipboard(context, msg.text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color(0xFF6C5CE7)
                            : (isDark ? const Color(0xFF1E1E2C) : Colors.white),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isUser
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),

                // Affichage des actions proposées par l'assistant
                if (!isUser && msg.actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (ctx) {
                      final pendingActions =
                          msg.actions.where((a) => !a.isApplied).toList();
                      if (pendingActions.length > 1) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF6C5CE7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 1,
                              ),
                              icon: const Icon(Icons.playlist_add_check_circle_rounded,
                                  size: 19),
                              label: Text(
                                'Tout appliquer (${pendingActions.length} actions)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              onPressed: () {
                                final count = state.applyAllAiActions(msg.actions);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '✓ $count actions appliquées au planning et aux routines !'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: const Color(0xFF00B894),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  ...msg.actions.map((act) => _buildActionCard(context, act, state, isDark)),
                ],

                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => _copyToClipboard(context, msg.text),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded, size: 11, color: Colors.grey.shade500),
                              const SizedBox(width: 3),
                              Text(
                                'Copier',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade400,
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 15),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, AiAction act, AppState state, bool isDark) {
    Color tagColor;
    String tagLabel;
    IconData icon;

    if (act.type.contains('task')) {
      tagColor = const Color(0xFF00B894);
      tagLabel = 'TÂCHE IA';
      icon = Icons.task_alt_rounded;
    } else if (act.type.contains('routine')) {
      tagColor = const Color(0xFFE17055);
      tagLabel = 'ROUTINE';
      icon = Icons.repeat_rounded;
    } else if (act.type.contains('conflict')) {
      tagColor = const Color(0xFFFF7675);
      tagLabel = 'CONFLIT';
      icon = Icons.warning_amber_rounded;
    } else if (act.type.contains('delete')) {
      tagColor = const Color(0xFFD63031);
      tagLabel = 'SUPPRESSION';
      icon = Icons.delete_outline_rounded;
    } else {
      tagColor = const Color(0xFF0984E3);
      tagLabel = 'PLANNING';
      icon = Icons.calendar_month_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171722) : const Color(0xFFF9FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: act.isApplied ? Colors.green.withOpacity(0.5) : tagColor.withOpacity(0.3),
          width: act.isApplied ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tagColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: tagColor),
                    const SizedBox(width: 4),
                    Text(
                      tagLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: tagColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (act.isApplied)
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 15, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'Appliqué',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            act.description,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (!act.isApplied) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tagColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('Appliquer maintenant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final success = state.applyAiAction(act);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Action appliquée : ${act.description}'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingBubble(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
              ),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C5CE7)),
                ),
                const SizedBox(width: 10),
                Text(
                  'Organisation de vos blocs...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF4A4B65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, bool isDark, AppState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13131B) : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF2F3F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (val) => setState(() => _isComposing = val.trim().isNotEmpty),
                onSubmitted: state.isAiLoading ? null : (val) => _handleSend(),
                decoration: const InputDecoration(
                  hintText: 'Demandez à l\'IA (ex: appeler maman)...',
                  hintStyle: TextStyle(fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _isComposing && !state.isAiLoading
                ? const Color(0xFF6C5CE7)
                : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: (_isComposing && !state.isAiLoading) ? () => _handleSend() : null,
              child: const Padding(
                padding: EdgeInsets.all(11),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
