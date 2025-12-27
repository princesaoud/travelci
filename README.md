# TravelCI - Plateforme de réservation de logements

Application Flutter pour la réservation de logements en Côte d'Ivoire (MVP).

## 🚀 Fonctionnalités

### Pour les Clients
- 🔐 Authentification complète (inscription/connexion) avec API backend
- 🏠 Recherche de logements par ville, type, prix avec filtres avancés
- 📱 Détails des logements avec galerie photos
- 📅 Réservation avec sélection de dates
- 📋 Gestion des réservations (en attente, acceptées, refusées, annulées)
- 💬 Messagerie (interface préparée)

### Pour les Propriétaires
- 📊 Tableau de bord avec statistiques
- 🏘️ Gestion complète des logements (ajout, modification, suppression)
- 📸 Upload d'images multiples pour les logements
- 📨 Gestion des demandes de réservation (accepter/refuser)
- 📈 Vue d'ensemble des réservations

## 🛠️ Technologies

- **Flutter** 3.6.0+
- **Riverpod** 2.5.1 - Gestion d'état réactive
- **GoRouter** 14.2.0 - Navigation déclarative
- **Dio** 5.4.0 - Client HTTP pour les appels API
- **Shared Preferences** 2.2.2 - Stockage local (tokens)
- **Image Picker** 1.0.7 - Sélection d'images
- **Table Calendar** 3.0.9 - Sélection de dates
- **Intl** 0.20.2 - Formatage XOF et dates

## 📦 Installation

### Prérequis

1. **Backend API** - L'application nécessite le backend TravelCI en cours d'exécution
   - Voir le repository backend: `travelci-backend-`
   - Le backend doit être accessible depuis votre appareil/émulateur

2. **Flutter SDK** 3.6.0 ou supérieur

### Configuration

1. **Cloner le projet**
```bash
git clone <repository-url>
cd travelci
```

2. **Installer les dépendances**
```bash
flutter pub get
```

3. **Configurer l'URL de l'API**

Modifiez `lib/core/utils/api_config.dart` pour configurer l'URL de base selon votre environnement :

```dart
static String get baseUrl {
  // Android Emulator
  // return androidEmulatorBaseUrl; // http://10.0.2.2:3000
  
  // iOS Simulator
  // return iosSimulatorBaseUrl; // http://localhost:3000
  
  // Appareil physique (votre IP locale)
  return physicalDeviceBaseUrl; // http://192.168.100.32:3000
}
```

**Important** : Assurez-vous que votre appareil/émulateur et votre ordinateur (où tourne le backend) sont sur le même réseau Wi-Fi.

4. **Démarrer le backend**

Dans le dossier du backend :
```bash
cd ../travelci-backend-
npm install
npm run dev
```

Le backend doit être accessible sur `http://localhost:3000` (ou votre IP locale).

5. **Lancer l'application**
```bash
flutter run
```

## 🎯 Utilisation

### Comptes de démonstration

Les comptes suivants sont créés par le script de seed du backend :

**Client:**
- Email: `john@example.com`
- Mot de passe: `password123`

**Propriétaire:**
- Email: `jane@example.com`
- Mot de passe: `password123`

**Admin:**
- Email: `admin@example.com`
- Mot de passe: `password123`

### Créer un nouveau compte

Vous pouvez créer un nouveau compte directement depuis l'application :
1. Cliquez sur "S'inscrire" depuis l'écran de connexion
2. Remplissez le formulaire (nom, email, téléphone, mot de passe)
3. Choisissez le type de compte (Client ou Propriétaire)
4. Le compte sera créé et vous serez automatiquement connecté

### Navigation

L'application détecte automatiquement le rôle de l'utilisateur et affiche l'interface appropriée :
- **Client** → Accueil avec recherche de logements
- **Propriétaire** → Tableau de bord avec gestion des logements
- **Invité** → Accès limité à la recherche et visualisation

## 📱 Écrans

### Client
- `/login` - Connexion
- `/register` - Inscription
- `/` - Accueil avec recherche de logements
- `/property/:id` - Détails d'un logement avec réservation
- `/bookings` - Mes réservations
- `/chat` - Messagerie (interface préparée)
- `/search` - Recherche avancée avec filtres

