class LevelInfo {
  final String title;
  final int level;
  final int minPoints;
  final int maxPoints;
  final String icon;
  final String assetImage;
  final String mascotImage;

  LevelInfo({
    required this.title,
    required this.level,
    required this.minPoints,
    required this.maxPoints,
    required this.icon,
    this.assetImage = '',
    this.mascotImage = '',
  });

  int get nextLevelPoints => maxPoints;

  double get progress {
    if (maxPoints == minPoints) return 1.0;
    final p = (maxPoints - minPoints) > 0 ? (maxPoints - minPoints).toDouble() : 0.0;
    return p;
  }
}

class LevelUtils {
  static final List<LevelInfo> levels = [
    LevelInfo(title: 'Graine',        level: 1,  minPoints: 0,      maxPoints: 500,     icon: '🌱', assetImage: 'level-1-graine.jpg',  mascotImage: 'mascot-1.png'),
    LevelInfo(title: 'Jeune Pousse',  level: 2,  minPoints: 500,    maxPoints: 1500,    icon: '🌿', assetImage: 'level-2-pousse.jpg',  mascotImage: 'mascot-2.png'),
    LevelInfo(title: 'Baobab',        level: 3,  minPoints: 1500,   maxPoints: 3500,    icon: '🌳', assetImage: 'level-3-baobab.jpg',  mascotImage: 'mascot-3.png'),
    LevelInfo(title: 'Feu de Brousse',level: 4,  minPoints: 3500,   maxPoints: 7000,    icon: '🔥', assetImage: 'level-4-feu.jpg',     mascotImage: 'mascot-4.png'),
    LevelInfo(title: 'Griot',         level: 5,  minPoints: 7000,   maxPoints: 12000,   icon: '🪕', assetImage: 'level-5-griot.jpg',   mascotImage: 'mascot-5.png'),
    LevelInfo(title: 'Masque',        level: 6,  minPoints: 12000,  maxPoints: 20000,   icon: '🎭', assetImage: 'level-6-masque.jpg',  mascotImage: 'mascot-6.png'),
    LevelInfo(title: 'Gardien',       level: 7,  minPoints: 20000,  maxPoints: 35000,   icon: '🏺', assetImage: 'level-7-gardien.jpg', mascotImage: 'mascot-7.png'),
    LevelInfo(title: 'Ancêtre',       level: 8,  minPoints: 35000,  maxPoints: 60000,   icon: '✨', assetImage: 'level-8-ancetre.jpg', mascotImage: 'mascot-8.png'),
    LevelInfo(title: 'Sage',          level: 9,  minPoints: 60000,  maxPoints: 100000,  icon: '👑', assetImage: 'level-9-sage.jpg',    mascotImage: 'mascot-9.png'),
    LevelInfo(title: 'Lumière',       level: 10, minPoints: 100000, maxPoints: 9999999, icon: '☀️', assetImage: 'level-10-lumiere.jpg',mascotImage: 'mascot-10.png'),
  ];

  static LevelInfo getLevelInfo(int points) {
    for (var i = levels.length - 1; i >= 0; i--) {
      if (points >= levels[i].minPoints) {
        return levels[i];
      }
    }
    return levels.first;
  }

  static String getLevelTitle(int level) {
    if (level < 1) return levels[0].title;
    if (level > levels.length) return levels.last.title;
    return levels[level - 1].title;
  }
}
