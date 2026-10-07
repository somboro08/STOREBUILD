import 'dart:typed_data';
import 'package:flutter/material.dart';

enum PostType { text, image, video }

const categories = ['Sacs', 'Fournitures scolaires', 'Chaussures', 'Électronique', 'Maison', 'Mode', 'Beauté', 'Alimentation', 'Autres'];

class Post {
  final String id;
  final PostType type;
  final String time, text;
  final String? title, quote, category;
  final int? price; // FCFA
  final List<String> reactions;
  final int reactionCount, forwards;
  final Color color;
  final bool bold, sold;
  final Uint8List? bytes; // image choisie par le vendeur
  const Post({
    required this.id,
    required this.type,
    required this.time,
    required this.text,
    this.title,
    this.quote,
    this.category,
    this.price,
    this.reactions = const [],
    this.reactionCount = 0,
    this.forwards = 0,
    this.color = const Color(0xFF37474F),
    this.bold = false,
    this.sold = false,
    this.bytes,
  });
  bool get isProduct => price != null && title != null && type != PostType.text;
}

class Channel {
  final String id, created;
  String name, description, category, zone, phone, preview, time;
  int followers;
  final int unread;
  Color color;
  final bool mine;
  bool followed;
  final List<Post> posts;
  Channel({
    required this.id,
    required this.name,
    this.preview = '',
    this.time = '',
    this.created = '',
    required this.followers,
    this.unread = 0,
    required this.color,
    List<Post>? posts,
    this.description = '',
    this.category = '',
    this.zone = '',
    this.phone = '',
    this.mine = false,
    this.followed = true,
  }) : posts = posts ?? [];
}

String nowHm() {
  final n = DateTime.now();
  return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
}

String fmtInt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

const _hello =
    '😍Hello hello la famille 👋 Pas de paiements momo ni de Livraison Chez nous actuellement svp❌ Donc Faites très attention Aux faux comptes.C\'est des Arnaqueurs❌\n\n'
    '👉(Nous sommes à Calavi carrefour bidossessi, sikecodji von mafri et Porto-Novo carrefour gbodje)\n'
    '👉CALAVI carrefour Bidossessi juste avant l\'ex supermarché Azima en prenant le trafic local directement kpota nous sommes dans la maison des entreprises portail bleu (maison de la banque ou là où on vend des carreaux ou objets de construction) en face de la boutique BAJAJ qui est avant ORCA DECO vous verrez mon affiche au dehors pour vous orienter ou mon enseigne en haut du portail😍 ( 0197669861 Appel direct uniquement)\n\n'
    '👉Sikecodji von mafri 4eme immeuble à droite vous verrez les enseignes la ( 01…';

