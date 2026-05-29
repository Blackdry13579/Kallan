import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../blocs/deck/deck_bloc.dart';
import '../blocs/deck/deck_event.dart';
import '../blocs/deck/deck_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_shimmer.dart';
import 'flashcard_study_screen.dart';
import 'share_screen.dart';
import '../../domain/entities/deck.dart';

class DeckListScreen extends StatelessWidget {
  final String? filterSubject;
  const DeckListScreen({super.key, this.filterSubject});

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, dynamic>> subjectConfigs = {
      // Système 6 catégories actuel
      'Mathématiques': {'color': const Color(0xFF6A2D9F), 'bg': const Color(0xFFEDE9FE), 'icon': Icons.calculate_rounded},
      'Sciences': {'color': const Color(0xFF009688), 'bg': const Color(0xFFE0F2F1), 'icon': Icons.science_rounded},
      'Français': {'color': const Color(0xFFB00020), 'bg': const Color(0xFFFDECEE), 'icon': Icons.menu_book_rounded},
      'Histoire-Géo': {'color': const Color(0xFF854F0B), 'bg': const Color(0xFFFAEEDA), 'icon': Icons.public_rounded},
      'Langues': {'color': const Color(0xFFE07B39), 'bg': const Color(0xFFFCEFE6), 'icon': Icons.translate_rounded},
      'Autre': {'color': const Color(0xFF2196F3), 'bg': const Color(0xFFE3F2FD), 'icon': Icons.extension_rounded},
      // Anciens sujets granulaires (compatibilité decks existants avant migration)
      'SVT': {'color': const Color(0xFF009688), 'bg': const Color(0xFFE0F2F1), 'icon': Icons.biotech_rounded},
      'Physique-Chimie': {'color': const Color(0xFF6A2D9F), 'bg': const Color(0xFFEEEDFE), 'icon': Icons.science_rounded},
      'Anglais': {'color': const Color(0xFFE07B39), 'bg': const Color(0xFFFCEFE6), 'icon': Icons.translate_rounded},
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(filterSubject ?? 'Mes Decks'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onBackground,
      ),
      body: BlocBuilder<DeckBloc, DeckState>(
        builder: (context, state) {
          if (state is DeckLoading) return const LoadingShimmer();
          if (state is DeckError) return Center(child: Text(state.message));
          if (state is DeckLoaded) {
            var decks = state.decks;
            if (filterSubject != null) {
              decks = decks.where((d) => d.subject == filterSubject).toList();
            }

            if (decks.isEmpty) return const EmptyState(title: 'Aucun deck', subtitle: 'Commence par créer ton premier deck de révision !');

            // Group decks by subject
            final Map<String, List<Deck>> decksBySubject = {};
            for (var deck in decks) {
              final subject = deck.subject ?? 'Autres';
              if (!decksBySubject.containsKey(subject)) {
                decksBySubject[subject] = [];
              }
              decksBySubject[subject]!.add(deck);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: decksBySubject.length,
              itemBuilder: (context, index) {
                final subject = decksBySubject.keys.elementAt(index);
                final subjectDecks = decksBySubject[subject]!;
                final config = subjectConfigs[subject] ?? {
                  'color': AppColors.primary,
                  'bg': AppColors.primary.withValues(alpha: 0.1),
                  'icon': Icons.school_rounded
                };

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(color: config['color'], borderRadius: BorderRadius.circular(6)),
                            child: Icon(config['icon'], color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 8),
                          Text(subject, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('${subjectDecks.length} decks', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    ...subjectDecks.map((deck) => _buildDeckItem(context, deck, config)),
                  ],
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDeckItem(BuildContext context, Deck deck, Map<String, dynamic> config) {
    return Dismissible(
      key: Key(deck.uuid),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => context.read<DeckBloc>().add(DeleteDeck(deck.uuid)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FlashcardStudyScreen(deckTitle: deck.title, deckUuid: deck.uuid))),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: config['bg'], borderRadius: BorderRadius.circular(12)),
                child: Icon(config['icon'], color: config['color'], size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deck.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('${deck.level ?? '3ème'} · ${deck.cardCount} cartes', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, color: AppColors.secondary, size: 20),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShareScreen(deck: deck))),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                onPressed: () => _confirmDelete(context, deck),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Deck deck) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette fiche ?'),
        content: Text('Es-tu sûr de vouloir supprimer "${deck.title}" ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              context.read<DeckBloc>().add(DeleteDeck(deck.uuid));
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
