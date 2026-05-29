import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../../core/constants/app_colors.dart';
import '../../data/local/database_helper.dart';
import '../../domain/entities/deck.dart';
import '../../data/remote/supabase_service.dart';
import '../../services/bluetooth_share_service.dart';
import '../../services/deep_link_service.dart';

class ShareScreen extends StatefulWidget {
  final Deck? deck;
  const ShareScreen({super.key, this.deck});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final BluetoothShareService _shareService = BluetoothShareService();
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void _startScan() async {
    setState(() {
      _isScanning = true;
      _scanResults = [];
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            _scanResults = results.where((r) => r.device.platformName.isNotEmpty).toList();
          });
        }
      });
    } catch (e) {
      _showSnackBar("Erreur Bluetooth : $e");
    }

    await Future.delayed(const Duration(seconds: 15));
    if (mounted) setState(() => _isScanning = false);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendDeck(BluetoothDevice device) async {
    try {
      Deck? deckToSend = widget.deck;
      
      if (deckToSend == null) {
        final userId = SupabaseService.currentUser?.id ?? "guest";
        final decksMaps = await DatabaseHelper.instance.getDecks(userId);
        if (decksMaps.isEmpty) {
          _showSnackBar("Aucun deck à envoyer");
          return;
        }
        final deckMap = decksMaps.first;
        deckToSend = Deck(
          uuid: deckMap['uuid'],
          title: deckMap['title'],
          subject: deckMap['subject'],
          level: deckMap['level'],
          createdAt: DateTime.now(),
        );
      }

      _showSnackBar("Préparation de ${deckToSend.title}...");
      final payload = await _shareService.prepareDeckPayload(deckToSend);
      
      _showSnackBar("Connexion à ${device.platformName}...");
      await _shareService.sendPayload(device, payload);
      
      _showSnackBar("Deck envoyé avec succès !");
    } catch (e) {
      _showSnackBar("Erreur d'envoi : $e");
    }
  }

  Future<void> _receiveDeck() async {
    _showSnackBar("Mode réception : Connectez-vous à cet appareil depuis l'autre téléphone.");
    _showSnackBar("Astuce : Assurez-vous que le Bluetooth est activé sur les deux appareils.");
  }

  Future<void> _shareViaSystem() async {
    if (widget.deck == null) {
      _showSnackBar("Sélectionnez d'abord un deck");
      return;
    }

    try {
      _showSnackBar("Génération du lien sécurisé...");
      final shareLink = await DeepLinkService.generateDeckLink(widget.deck!);
      
      final String shareText = "Salut ! 🚀\n\n"
          "Regarde ce deck de révision sur KALAN : '${widget.deck!.title}'\n\n"
          "Clique ici pour le réviser avec moi (ou télécharge l'app si tu ne l'as pas encore) :\n"
          "$shareLink";

      await Share.share(
        shareText,
        subject: "Révise avec moi sur KALAN : ${widget.deck!.title}",
      );
    } catch (e) {
      _showSnackBar("Erreur de partage : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Partage de Flashcards'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        actions: [
          if (_isScanning)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))))
          else
            IconButton(icon: const Icon(Icons.refresh, color: AppColors.primary), onPressed: _startScan),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            
            // Bouton Partage WhatsApp / Système
            if (widget.deck != null)
              ElevatedButton.icon(
                onPressed: _shareViaSystem,
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                label: const Text('PARTAGER VIA WHATSAPP / SMS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // Couleur WhatsApp
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
            
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 4))]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bluetooth à proximité', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A))),
                        if (widget.deck != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: Text(widget.deck!.title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _scanResults.isEmpty 
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bluetooth_disabled_rounded, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(_isScanning ? "Recherche en cours..." : "Aucun appareil détecté", style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            )
                          )
                        : ListView.builder(
                            itemCount: _scanResults.length,
                            itemBuilder: (context, index) {
                              final result = _scanResults[index];
                              final name = result.device.platformName;
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade100),
                                ),
                                child: ListTile(
                                  onTap: () => _sendDeck(result.device),
                                  leading: CircleAvatar(backgroundColor: Colors.blue.withValues(alpha: 0.1), child: const Icon(Icons.phone_android_rounded, color: Colors.blue, size: 20)),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: const Text('Appuyer pour envoyer', style: TextStyle(fontSize: 12, color: Colors.green)),
                                  trailing: const Icon(Icons.send_rounded, color: AppColors.primary, size: 18),
                                ),
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _receiveDeck, 
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('RECEVOIR')
                  )
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _showSnackBar('Choisissez un appareil dans la liste ci-dessus'), 
                    icon: const Icon(Icons.upload_rounded, color: Colors.white),
                    label: const Text('ENVOYER', style: TextStyle(color: Colors.white))
                  )
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Version Bluetooth 1.0 - KALAN Transfer', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.share_rounded, color: AppColors.primary, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('Partage Direct', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 8),
        const Text('Échange tes fiches de révision instantanément via Bluetooth ou réseaux sociaux.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5)),
      ],
    );
  }
}
