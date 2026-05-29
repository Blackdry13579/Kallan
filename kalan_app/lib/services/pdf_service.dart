import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfAnalysis {
  final String text;
  final int pageCount;
  final int processedPages;
  final int textPageCount;
  final int imageObjectCount;
  final String detectedLanguage;
  final List<String> contentSignals;
  final String aiContext;

  const PdfAnalysis({
    required this.text,
    required this.pageCount,
    required this.processedPages,
    required this.textPageCount,
    required this.imageObjectCount,
    required this.detectedLanguage,
    required this.contentSignals,
    required this.aiContext,
  });

  bool get hasExtractableText => text.trim().isNotEmpty;
  bool get hasImages => imageObjectCount > 0;
  bool get likelyScanned => !hasExtractableText && hasImages;

  factory PdfAnalysis.fromMap(Map<String, dynamic> map) {
    return PdfAnalysis(
      text: map['text'] as String? ?? '',
      pageCount: map['pageCount'] as int? ?? 0,
      processedPages: map['processedPages'] as int? ?? 0,
      textPageCount: map['textPageCount'] as int? ?? 0,
      imageObjectCount: map['imageObjectCount'] as int? ?? 0,
      detectedLanguage: map['detectedLanguage'] as String? ?? 'français',
      contentSignals: ((map['contentSignals'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      aiContext: map['aiContext'] as String? ?? '',
    );
  }
}

class PdfService {
  /// Extrait le texte d'un fichier PDF, limité aux [maxPages] premières pages, en utilisant un isolate.
  Future<String> extractText(
      {String? filePath, List<int>? bytes, int maxPages = 10}) async {
    try {
      final result =
          await analyze(filePath: filePath, bytes: bytes, maxPages: maxPages);
      return result.text;
    } catch (e) {
      debugPrint('[PdfService] Erreur lors de l\'extraction PDF : $e');
      throw Exception('Erreur lors de la lecture du PDF : $e');
    }
  }

  /// Analyse un PDF hors ligne : texte extractible, langue, indices de contenu et présence d'images.
  Future<PdfAnalysis> analyze(
      {String? filePath, List<int>? bytes, int maxPages = 15}) async {
    try {
      final result = await compute(_analyzePdfTask, {
        'filePath': filePath,
        'bytes': bytes,
        'maxPages': maxPages,
      });
      return PdfAnalysis.fromMap(result);
    } catch (e) {
      debugPrint('[PdfService] Erreur lors de l\'analyse PDF : $e');
      throw Exception('Erreur lors de la lecture du PDF : $e');
    }
  }
}

/// Fonction de niveau supérieur exécutée dans un Isolate séparé.
Future<Map<String, dynamic>> _analyzePdfTask(Map<String, dynamic> args) async {
  final filePath = args['filePath'] as String?;
  final bytes = args['bytes'] as List<int>?;
  final maxPages = args['maxPages'] as int;

  final List<int> pdfBytes;
  if (bytes != null) {
    debugPrint(
        '[PdfService Isolate] Extraction à partir de bytes (${bytes.length} octets)');
    pdfBytes = bytes;
  } else if (filePath != null) {
    debugPrint(
        '[PdfService Isolate] Extraction à partir du fichier : $filePath');
    final File file = File(filePath);
    if (!file.existsSync()) {
      throw Exception(
          'Le fichier PDF n\'existe pas à l\'emplacement : $filePath');
    }
    pdfBytes = await file.readAsBytes();
    debugPrint(
        '[PdfService Isolate] Fichier lu avec succès (${pdfBytes.length} octets)');
  } else {
    throw Exception(
        'Aucune source de fichier PDF fournie (chemin ou octets nuls).');
  }

  // Chargement du document PDF
  final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
  final int totalPages = document.pages.count;
  debugPrint(
      '[PdfService Isolate] Document PDF chargé. Nombre total de pages : $totalPages');

  if (totalPages == 0) {
    document.dispose();
    return _buildPdfAnalysisMap(
      text: '',
      pageCount: 0,
      processedPages: 0,
      textPageCount: 0,
      imageObjectCount: _countPdfImages(pdfBytes),
    );
  }

  // Détermination du nombre de pages à traiter
  int pagesToProcess = totalPages;
  if (pagesToProcess > maxPages) {
    pagesToProcess = maxPages;
    debugPrint(
        '[PdfService Isolate] Limitation de l\'extraction aux $maxPages premières pages.');
  }

  final PdfTextExtractor extractor = PdfTextExtractor(document);
  final pageTexts = <String>[];
  int textPageCount = 0;

  for (int i = 0; i < pagesToProcess; i++) {
    final pageText =
        extractor.extractText(startPageIndex: i, endPageIndex: i).trim();
    if (pageText.isNotEmpty) {
      textPageCount++;
      pageTexts.add('--- Page ${i + 1} ---\n$pageText');
    }
  }

  document.dispose();

  final String trimmedText = pageTexts.join('\n\n').trim();
  debugPrint(
      '[PdfService Isolate] Extraction terminée ! Longueur : ${trimmedText.length} caractères');

  return _buildPdfAnalysisMap(
    text: trimmedText,
    pageCount: totalPages,
    processedPages: pagesToProcess,
    textPageCount: textPageCount,
    imageObjectCount: _countPdfImages(pdfBytes),
  );
}

Map<String, dynamic> _buildPdfAnalysisMap({
  required String text,
  required int pageCount,
  required int processedPages,
  required int textPageCount,
  required int imageObjectCount,
}) {
  final language = _detectLanguage(text);
  final signals = _detectContentSignals(text, imageObjectCount, textPageCount);
  final aiContext = _buildAiContext(
    language: language,
    pageCount: pageCount,
    processedPages: processedPages,
    textPageCount: textPageCount,
    imageObjectCount: imageObjectCount,
    signals: signals,
  );

  return {
    'text': text,
    'pageCount': pageCount,
    'processedPages': processedPages,
    'textPageCount': textPageCount,
    'imageObjectCount': imageObjectCount,
    'detectedLanguage': language,
    'contentSignals': signals,
    'aiContext': aiContext,
  };
}

int _countPdfImages(List<int> bytes) {
  final source =
      String.fromCharCodes(bytes, 0, bytes.length.clamp(0, 2500000).toInt());
  return RegExp(r'/Subtype\s*/Image').allMatches(source).length;
}

String _detectLanguage(String text) {
  final lower = ' ${text.toLowerCase()} ';
  int fr = 0;
  int en = 0;
  const frWords = [
    ' le ',
    ' la ',
    ' les ',
    ' des ',
    ' une ',
    ' est ',
    ' sont ',
    ' dans ',
    ' avec ',
    ' pour ',
    ' qui ',
    ' que ',
    ' cette ',
    ' cours '
  ];
  const enWords = [
    ' the ',
    ' and ',
    ' is ',
    ' are ',
    ' with ',
    ' for ',
    ' this ',
    ' that ',
    ' from ',
    ' which ',
    ' lesson ',
    ' chapter ',
    ' question '
  ];
  for (final word in frWords) {
    if (lower.contains(word)) fr++;
  }
  for (final word in enWords) {
    if (lower.contains(word)) en++;
  }
  return en > fr ? 'anglais' : 'français';
}

List<String> _detectContentSignals(
    String text, int imageObjectCount, int textPageCount) {
  final lower = text.toLowerCase();
  final signals = <String>[];

  if (textPageCount == 0 && imageObjectCount > 0) {
    signals.add('PDF probablement scanné ou composé d\'images');
  } else if (imageObjectCount > 0) {
    signals.add('Contient des images ou pages illustrées');
  }

  if (RegExp(r'(^|\n)\s*[-•*]\s+', multiLine: true).hasMatch(text) ||
      RegExp(r'(^|\n)\s*\d+[\).]\s+', multiLine: true).hasMatch(text)) {
    signals.add('Notes structurées ou listes');
  }
  if (RegExp(r'\?', multiLine: true).allMatches(text).length >= 2 ||
      lower.contains('exercice') ||
      lower.contains('qcm') ||
      lower.contains('questions')) {
    signals.add('Questions ou exercices');
  }
  if (lower.contains('figure') ||
      lower.contains('schéma') ||
      lower.contains('schema') ||
      lower.contains('diagramme') ||
      lower.contains('graphique') ||
      lower.contains('tableau')) {
    signals.add('Schémas, diagrammes ou tableaux mentionnés');
  }
  if (lower.contains('définition') ||
      lower.contains('definition') ||
      lower.contains('signifie') ||
      lower.contains('désigne') ||
      lower.contains('est un') ||
      lower.contains('est une')) {
    signals.add('Définitions et notions clés');
  }
  if (signals.isEmpty) {
    signals.add(text.trim().isEmpty
        ? 'Aucun texte extractible'
        : 'Texte de cours continu');
  }
  return signals;
}

String _buildAiContext({
  required String language,
  required int pageCount,
  required int processedPages,
  required int textPageCount,
  required int imageObjectCount,
  required List<String> signals,
}) {
  return [
    'Analyse PDF locale:',
    '- Langue détectée: $language',
    '- Pages: $pageCount ($processedPages analysées)',
    '- Pages avec texte extractible: $textPageCount',
    '- Objets image détectés: $imageObjectCount',
    '- Indices de contenu: ${signals.join(', ')}',
  ].join('\n');
}