### Propriétaire
- `/` - Tableau de bord
- `/owner/property/new` - Ajouter un logement (avec upload d'images)
- `/owner/property/:id` - Modifier un logement
- `/owner/bookings` - Demandes de réservation
- `/owner/chat` - Messagerie avec clients

## 🏗️ Architecture

```
lib/
├── core/
│   ├── models/              # Modèles de domaine (User, Property, Booking)
│   │   ├── user.dart
│   │   ├── property.dart
│   │   ├── booking.dart
│   │   └── api_response.dart
│   ├── providers/           # Providers Riverpod (state management)
│   │   ├── auth_provider.dart
│   │   ├── property_provider.dart
│   │   └── booking_provider.dart
│   ├── services/            # Services API
│   │   ├── api_service.dart      # Service de base (Dio)
│   │   ├── auth_service.dart     # Authentification
│   │   ├── property_service.dart # Gestion des propriétés
│   │   └── booking_service.dart  # Gestion des réservations
│   ├── utils/               # Utilitaires
│   │   ├── api_config.dart        # Configuration API
│   │   ├── token_manager.dart     # Gestion des tokens JWT
│   │   ├── error_handler.dart     # Gestion des erreurs
│   │   ├── currency_formatter.dart
│   │   └── date_formatter.dart
│   └── router/              # Configuration de navigation
│       └── app_router.dart
├── features/
│   ├── auth/                # Authentification
│   │   └── screens/
│   │       ├── login_screen.dart
│   │       └── register_screen.dart
│   ├── client/              # Écrans client
│   │   └── screens/
│   │       ├── home_screen.dart
│   │       ├── property_detail_screen.dart
│   │       ├── my_bookings_screen.dart
│   │       ├── search_screen.dart
│   │       ├── chat_screen.dart
│   │       └── client_navigation_wrapper.dart
│   └── owner/               # Écrans propriétaire
│       └── screens/
│           ├── dashboard_screen.dart
│           ├── property_form_screen.dart
│           ├── booking_requests_screen.dart
│           └── owner_chat_screen.dart
└── main.dart                # Point d'entrée
```

## 🔌 Intégration API

L'application est entièrement intégrée avec le backend TravelCI via une API REST.

### Configuration API

- **Base URL** : Configurée dans `lib/core/utils/api_config.dart`
- **Endpoints** :
  - Authentification : `/api/auth/*`
  - Propriétés : `/api/properties/*`
  - Réservations : `/api/bookings/*`
  - Images : `/api/images/*`

### Authentification

- Utilisation de **JWT tokens** pour l'authentification
- Tokens stockés de manière sécurisée avec `SharedPreferences`
- Tokens automatiquement inclus dans les en-têtes des requêtes
- Gestion automatique de la déconnexion en cas de token invalide

### Gestion des erreurs

- Toutes les erreurs API sont capturées et converties en messages en français
- Messages d'erreur affichés via des SnackBars
- Gestion des erreurs réseau, authentification, et validation

## 📝 Fonctionnalités implémentées

✅ **Authentification complète**
- Inscription avec validation
- Connexion avec gestion des tokens
- Déconnexion
- Récupération du profil utilisateur

✅ **Gestion des propriétés**
- Liste avec pagination et filtres (ville, type, prix, meublé)
- Détails d'une propriété
- Création avec upload d'images multiples
- Modification
- Suppression

✅ **Gestion des réservations**
- Création de réservation
- Liste des réservations (client/propriétaire)
- Mise à jour du statut (accepter/refuser)
- Annulation

✅ **Interface utilisateur**
- Navigation adaptative selon le rôle
- Feedback utilisateur (messages de succès/erreur)
- États de chargement
- Gestion des erreurs avec messages en français

## 🔔 Système de Notifications Locales

L'application utilise un système de **notifications locales** qui fonctionne sans Firebase :

### Fonctionnalités
- ✅ Notifications in-app (quand l'application est ouverte)
- ✅ Notifications système (quand l'application est en arrière-plan)
- ✅ Badge avec compteur de notifications non lues
- ✅ Stockage local des notifications (persistance)
- ✅ Types de notifications :
  - Nouvelle demande de réservation (propriétaire)
  - Réservation acceptée (client)
  - Réservation refusée (client)
  - Réservation annulée (propriétaire/client)

### Comment ça fonctionne
1. **Quand l'app est ouverte** : Les notifications sont créées automatiquement lors des événements (création de réservation, acceptation, etc.)
2. **Quand l'app est en arrière-plan** : Les notifications système s'affichent
3. **Stockage** : Toutes les notifications sont sauvegardées localement et persistent entre les sessions
4. **Accès** : Cliquez sur l'icône de cloche dans le dashboard pour voir toutes les notifications

### Limitations
- ⚠️ Les notifications ne fonctionnent **pas** quand l'application est complètement fermée
- ⚠️ Pas de notifications push depuis le backend (nécessiterait Firebase Cloud Messaging)

### Pour ajouter Firebase (optionnel)
Si vous souhaitez des notifications push même quand l'app est fermée, vous pouvez ajouter Firebase Cloud Messaging plus tard.

## 🔜 Prochaines étapes

- [x] Notifications locales (implémenté)
- [ ] Notifications push (Firebase Cloud Messaging - optionnel)
- [ ] Paiements (CinetPay, Orange Money)
- [ ] Géolocalisation et cartes
- [ ] Système de favoris
- [ ] Avis et notes
- [ ] Recherche par géolocalisation
- [ ] Chat en temps réel
- [ ] Notifications email/SMS

## 🐛 Dépannage

### L'application ne peut pas se connecter à l'API

1. Vérifiez que le backend est en cours d'exécution
2. Vérifiez l'URL dans `api_config.dart`
3. Pour un appareil physique, assurez-vous que :
   - L'appareil et l'ordinateur sont sur le même réseau Wi-Fi
   - Le pare-feu n'bloque pas le port 3000
   - L'IP de l'ordinateur est correcte

### Erreurs d'authentification

1. Vérifiez que vous utilisez les bons identifiants
2. Si le token est invalide, déconnectez-vous et reconnectez-vous
3. Vérifiez les logs du backend pour plus de détails

### Les images ne s'affichent pas

1. Vérifiez que les URLs d'images retournées par l'API sont valides
2. Vérifiez la connexion réseau
3. Les images sont chargées via `cached_network_image`

## 📄 Licence

Ce projet est un MVP de démonstration.

## 👥 Contribution

Pour contribuer au projet, veuillez suivre les conventions de code et créer une pull request.
