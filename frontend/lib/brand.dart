/// Identité et réglages de l'app : modifie ici le nom, le domaine, les taux, etc.
class Brand {
  static const name = 'Whatstore';
  static const domain = 'whatstore.store';
  static const baseUrl = 'https://$domain';
  static const tagline = 'Achète et vends facilement, avec paiement mobile money.';

  /// Mets false avant la mise en ligne : retire toutes les données de démo.
  static const demoData = true;

  /// URL de ton API (ex. https://api.whatstore.store). Vide = mode 100 % local (hors-ligne).
  static const apiBaseUrl = '';

  /// Indicatif pays pour les appels / WhatsApp (Bénin = 229).
  static const countryCode = '229';

  /// Commission prélevée sur les ventes (0.05 = 5 %) et seuil minimum de retrait (FCFA).
  static const commissionRate = 0.05;
  static const minPayout = 1000;

  /// Numéros ayant accès à l'espace administration (modération, vérification des boutiques).
  static const adminPhones = <String>[];

  /// Durée d'une réservation en magasin (heures) — même valeur que RESERVATION_HOURS côté API.
  static const reservationHours = 24;

  static const supportPhone = '+22901000000';
  static const supportEmail = 'support@whatstore.store';
}
