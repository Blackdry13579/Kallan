import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../blocs/deck/deck_bloc.dart';
import '../blocs/deck/deck_event.dart';
import '../blocs/deck/deck_state.dart';
import '../../domain/entities/deck.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/supabase_service.dart';
import 'deck_list_screen.dart';
import 'flashcard_study_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _sortOption = 'Date de création';
  List<Map<String, dynamic>> _publicDecks = [];
  bool _loadingPublic = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<DeckBloc>().add(const LoadDecks());
    _tabController.addListener(() {
      if (_tabController.index == 1 && _publicDecks.isEmpty && !_loadingPublic) {
        _loadPublicDecks();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPublicDecks() async {
    setState(() => _loadingPublic = true);
    try {
      final res = await SupabaseService.client
          .from('public_decks')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) setState(() => _publicDecks = List<Map<String, dynamic>>.from(res));
    } catch (_) {
      // table inexistante ou pas encore créée → liste vide
    } finally {
      if (mounted) setState(() => _loadingPublic = false);
    }
  }

  void _confirmDelete(BuildContext context, Deck deck) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer ?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Supprimer "${deck.title}" définitivement ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              context.read<DeckBloc>().add(DeleteDeck(deck.uuid));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fiche supprimée ✓'), duration: Duration(seconds: 2)),
              );
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMesFilesTab(),
                    _buildPublicTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TABS ──────────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        TabBar(
          controller: _tabController,
          isScrollable: false,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          dividerColor: const Color(0xFFE5E1DA),
          dividerHeight: 1,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: Color(0xFF2D6A2D), width: 2.5),
            insets: EdgeInsets.symmetric(horizontal: 20),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: const Color(0xFF1A1A1A),
          unselectedLabelColor: const Color(0xFF9A9A9A),
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          tabs: const [
            Tab(text: 'Mes Fiches'),
            Tab(text: 'Public'),
          ],
        ),
      ],
    );
  }

  // ── MES FICHES ────────────────────────────────────────────────────────────────
  Widget _buildMesFilesTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: BlocBuilder<DeckBloc, DeckState>(
            builder: (context, state) {
              if (state is DeckLoading) return const Center(child: CircularProgressIndicator());
              if (state is DeckLoaded) {
                final query = _searchController.text.toLowerCase();
                var decks = state.decks.where((d) => d.title.toLowerCase().contains(query)).toList();

                if (_sortOption == 'Nom (A-Z)') {
                  decks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
                } else if (_sortOption == 'Progression') {
                  decks.sort((a, b) {
                    final pA = a.cardCount > 0 ? a.masteredCount / a.cardCount : 0.0;
                    final pB = b.cardCount > 0 ? b.masteredCount / b.cardCount : 0.0;
                    return pB.compareTo(pA);
                  });
                }

                if (decks.isEmpty) return _buildEmptyState();

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: DatabaseHelper.instance.getAllSubjects(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final subjects = snapshot.data!;

                    final subjectsWithDecks = subjects
                        .where((s) => decks.any((d) => d.subject == s['label']))
                        .toList();

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 16, bottom: 100),
                      itemCount: subjectsWithDecks.length,
                      itemBuilder: (context, index) {
                        final subject = subjectsWithDecks[index];
                        final subjectDecks = decks.where((d) => d.subject == subject['label']).toList();
                        return _buildSubjectSection(subject, subjectDecks);
                      },
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E1DA)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
          decoration: const InputDecoration(
            hintText: 'Rechercher une fiche...',
            hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFFAAAAAA)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectSection(Map<String, dynamic> subject, List<Deck> decks) {
    final color = Color(subject['color'] as int);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                subject['label'],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text('${decks.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DeckListScreen(filterSubject: subject['label']))),
                child: const Text('Voir tout', style: TextStyle(fontSize: 11, color: Color(0xFF2D6A2D), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: List.generate(decks.length, (i) => _buildDeckCard(decks[i], color)),
          ),
        ),
      ],
    );
  }

  Widget _buildDeckCard(Deck deck, Color color) {
    final pct = deck.cardCount > 0
        ? (deck.lastQuizScore ?? (deck.masteredCount / deck.cardCount * 100).round())
        : 0;
    final isGrey = color.toARGB32() == 0xFF9E9E9E;
    final cardColor = isGrey ? const Color(0xFF2D6A2D) : color;
    final barColor = pct < 50 ? const Color(0xFFE07B39) : cardColor;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => FlashcardStudyScreen(deckTitle: deck.title, deckUuid: deck.uuid))),
      onLongPress: () => _confirmDelete(context, deck),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEAE3), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    deck.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 3),
                  Text('${deck.cardCount} cartes', style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0.0, 1.0),
                      backgroundColor: const Color(0xFFEEEAE3),
                      color: barColor,
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$pct%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: barColor)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => Share.share('Révise "${deck.title}" sur KALAN ! 📚'),
                      child: const Icon(Icons.share_rounded, size: 15, color: Color(0xFFAAAAAA)),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _confirmDelete(context, deck),
                      child: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.redAccent),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A2D).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.library_books_rounded, size: 38, color: Color(0xFF2D6A2D)),
            ),
            const SizedBox(height: 20),
            const Text('Aucune fiche', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            const Text(
              'Crée ta première fiche en appuyant sur le bouton + en bas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── PUBLIC ────────────────────────────────────────────────────────────────────
  Widget _buildPublicTab() {
    if (_loadingPublic) return const Center(child: CircularProgressIndicator());

    if (_publicDecks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6A2D).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.public_rounded, size: 38, color: Color(0xFF2D6A2D)),
              ),
              const SizedBox(height: 20),
              const Text('Bientôt disponible', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 8),
              const Text(
                'Les fiches partagées par la communauté KALAN apparaîtront ici.\nTu pourras les importer et réviser directement.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadPublicDecks,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Actualiser', style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A2D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: _publicDecks.length,
      itemBuilder: (context, i) => _buildPublicCard(_publicDecks[i]),
    );
  }

  Widget _buildPublicCard(Map<String, dynamic> deck) {
    final title = deck['title'] as String? ?? 'Sans titre';
    final cardCount = deck['card_count'] as int? ?? 0;
    final author = deck['author_pseudo'] as String? ?? 'KALAN';
    final subject = deck['subject'] as String? ?? 'Général';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEAE3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A2D).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(subject, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF2D6A2D))),
          ),
          const SizedBox(height: 8),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A), height: 1.3)),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.style_rounded, size: 12, color: Color(0xFFAAAAAA)),
              const SizedBox(width: 4),
              Text('$cardCount cartes', style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFFAAAAAA)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(author, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── FILTRES ───────────────────────────────────────────────────────────────────
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trier par', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            _filterOption(ctx, 'Date de création'),
            _filterOption(ctx, 'Nom (A-Z)'),
            _filterOption(ctx, 'Progression'),
          ],
        ),
      ),
    );
  }

  Widget _filterOption(BuildContext ctx, String label) {
    final isSelected = _sortOption == label;
    return ListTile(
      onTap: () { setState(() => _sortOption = label); Navigator.pop(ctx); },
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF2D6A2D) : const Color(0xFF1A1A1A), fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
      trailing: isSelected ? const Icon(Icons.check_rounded, color: Color(0xFF2D6A2D)) : null,
    );
  }
}

