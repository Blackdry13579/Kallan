import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelDownloader {
  static const String _modelUrl =
      'https://github.com/Blackdry13579/Gemma3-1B/releases/download/V1.0/gemma3-1b-it-int4.task';
  static const String _fileName    = 'gemma3-1b-it-int4.task';
  static const String _tmpFileName = 'gemma3-1b-it-int4.task.tmp';

  // Nombre de connexions parallèles
  static const int _numWorkers = 4;

  // ─────────────────────────────────────────────────────────────────────────
  // API publique
  // ─────────────────────────────────────────────────────────────────────────

  /// Importe le modèle depuis le stockage externe s'il a été copié manuellement.
  static Future<bool> importModelFromExternalStorage() async {
    if (kIsWeb) return false;
    try {
      final docsDir   = await getApplicationDocumentsDirectory();
      final target    = File('${docsDir.path}/$_fileName');
      final prefs     = await SharedPreferences.getInstance();

      if (await target.exists()) {
        if (prefs.getString('installed_model_file_name') != _fileName) {
          await prefs.setString('installed_model_file_name', _fileName);
        }
        return true;
      }

      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final source = File('${extDir.path}/$_fileName');
        if (await source.exists()) {
          debugPrint('[ModelDownloader] Modèle externe détecté → copie interne...');
          await source.copy(target.path);
          await prefs.setString('installed_model_file_name', _fileName);
          debugPrint('[ModelDownloader] ✅ Importation réussie.');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[ModelDownloader] importFromExternal: $e');
    }
    return false;
  }

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
    final ctrl = StreamController<double>();
    _downloadParallel(ctrl);
    return ctrl.stream;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Implémentation interne
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _downloadParallel(StreamController<double> ctrl) async {
    try {
      final docsDir   = await getApplicationDocumentsDirectory();
      final finalFile = File('${docsDir.path}/$_fileName');
      final prefs     = await SharedPreferences.getInstance();

      // Déjà installé ?
      if (await finalFile.exists()) {
        if (prefs.getString('installed_model_file_name') != _fileName) {
          await prefs.setString('installed_model_file_name', _fileName);
        }
        ctrl.add(1.0);
        ctrl.close();
        return;
      }

      // Taille totale via HEAD
      final totalBytes = await _getFileSize();
      if (totalBytes <= 0) {
        // Fallback : téléchargement en flux simple
        debugPrint('[ModelDownloader] Taille inconnue → flux simple');
        await _downloadSingleStream(ctrl, docsDir, prefs, finalFile);
        return;
      }

      debugPrint('[ModelDownloader] $totalBytes octets → $_numWorkers connexions parallèles');

      // Fichiers de parties
      final parts = List.generate(
        _numWorkers,
        (i) => File('${docsDir.path}/$_fileName.part.$i'),
      );

      // Taille de chaque partie
      final chunkSize = (totalBytes / _numWorkers).ceil();
      final expectedSizes = List.generate(_numWorkers, (i) {
        final start = i * chunkSize;
        final end   = min((i + 1) * chunkSize, totalBytes);
        return end - start;
      });

      // Octets déjà téléchargés par partie (reprise)
      final alreadyDone = <int>[];
      for (int i = 0; i < _numWorkers; i++) {
        final f = parts[i];
        alreadyDone.add(await f.exists() ? await f.length() : 0);
      }

      // Suivi de progression (partagé entre les workers)
      final progress = List<int>.from(alreadyDone);

      void emit() {
        if (ctrl.isClosed) return;
        final done = progress.fold<int>(0, (s, b) => s + b);
        ctrl.add((done / totalBytes).clamp(0.0, 1.0));
      }

      // Progression initiale si reprise
      if (alreadyDone.any((b) => b > 0)) emit();

      // Lance les workers en parallèle
      final futures = <Future<void>>[];
      for (int i = 0; i < _numWorkers; i++) {
        if (alreadyDone[i] >= expectedSizes[i]) continue; // Partie déjà complète

        final chunkStart  = i * chunkSize;
        final chunkEnd    = chunkStart + expectedSizes[i] - 1;
        final resumeBytes = alreadyDone[i];

        futures.add(_downloadChunk(
          rangeStart: chunkStart + resumeBytes,
          rangeEnd:   chunkEnd,
          partFile:   parts[i],
          appendMode: resumeBytes > 0,
          onProgress: (bytes) {
            progress[i] = resumeBytes + bytes;
            emit();
          },
        ));
      }

      await Future.wait(futures);

      // Vérification de complétude
      for (int i = 0; i < _numWorkers; i++) {
        final actual = await parts[i].length();
        if (actual < expectedSizes[i]) {
          throw Exception('Partie $i incomplète : $actual/${expectedSizes[i]} octets');
        }
      }

      // Fusion des parties
      debugPrint('[ModelDownloader] Fusion des parties...');
      final tmpFile = File('${docsDir.path}/$_tmpFileName');
      final sink    = tmpFile.openWrite();
      for (final part in parts) {
        await sink.addStream(part.openRead());
      }
      await sink.close();

      // Nettoyage des parties
      for (final part in parts) {
        try { await part.delete(); } catch (_) {}
      }

      // Renommage et enregistrement
      await tmpFile.rename(finalFile.path);
      await prefs.setString('installed_model_file_name', _fileName);

      debugPrint('[ModelDownloader] ✅ Téléchargement terminé.');
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

  /// Télécharge un segment (bytes=$rangeStart-$rangeEnd) dans [partFile].
  static Future<void> _downloadChunk({
    required int rangeStart,
    required int rangeEnd,
    required File partFile,
    required bool appendMode,
    required void Function(int bytesReceived) onProgress,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_modelUrl));
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$rangeStart-$rangeEnd');

      final response = await request.close();

      if (response.statusCode != HttpStatus.partialContent &&
          response.statusCode != HttpStatus.ok) {
        throw Exception('HTTP ${response.statusCode} '
            '(bytes=$rangeStart-$rangeEnd)');
      }

      final sink     = partFile.openWrite(
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

  /// HEAD pour obtenir la taille totale du fichier.
  static Future<int> _getFileSize() async {
    final client = HttpClient();
    try {
      final req  = await client.headUrl(Uri.parse(_modelUrl));
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

  /// Fallback : flux unique avec reprise (quand la taille est inconnue).
  static Future<void> _downloadSingleStream(
    StreamController<double> ctrl,
    Directory docsDir,
    SharedPreferences prefs,
    File finalFile,
  ) async {
    try {
      final tmpFile  = File('${docsDir.path}/$_tmpFileName');
      int startByte  = await tmpFile.exists() ? await tmpFile.length() : 0;

      final client  = HttpClient();
      final request = await client.getUrl(Uri.parse(_modelUrl));
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
      final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
      if (contentRange != null) {
        final m = RegExp(r'/(\d+)$').firstMatch(contentRange);
        if (m != null) totalBytes = int.parse(m.group(1)!);
      }
      if (totalBytes == 0 && response.contentLength > 0) {
        totalBytes = startByte + response.contentLength;
      }

      if (totalBytes > 0 && startByte > 0) ctrl.add(startByte / totalBytes);

      final sink      = tmpFile.openWrite(
        mode: startByte > 0 ? FileMode.append : FileMode.write,
      );
      int downloaded  = startByte;

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
      await prefs.setString('installed_model_file_name', _fileName);

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
