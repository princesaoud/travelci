# TravelCI - Plateforme de réservation de logements

Application Flutter pour la réservation de logements en Côte d'Ivoire (MVP).

## 🚀 Fonctionnalités

### Pour les Clients
- 🔐 Authentification (inscription/connexion)
- 🏠 Recherche de logements par ville, type, prix
- 📱 Détails des logements avec galerie photos
- 📅 Réservation avec sélection de dates
- 📋 Gestion des réservations (en attente, acceptées, refusées)

### Pour les Propriétaires
- 📊 Tableau de bord avec statistiques
- 🏘️ Gestion des logements (ajout, modification)
- 📨 Gestion des demandes de réservation (accepter/refuser)
- 📈 Vue d'ensemble des réservations

## 🛠️ Technologies

- **Flutter** 3.6.0+
- **Riverpod** - Gestion d'état
- **GoRouter** - Navigation
- **Table Calendar** - Sélection de dates
- **Intl** - Formatage XOF et dates

## 📦 Installation

1. Cloner le projet
```bash
git clone <repository-url>
cd travelci
```

2. Installer les dépendances
```bash
flutter pub get
```

3. Lancer l'application
```bash
flutter run
```

## 🎯 Utilisation

### Comptes de démonstration

**Client:**
- Email: `client@example.com`
- Mot de passe: `password`

**Propriétaire:**
- Email: `owner@example.com`
- Mot de passe: `password`

### Navigation

L'application détecte automatiquement le rôle de l'utilisateur et affiche l'interface appropriée:
- **Client** → Accueil avec recherche de logements
- **Propriétaire** → Tableau de bord avec gestion des logements

## 📱 Écrans

### Client
- `/login` - Connexion
- `/register` - Inscription
- `/` - Accueil avec recherche
- `/property/:id` - Détails d'un logement
- `/bookings` - Mes réservations

### Propriétaire
- `/` - Tableau de bord
- `/owner/property/new` - Ajouter un logement
- `/owner/property/:id` - Modifier un logement
- `/owner/bookings` - Demandes de réservation

## 🏗️ Architecture

```
lib/
├── core/
│   ├── models/          # Modèles de domaine
│   ├── providers/       # Providers Riverpod
│   ├── services/        # Services (mock data)
│   ├── utils/           # Utilitaires (formatage)
│   └── router/          # Configuration de navigation
├── features/
│   ├── auth/            # Authentification
│   ├── client/          # Écrans client
│   └── owner/           # Écrans propriétaire
└── main.dart            # Point d'entrée
```

## 📝 Notes

- Les données sont actuellement mockées (pas de backend)
- Les images utilisent des URLs Unsplash pour la démonstration
- La localisation est en français
- La devise est en XOF (Franc CFA)

## 🔜 Prochaines étapes

- [ ] Intégration API backend
- [ ] Upload d'images pour les logements
- [ ] Notifications push
- [ ] Paiements (CinetPay, Orange Money)
- [ ] Géolocalisation
- [ ] Favoris
- [ ] Avis et notes

## 📄 Licence

Ce projet est un MVP de démonstration.
