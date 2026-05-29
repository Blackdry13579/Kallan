import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../ai/model_downloader.dart';

class AIStatusIndicator extends StatefulWidget {
  const AIStatusIndicator({super.key});

  @override
  State<AIStatusIndicator> createState() => _AIStatusIndicatorState();
}

class _AIStatusIndicatorState extends State<AIStatusIndicator> {
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    setState(() => _checking = true);
    try {
      final isDownloaded = await ModelDownloader.isModelDownloaded();
      if (mounted) {
        setState(() {
          _isDownloaded = isDownloaded;
          _checking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  void _startDownload() {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    ModelDownloader.downloadModel().listen(
      (progress) {
        if (!mounted) return;
        if (progress == 1.0) {
          setState(() {
            _isDownloaded = true;
            _isDownloading = false;
            _downloadProgress = 1.0;
          });
          _showToast("IA locale Qwen2.5 prête !");
        } else if (progress < 0) {
          setState(() {
            _isDownloading = false;
          });
          _showToast("Erreur lors du téléchargement");
        } else {
          setState(() {
            _downloadProgress = progress;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
          _showToast("Erreur : $err");
        }
      },
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.psychology_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Text("IA Locale KALAN"),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Modèle : Qwen2.5 1.5B (offline)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              "Ce modèle est installé directement sur ton smartphone.",
            ),
            SizedBox(height: 8),
            Text(
              "Il te permet de créer des fiches de révision instantanément, même sans aucune connexion Internet.",
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  "Statut : Prêt à réviser offline !",
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  void _showDownloadConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cloud_download_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text("Installer l'IA Locale"),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Télécharger Qwen2.5 1.5B (~986 Mo)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              "KALAN utilise une IA locale pour te permettre de créer des fiches de révision même sans connexion Internet.",
            ),
            SizedBox(height: 8),
            Text(
              "Pour une expérience optimale, nous te conseillons d'être connecté à un réseau Wi-Fi pour le téléchargement.",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Plus tard"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _startDownload();
            },
            child: const Text("Télécharger maintenant"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
        ),
      );
    }

    if (_isDownloaded) {
      return IconButton(
        tooltip: "IA locale prête pour le offline",
        icon: const Icon(Icons.cloud_done_rounded, color: AppColors.primary, size: 26),
        onPressed: _showStatusDialog,
      );
    }

    if (_isDownloading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "${(_downloadProgress * 100).toInt()}%",
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // Pas téléchargé
    return IconButton(
      tooltip: "Télécharger l'IA locale pour le offline",
      icon: const Icon(Icons.cloud_download_rounded, color: Colors.grey, size: 26),
      onPressed: _showDownloadConfirmDialog,
    );
  }
}
