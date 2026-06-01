import 'package:flutter/material.dart';

/// Fond global de l'app : image fondkalan.png (beige + motifs africains).
/// Injecté via MaterialApp.builder → visible sur tous les 36 écrans.
class KalanBackground extends StatelessWidget {
  final Widget child;
  const KalanBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/fondkalan.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}
