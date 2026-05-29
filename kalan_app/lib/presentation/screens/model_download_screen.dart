import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../ai/model_downloader.dart';

class ModelDownloadScreen extends StatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  double _progress = 0;
  bool _isDownloading = false;
  String _status = "Prêt à télécharger";

  void _startDownload() {
    setState(() {
      _isDownloading = true;
      _status = "Téléchargement en cours...";
    });

    ModelDownloader.downloadModel().listen(
      (progress) {
        if (!mounted) return;
        if (progress < 0) {
          setState(() {
            _isDownloading = false;
            _status = 'Erreur de téléchargement';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Échec du téléchargement. Vérifie ta connexion Wi‑Fi.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        setState(() {
          _progress = progress;
          if (progress >= 1.0) {
            _status = 'Installation terminée !';
            _isDownloading = false;
          }
        });
        if (progress >= 1.0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('IA locale installée — tu peux réviser hors ligne !')),
          );
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context, true);
          });
        }
      },
      onDone: () {
        if (mounted && _progress >= 1.0 && !_status.contains('Erreur')) {
          setState(() {
            _isDownloading = false;
            _status = 'Téléchargement terminé !';
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _status = "Erreur : $error";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de téléchargement : $error')),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.fredokaTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, size: 80, color: Color(0xFF2D6A2D)),
                  const SizedBox(height: 30),
                  const Text(
                    'IA Locale KALAN',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pour fonctionner sans internet, l\'IA locale nécessite un téléchargement unique de ~986 Mo (Wi-Fi recommandé).',
                    style: TextStyle(fontSize: 15, color: Color(0xFF555555), height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi, color: Colors.orange, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Utilisez une connexion WiFi stable pour éviter les frais mobiles.',
                            style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_isDownloading || _progress > 0) ...[
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 20,
                              backgroundColor: const Color(0xFFEEEEEE),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2D6A2D)),
                            ),
                          ),
                        ),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: const TextStyle(color: Color(0xFF2D6A2D), fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    if (_status.contains("Erreur"))
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: ElevatedButton.icon(
                          onPressed: _startDownload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D6A2D),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _startDownload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D6A2D),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Télécharger l\'IA Qwen (~986 Mo)',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Plus tard (Garder le mode Cloud)',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
