import 'package:flutter/foundation.dart';
import 'package:llamadart/llamadart.dart';
import 'local_llm_engine.dart';

class LlamadartEngine implements LocalLlmEngine {
  LlamaEngine? _engine;
  String? _loadedPath;

  @override
  Future<void> loadModel(String modelPath) async {
    if (_loadedPath == modelPath && _engine != null) return;
    await dispose();
    debugPrint('[LlamadartEngine] Chargement du modèle : $modelPath');
    _engine = LlamaEngine(LlamaBackend());
    await _engine!.loadModel(modelPath);
    _loadedPath = modelPath;
    debugPrint('[LlamadartEngine] ✅ Modèle chargé.');
  }

  @override
  Future<String> generateText(String prompt, {int maxTokens = 512}) async {
    final engine = _engine;
    if (engine == null || _loadedPath == null) {
      throw StateError('Modèle non chargé — appelle loadModel() d\'abord.');
    }

    final buffer = StringBuffer();
    int tokenCount = 0;

    await for (final token in engine.generate(prompt)) {
      buffer.write(token);
      tokenCount++;
      if (tokenCount >= maxTokens) break;
    }

    return buffer.toString();
  }

  @override
  Future<void> dispose() async {
    if (_engine != null) {
      await _engine!.dispose();
      _engine = null;
      _loadedPath = null;
      debugPrint('[LlamadartEngine] Modèle déchargé.');
    }
  }
}
