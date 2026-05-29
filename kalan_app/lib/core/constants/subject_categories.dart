import 'package:flutter/material.dart';

class SubjectCategories {
  static const mathematiques = 'Mathématiques';
  static const sciences = 'Sciences';
  static const francais = 'Français';
  static const histoireGeo = 'Histoire-Géo';
  static const langues = 'Langues';
  static const autre = 'Autre';

  static const all = <String>[
    mathematiques,
    sciences,
    francais,
    histoireGeo,
    langues,
    autre,
  ];

  static const emojis = <String, String>{
    mathematiques: '📐',
    sciences: '🔬',
    francais: '📖',
    histoireGeo: '🌍',
    langues: '🗣️',
    autre: '📚',
  };

  static const colors = <String, Color>{
    mathematiques: Color(0xFF6A2D9F),
    sciences: Color(0xFF009688),
    francais: Color(0xFFB00020),
    histoireGeo: Color(0xFF854F0B),
    langues: Color(0xFFE07B39),
    autre: Color(0xFF2196F3),
  };

  static const backgroundColors = <String, Color>{
    mathematiques: Color(0xFFEDE9FE),
    sciences: Color(0xFFE0F2F1),
    francais: Color(0xFFFDECEE),
    histoireGeo: Color(0xFFFAEEDA),
    langues: Color(0xFFFCEFE6),
    autre: Color(0xFFE3F2FD),
  };

  static String normalize(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return autre;

    if (all.contains(value)) return value;

    final lower = _withoutAccents(value.toLowerCase());

    if (lower.contains('math')) return mathematiques;

    if (lower.contains('science') ||
        lower.contains('svt') ||
        lower.contains('biologie') ||
        lower.contains('biolog') ||
        lower.contains('physique') ||
        lower.contains('chimie') ||
        lower.contains('physics') ||
        lower.contains('chemistry')) {
      return sciences;
    }

    if (lower.contains('francais') ||
        lower.contains('litterature') ||
        lower.contains('grammaire') ||
        lower.contains('poesie') ||
        lower.contains('expression ecrite') ||
        lower.contains('french')) {
      return francais;
    }

    if (lower.contains('histoire') ||
        lower.contains('geographie') ||
        lower.contains('history') ||
        lower.contains('geography') ||
        lower.contains('geo')) {
      return histoireGeo;
    }

    if (lower.contains('langue') ||
        lower.contains('anglais') ||
        lower.contains('english') ||
        lower.contains('arabe') ||
        lower.contains('arabic') ||
        lower.contains('allemand') ||
        lower.contains('german') ||
        lower.contains('traduction')) {
      return langues;
    }

    // Informatique, Philosophie, Économie, Gestion, Éducation Civique → Autre
    return autre;
  }

  static String _withoutAccents(String value) {
    return value
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('ç', 'c')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u');
  }
}
