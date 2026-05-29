import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_model_config.dart';

class ModelDownloader {
  static const int _numWorkers = 4;

  // ─────────────────────────────────────────────────────────────────────────
  // API publique
  // ─────────────────────────────────────────────────────────────────────────

<<<<<<< HEAD
  /// Importe le modèle depuis le stockage externe s'il a été copié manuellement.
  static Future<bool> importModelFromExternalStorage() async {
    if (kIsWeb) return false;
=======
  /// Retourne le chemin complet du fichier de modèle s'il est installé, sinon null.
  static Future<String?> getModelPath(LocalModelConfig config) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final file = File('${docsDir.path}/${config.fileName}');
    return file.existsSync() ? file.path : null;
  }

  /// Vérifie si Qwen GGUF est installé (modèle cible).
  static Future<bool> isQwenInstalled() async {
    return _isFilePresent(qwen25LocalModel.fileName);
  }

  /// Vérifie si Gemma est installé (fallback).
  static Future<bool> isGemmaInstalled() async {
    if (await _isFilePresent(gemmaLocalModel.fileName)) return true;
>>>>>>> fb001a99013dd72570652afc58ecc80e19b64612
    try {
      return await FlutterGemmaPlugin.instance.modelManager.isModelInstalled;
    } catch (_) {
      return false;
    }
  }

  /// Vérifie si au moins un modèle offline est disponible (Qwen ou Gemma).
  /// Utilisé par les écrans pour afficher le badge "IA offline prête".
  static Future<bool> isModelDownloaded() async {
    if (await isQwenInstalled()) return true;
    return isGemmaInstalled();
  }

  /// Importe un modèle depuis le stockage externe s'il a été copié manuellement.
  static Future<bool> importModelFromExternalStorage(
      [LocalModelConfig config = qwen25LocalModel]) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final target = File('${docsDir.path}/${config.fileName}');
      final prefs = await SharedPreferences.getInstance();

      if (await target.exists()) {
        await prefs.setString('installed_model_id', config.id);
        return true;
      }

      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final source = File('${extDir.path}/${config.fileName}');
        if (await source.exists()) {
          debugPrint('[ModelDownloader] Modèle externe détecté → copie interne...');
          await source.copy(target.path);
          await prefs.setString('installed_model_id', config.id);
          debugPrint('[ModelDownloader] ✅ Importation réussie.');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[ModelDownloader] importFromExternal: $e');
    }
    return false;
  }

