import 'package:flutter/material.dart';
import '../brand.dart';
import '../theme.dart';

/// Conditions d'utilisation et politique de confidentialité.
/// MODÈLES À FAIRE VALIDER par un juriste avant la mise en ligne (droit béninois, protection des données).
class LegalScreen extends StatelessWidget {
  final bool privacy;
  const LegalScreen({super.key, this.privacy = false});

  static final _terms = [
    ['1. Objet', '${Brand.name} est une plateforme qui met en relation des vendeurs (boutiques) et des acheteurs. ${Brand.name} n\'est pas vendeur des produits proposés par les boutiques.'],
    ['2. Compte', 'Tu dois fournir un numéro de téléphone valide et des informations exactes. Tu es responsable de l\'usage de ton compte. Tu peux le supprimer à tout moment depuis ton profil.'],
    ['3. Publications', 'Les boutiques sont responsables de leurs produits, prix, photos et descriptions. Sont interdits : produits illicites, contrefaçons, contenus trompeurs, haineux ou violents, ainsi que toute arnaque. Nous pouvons retirer une publication ou suspendre une boutique.'],
    ['4. Commandes et paiements', 'Les paiements se font par mobile money. Une commande est confirmée après paiement. ${Brand.name} prélève une commission de ${(Brand.commissionRate * 100).round()} % sur les ventes livrées.'],
    ['5. Annulation et remboursement', 'Tu peux annuler une commande tant qu\'elle n\'est pas confirmée par la boutique ; elle est alors remboursée. Une boutique qui annule une commande déjà payée la rembourse également.'],
    ['6. Litiges', 'En cas de problème, contacte d\'abord la boutique. Tu peux nous signaler une boutique depuis son profil : ${Brand.supportEmail}.'],
    ['7. Responsabilité', '${Brand.name} fournit la plateforme « en l\'état » et ne garantit pas l\'absence d\'interruption. Notre responsabilité est limitée dans les conditions prévues par la loi.'],
    ['8. Modifications', 'Ces conditions peuvent évoluer ; en cas de changement important, tu en seras informé(e) dans l\'application.'],
  ];

  static final _privacy = [
    ['Données collectées', 'Nom, numéro de téléphone, adresses de livraison, commandes, avis, et contenus que tu publies (photos, vidéos, textes). Pour une boutique : nom, description, zone, téléphone.'],
    ['Utilisation', 'Faire fonctionner l\'application (commandes, paiements, notifications), sécuriser les comptes, lutter contre la fraude et améliorer le service.'],
    ['Partage', 'Le vendeur reçoit ton nom, ton numéro et ton adresse (si livraison) uniquement après une commande. Les prestataires de paiement mobile money reçoivent le strict nécessaire pour traiter le paiement. Nous ne vendons pas tes données.'],
    ['Conservation', 'Tes données sont conservées tant que ton compte existe. La suppression du compte efface tes données personnelles, sous réserve des obligations légales de conservation (comptabilité, paiements).'],
    ['Tes droits', 'Tu peux accéder à tes données, les corriger ou les supprimer depuis ton profil, ou en écrivant à ${Brand.supportEmail}.'],
    ['Stockage sur ton téléphone', 'L\'application garde sur ton téléphone ton panier, tes commandes et tes publications afin de fonctionner hors connexion.'],
  ];

  @override
  Widget build(BuildContext context) {
    final items = privacy ? _privacy : _terms;
    return Scaffold(
      appBar: AppBar(title: Text(privacy ? 'Confidentialité' : 'Conditions d\'utilisation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListView(padding: EdgeInsets.all(18), children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(10)),
          child: Text('Texte type à faire relire par un juriste avant la publication de l\'application.', style: TextStyle(color: C.sub, fontSize: 12.5)),
        ),
        SizedBox(height: 14),
        for (final i in items) ...[
          Text(i[0], style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text(i[1], style: TextStyle(fontSize: 15, height: 1.45)),
          SizedBox(height: 16),
        ],
      ]),
    );
  }
}