final allChannels = <Channel>[
  Channel(
    id: 'martistore',
    name: 'MARTISTORE OFFICIEL',
    preview: 'Mes clients sont les plus heureux actuelle…',
    time: '15:53',
    created: '17/04/2025',
    followers: 99563,
    description: 'Fournitures scolaires, sacs, chaussures et accessoires à petits prix. Pas de livraison, retrait en boutique.',
    category: 'Fournitures scolaires',
    zone: 'Calavi · Sikècodji · Porto-Novo',
    color: const Color(0xFF9E8B7D),
    posts: [
      Post(id: 'p1', category: 'Électronique', type: PostType.image, time: '08:33', color: Color(0xFF0E8F83), title: 'Lumière LED + trépied', price: 6500,
          text: 'Cette lumière led de la gloire glorieuse avec trépied et support téléphone disponible dans toutes nos boutiques à 6500f cadeau 🥹🥹',
          reactions: ['🙏', '❤️', '👍', '😄'], reactionCount: 5, forwards: 34),
      Post(id: 'p2', type: PostType.text, time: '09:46', text: _hello,
          reactions: ['❤️', '👍', '😂', '🙏'], reactionCount: 9, forwards: 72),
      Post(id: 'p3', type: PostType.text, time: '12:03', quote: '1200f mes tata 😎',
          text: '❌ fini à calavi je vais republier si ça revient là-bas\n❌❌'),
      Post(id: 'p4', category: 'Fournitures scolaires', type: PostType.image, time: '07:57', color: Color(0xFFE0B72E), title: 'Cahiers J\'aime l\'Afrique', price: 1000,
          text: 'Cahier qui va durer toute l\'année scolaire sans se chiffonner, quand on voit ont sait 🥹🥹', forwards: 17),
      Post(id: 'p5', category: 'Fournitures scolaires', type: PostType.image, time: '07:59', color: Color(0xFFC62828), title: 'Cahiers J\'aime l\'Afrique', price: 1000,
          text: 'Nos Cashiers J\'aime l\'Afrique dans toutes nos boutiques et même disponible à la boutique de calavi carrefour Bidossessi 😍😍\n\nLes prix\n\n👉100 pages à 1000f le packet de 10 unités et 16000f le carton de 20 packet\n\n👉200 pages à 1000f le pack de 10 unités et 16000f le carton de 10 paquets'),
      Post(id: 'p6', category: 'Sacs', type: PostType.video, time: '18:00', color: Color(0xFF2B3A55), title: 'Sac 1200f', price: 1200,
          text: 'Sac 1200f cadeau deh🤣', reactions: ['👍', '❤️', '🙏', '❓'], reactionCount: 26, forwards: 183),
      Post(id: 'p7', category: 'Sacs', type: PostType.image, time: '16:41', color: Color(0xFF546E7A), title: 'Sac secondaire', price: 3500,
          text: 'Sac secondaire disponible à 3500f déjà à calavi et sikecodji 😎😎😂',
          reactions: ['❤️', '😢', '👍', '😮'], reactionCount: 23, forwards: 238),
      Post(id: 'p8', category: 'Chaussures', type: PostType.image, time: '00:40', color: Color(0xFF6D5A4A), title: 'Chaussures enfants', price: 2000,
          text: '2000f chaussures de qualité pour enfants 😍',
          reactions: ['❤️', '👍', '😂', '😢'], reactionCount: 17, forwards: 77),
      Post(id: 'p9', category: 'Sacs', type: PostType.image, time: '07:20', color: Color(0xFF7A7F86), title: 'Sac 1200f', price: 1200, sold: true,
          text: '❌ Ce sac de 1200f est terminé à Cotonou et calavi pour le moment mais ça va revenir dans l\'après midi ils ont envoyé une grande quantité à porto par erreur et ils vont renvoyer\n\nNB: c\'est à Porto-Novo car c\'est ce matin ils vont commencer à vendre 😫',
          reactions: ['😭', '❤️', '😢', '👍'], reactionCount: 27, forwards: 45),
      Post(id: 'p10', category: 'Sacs', type: PostType.image, time: '19:28', color: Color(0xFF8E6BA8), title: 'Sac d\'école secondaire 2enQ', price: 1200,
          text: 'Sac d\'école secondaire 2enQ petit prix sur vous à 1200f waaabaaaa min🥹🥹🥹',
          reactions: ['❤️', '👍', '😢', '😂'], reactionCount: 44, forwards: 286),
      Post(id: 'p11', type: PostType.text, time: '22:50', bold: true,
          text: 'Voici encore quelques fournitures que vous pouvez trouver demain dans nos boutiques 👇👇\n\n'
              'Crayon à papier jaune 200f ✅\n\nArdoise petit 150f la dz a 1500✅\n\nArdoise moyen 250f la dz a 2500f✅\n\n'
              'Ardoise grand 350f la dz a 3500f ✅\n\nArdoise avec bordure en plastique à 300f la dz a 3000f ✅\n\n'
              'Colle écolier 75f unité la dz a 600f ✅\n\nBic TRIO PLUS bleu /rouge/noir boîte de 50 pcs a 3000f 👉unité 100f ✅',
          reactions: ['👍', '❤️', '😄', '😂'], reactionCount: 6, forwards: 6),
    ],
  ),
  Channel(id: 'anglais', name: 'Apprendre L\'anglais', preview: 'Phrases du quotidien', time: '15:26', followers: 12000, unread: 137, color: Color(0xFFF5F5F5)),
  Channel(id: 'emploi', name: 'BENIN EMPLOI+', preview: '🇧🇯🔥 RECRUTEMENT URGENT – RC…', time: '08:42', followers: 45000, unread: 109, color: Color(0xFF1ED5D0)),
  Channel(id: 'web', name: 'Web Development - HTML, CSS & Jav…', preview: '🌐 Web Development Roadmap — Par…', time: 'Hier', followers: 8000, unread: 24, color: Color(0xFF2A1A12)),
  Channel(id: 'anpe', name: 'AnpE Bénin | Agence nationale…', preview: 'Aviculture : L\'AnpE et Azôli réceptionnent …', time: '02/10/2026', followers: 30000, unread: 2, color: Color(0xFFFFFFFF)),
  Channel(id: 'nordtv', name: 'NORD BÉNIN TV', preview: 'LANCEMENT OFFICIEL DU PROJET S…', time: '02/10/2026', followers: 20000, unread: 22, color: Color(0xFFFFFFFF)),
  Channel(id: 'netflix', name: 'Netflix', preview: 'NVR TOO LATE CUB 🥵🥵🥵🥵 AWW…', time: '29/09/2026', followers: 500000, unread: 56, color: Color(0xFF000000)),
  Channel(
    id: 'techbj', name: 'TechShop Cotonou', preview: 'Chargeur rapide 20W original 3000f ⚡', time: '10:20', followers: 3200,
    color: const Color(0xFF1565C0), followed: false, category: 'Électronique', zone: 'Cotonou · Ganhi',
    description: 'Accessoires téléphone, écouteurs, chargeurs.',
    posts: [
      Post(id: 't1', type: PostType.image, time: '10:12', color: Color(0xFF283593), title: 'Écouteurs Bluetooth', price: 4500, category: 'Électronique',
          text: 'Écouteurs Bluetooth batterie 20h, 4500f 🎧', reactions: ['👍', '🔥'], reactionCount: 12, forwards: 8),
      Post(id: 't2', type: PostType.image, time: '10:20', color: Color(0xFF00695C), title: 'Chargeur rapide 20W', price: 3000, category: 'Électronique',
          text: 'Chargeur rapide 20W original 3000f ⚡'),
    ],
  ),
  Channel(
    id: 'mode', name: 'Mode Africaine', preview: 'Pagne wax 6 yards 5000f', time: '09:05', followers: 8700,
    color: const Color(0xFFAD1457), followed: false, category: 'Mode', zone: 'Cotonou · Dantokpa',
    description: 'Pagnes, tenues et accessoires de mode.',
    posts: [
      Post(id: 'm1', type: PostType.image, time: '09:05', color: Color(0xFFEF6C00), title: 'Pagne wax 6 yards', price: 5000, category: 'Mode',
          text: 'Pagne wax 6 yards qualité supérieure 5000f 🌍', reactions: ['❤️', '😍'], reactionCount: 31, forwards: 20),
    ],
  ),
];