<<<<<<< HEAD
  /// Vérifie si le modèle est installé.
  static Future<bool> isModelDownloaded() async {
    if (kIsWeb) return false;
    if (await importModelFromExternalStorage()) return true;
    try {
      return await FlutterGemmaPlugin.instance.modelManager.isModelInstalled;
    } catch (_) {
      return false;
    }
  }

  /// Téléchargement avec N connexions parallèles et reprise automatique.
  ///
  /// Émet des valeurs 0.0 → 1.0 (progression).
  /// Émet -1.0 en cas d'erreur.
  static Stream<double> downloadModel() {
    if (kIsWeb) {
      return Stream<double>.fromIterable([-1.0]);
    }
=======
  /// Télécharge un modèle avec N connexions parallèles et reprise automatique.
  /// Émet 0.0 → 1.0 (progression), -1.0 en cas d'erreur.
  /// Par défaut télécharge Qwen2.5 1.5B Q4_K_M.
  static Stream<double> downloadModel(
      [LocalModelConfig config = qwen25LocalModel]) {
>>>>>>> fb001a99013dd72570652afc58ecc80e19b64612
    final ctrl = StreamController<double>();
    _downloadParallel(ctrl, config);
    return ctrl.stream;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Implémentation interne
  // ─────────────────────────────────────────────────────────────────────────

  static Future<bool> _isFilePresent(String fileName) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      return File('${docsDir.path}/$fileName').existsSync();
    } catch (_) {
      return false;
    }
  }

  static Future<void> _downloadParallel(
      StreamController<double> ctrl, LocalModelConfig config) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final finalFile = File('${docsDir.path}/${config.fileName}');
      final prefs = await SharedPreferences.getInstance();

      if (await finalFile.exists()) {
        await prefs.setString('installed_model_id', config.id);
        ctrl.add(1.0);
        ctrl.close();
        return;
      }

      final totalBytes = await _getFileSize(config.downloadUrl);
      // Sanity check: model files are at least 50 MB — anything smaller means
      // we got a redirect page or error body instead of a real Content-Length.
      if (totalBytes <= 0 || totalBytes < 50 * 1024 * 1024) {
        debugPrint('[ModelDownloader] Taille inconnue ou invalide ($totalBytes) → flux simple');
        await _downloadSingleStream(ctrl, docsDir, prefs, finalFile, config);
        return;
      }

      debugPrint(
          '[ModelDownloader] $totalBytes octets → $_numWorkers connexions parallèles');

      final parts = List.generate(
        _numWorkers,
        (i) => File('${docsDir.path}/${config.fileName}.part.$i'),
      );

      final chunkSize = (totalBytes / _numWorkers).ceil();
      final expectedSizes = List.generate(_numWorkers, (i) {
        final start = i * chunkSize;
        final end = min((i + 1) * chunkSize, totalBytes);
        return end - start;
      });

      final alreadyDone = <int>[];
      for (int i = 0; i < _numWorkers; i++) {
        final f = parts[i];
        alreadyDone.add(await f.exists() ? await f.length() : 0);
      }

      final progress = List<int>.from(alreadyDone);

      void emit() {
        if (ctrl.isClosed) return;
        final done = progress.fold<int>(0, (s, b) => s + b);
        ctrl.add((done / totalBytes).clamp(0.0, 1.0));
      }

      if (alreadyDone.any((b) => b > 0)) emit();

      final futures = <Future<void>>[];
      for (int i = 0; i < _numWorkers; i++) {
        if (alreadyDone[i] >= expectedSizes[i]) continue;

        final chunkStart = i * chunkSize;
        final chunkEnd = chunkStart + expectedSizes[i] - 1;
        final resumeBytes = alreadyDone[i];

        futures.add(_downloadChunk(
          url: config.downloadUrl,
          rangeStart: chunkStart + resumeBytes,
          rangeEnd: chunkEnd,
          partFile: parts[i],
          appendMode: resumeBytes > 0,
          onProgress: (bytes) {
            progress[i] = resumeBytes + bytes;
            emit();
          },
        ));
      }

      await Future.wait(futures);

      for (int i = 0; i < _numWorkers; i++) {
        final actual = await parts[i].length();
        if (actual < expectedSizes[i]) {
          throw Exception('Partie $i incomplète : $actual/${expectedSizes[i]}');
        }
      }

      debugPrint('[ModelDownloader] Fusion des parties...');
      final tmpFile = File('${docsDir.path}/${config.tmpFileName}');
      final sink = tmpFile.openWrite();
      for (final part in parts) {
        await sink.addStream(part.openRead());
      }
      await sink.close();

      for (final part in parts) {
        try {
          await part.delete();
        } catch (_) {}
      }

      await tmpFile.rename(finalFile.path);
      await prefs.setString('installed_model_id', config.id);

      debugPrint('[ModelDownloader] ✅ Téléchargement terminé : ${config.displayName}');
      ctrl.add(1.0);
      ctrl.close();
    } catch (e) {
      debugPrint('[ModelDownloader] Erreur parallèle : $e');
      if (!ctrl.isClosed) {
        ctrl.add(-1.0);
        ctrl.close();
      }
    }
  }

  static Future<void> _downloadChunk({
    required String url,
    required int rangeStart,
    required int rangeEnd,
    required File partFile,
    required bool appendMode,
    required void Function(int bytesReceived) onProgress,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers
          .set(HttpHeaders.rangeHeader, 'bytes=$rangeStart-$rangeEnd');

      final response = await request.close();

      if (response.statusCode != HttpStatus.partialContent &&
          response.statusCode != HttpStatus.ok) {
        throw Exception(
            'HTTP ${response.statusCode} (bytes=$rangeStart-$rangeEnd)');
      }

      final sink = partFile.openWrite(
        mode: appendMode ? FileMode.append : FileMode.write,
      );
      int downloaded = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress(downloaded);
      }

      await sink.flush();
      await sink.close();
    } finally {
      client.close();
    }
  }

  static Future<int> _getFileSize(String url) async {
    final client = HttpClient();
    try {
      final req = await client.headUrl(Uri.parse(url));
      final resp = await req.close();
      await resp.drain<void>();
      return resp.contentLength > 0 ? resp.contentLength : 0;
    } catch (e) {
      debugPrint('[ModelDownloader] HEAD échoué : $e');
      return 0;
    } finally {
      client.close();
    }
  }

  static Future<void> _downloadSingleStream(
    StreamController<double> ctrl,
    Directory docsDir,
    SharedPreferences prefs,
    File finalFile,
    LocalModelConfig config,
  ) async {
    try {
      final tmpFile = File('${docsDir.path}/${config.tmpFileName}');
      int startByte = await tmpFile.exists() ? await tmpFile.length() : 0;

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(config.downloadUrl));
      if (startByte > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$startByte-');
      }

      final response = await request.close();

      if (startByte > 0 && response.statusCode == HttpStatus.ok) {
        startByte = 0;
        if (await tmpFile.exists()) await tmpFile.delete();
      }

      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        client.close();
        ctrl.add(-1.0);
        ctrl.close();
        return;
      }

      int totalBytes = 0;
      final contentRange =
          response.headers.value(HttpHeaders.contentRangeHeader);
      if (contentRange != null) {
        final m = RegExp(r'/(\d+)$').firstMatch(contentRange);
        if (m != null) totalBytes = int.parse(m.group(1)!);
      }
      if (totalBytes == 0 && response.contentLength > 0) {
        totalBytes = startByte + response.contentLength;
      }

      if (totalBytes > 0 && startByte > 0) ctrl.add(startByte / totalBytes);

      final sink = tmpFile.openWrite(
        mode: startByte > 0 ? FileMode.append : FileMode.write,
      );
      int downloaded = startByte;

      await for (final chunk in response) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (totalBytes > 0 && !ctrl.isClosed) {
          ctrl.add((downloaded / totalBytes).clamp(0.0, 1.0));
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      await tmpFile.rename(finalFile.path);
      await prefs.setString('installed_model_id', config.id);

      ctrl.add(1.0);
      ctrl.close();
    } catch (e) {
      debugPrint('[ModelDownloader] Erreur flux simple : $e');
      if (!ctrl.isClosed) {
        ctrl.add(-1.0);
        ctrl.close();
      }
    }
  }
}
