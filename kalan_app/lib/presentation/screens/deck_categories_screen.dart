import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_colors.dart';
import '../../data/local/database_helper.dart';
import 'deck_list_screen.dart';

class DeckCategoriesScreen extends StatefulWidget {
  const DeckCategoriesScreen({super.key});

  @override
  State<DeckCategoriesScreen> createState() => _DeckCategoriesScreenState();
}

class _DeckCategoriesScreenState extends State<DeckCategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final db = await DatabaseHelper.instance.database;
    final subjects = await DatabaseHelper.instance.getAllSubjects();
    
    final List<Map<String, dynamic>> cats = [];
    for (var s in subjects) {
      final count = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM decks WHERE subject = ?", [s['id']]
      )) ?? 0;
      
      cats.add({
        'name': s['label'],
        'icon': IconData(s['icon_code'] as int, fontFamily: 'MaterialIcons'),
        'count': count,
        'color': Color(s['color'] as int),
      });
    }

    // Ajouter les matières orphelines (decks avec subject non référencé)
    final orphans = await db.rawQuery(
      "SELECT DISTINCT subject FROM decks WHERE subject NOT IN (SELECT id FROM subjects) AND subject IS NOT NULL"
    );
    for (var row in orphans) {
      final subjectName = row['subject'] as String;
      final count = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM decks WHERE subject = ?", [subjectName]
      )) ?? 0;
      cats.add({
        'name': subjectName,
        'icon': Icons.folder_rounded,
        'count': count,
        'color': Colors.blueGrey,
      });
    }

    if (mounted) setState(() { _categories = cats; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Matières'), centerTitle: true),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher une matière...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: _categories.isEmpty
                ? const Center(child: Text('Aucune matière trouvée'))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      return _buildCategoryCard(context, cat);
                    },
                  ),
            ),
          ],
        ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> cat) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DeckListScreen(filterSubject: cat['name'])),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: (cat['color'] as Color).withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(cat['icon'], color: cat['color'], size: 32),
            ),
            const SizedBox(height: 12),
            Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onBackground), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('${cat['count']} decks', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

