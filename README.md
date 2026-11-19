# Difonssé — Marketplace de Pièces Détachées Automobiles avec Séquestre Sécurisé

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Fpousniang-sudo%2FDifonss-)

Plateforme sénégalaise innovante dédiée au commerce de pièces détachées automobiles neuves et d'occasion (Pikine, Dakar). **Difonssé** sécurise chaque transaction grâce au séquestre mobile money (*Kooru Difonssé* via Wave et Orange Money), assorti d'une période d'essai de 48h au garage avant libération des fonds.

---

## 🚀 Déploiement sur Vercel (Production)

Le projet est configuré pour un déploiement continu instantané sur **Vercel** :

1. Rendez-vous sur 👉 **[https://vercel.com/new](https://vercel.com/new)** (connectez-vous avec votre compte GitHub **pousniang-sudo**).
2. Dans la liste de vos dépôts, repérez **`Difonss-`** et cliquez sur **Import**.
3. Laissez les réglages par défaut (détection automatique de `package.json` et `vercel.json`) et cliquez sur **Deploy**.
4. En quelques secondes, votre plateforme est en ligne sur une URL publique sécurisée HTTPS (ex: `https://difonss.vercel.app`) !

> **Note :** Chaque nouveau commit poussé sur la branche `main` déclenche un redéploiement automatique sur Vercel.

---

## 🏛️ Architecture de la Plateforme

Le projet sépare strictement les interfaces clients (acheteurs/vendeurs), l'administration DG et l'API :

```
Difonssé/
├── index.html        # Front-End Mobile-First (Acheteurs & Vendeurs)
├── admin.html        # Back-End Superviseur & Cockpit DG (Strictement séparé)
├── vercel.json       # Configuration de routage & Serverless Vercel
├── package.json      # Manifeste Node.js pour Vercel
├── api/
│   └── index.js      # API REST Serverless Node.js (Vercel & cloud)
├── server.ps1        # Serveur Web & API REST PowerShell natif (local port 8080)
├── data/             # Base de données JSON
│   ├── products.json   # Catalogue pièces (OEM, compatibilités, photos)
│   ├── orders.json     # Commandes & statuts séquestre
│   ├── users.json      # Profils acheteurs, mécaniciens & vendeurs
│   ├── disputes.json   # Dossiers de litige & arbitrages
│   ├── payouts.json    # Demandes de retraits vendeurs
│   └── activities.json # Journal d'audit temps réel
└── README.md
```

---

## 📱 1. Front-End Mobile (`index.html`)

Accessible sur mobile à l'adresse locale `http://localhost:8080/` ou sur l'URL Vercel de production :

* **Écran de Connexion & Choix de Profil :** Sélection claire entre profil *Acheteur* (propriétaire de véhicule, mécanicien) et *Vendeur* (échoppes spécialisées).
* **Parcours Acheteur :**
  * Véhicule actif en contexte d'atelier (ex: Toyota Hilux 2.5 D-4D 2KD-FTV).
  * Recherche par mot-clé, catégorie, note vocale en Wolof ou envoi de photo de pièce cassée (SOS Pièce).
  * Paiement sécurisé via séquestre *Kooru Difonssé* (Wave / Orange Money).
  * Suivi de commande en temps réel avec période d'essai 48h au garage.
  * Validation « Pièce Conforme » pour débloquer les fonds au vendeur ou « Signaler Litige ».
  * Bouton **« Devenir Vendeur »** pour permettre aux mécaniciens et commerçants d'enregistrer leur boutique.
* **Parcours Vendeur :**
  * Tableau de bord marchand (solde disponible, séquestre en cours, commandes à préparer).
  * Validation des remises coursier Tiak-Tiak avec code de retrait sécurisé.
  * Calculateur de commission transparent en direct (5%).
  * Demandes de retraits vers Wave ou Orange Money.
* **Sécurité & Confidentialité :** Aucun lien ou mention du tableau de bord d'administration n'apparaît sur le front-end client.

---

## 🛡️ 2. Back-End Admin & Cockpit de Supervision (`admin.html`)

Interface réservée à la direction générale et aux superviseurs (`/admin` ou `/admin.html`) :

* **Métriques Consolidées :** Volume d'affaires brut (GMV), montants actuellement verrouillés sous séquestre, commissions collectées, litiges en cours et remboursements en attente.
* **Suivi Transaction par Transaction :** Visualisation détaillée de chaque commande avec statut exact et actions immédiates recommandées (*« Ce qu'il faudra faire »*).
* **Coffre-fort du Séquestre (*Kooru Difonssé*) :** Déblocage manuel d'urgence ou gel conservatoire des fonds.
* **Chambre d'Arbitrage des Litiges :** Résolution des contestations avec calcul d'empreinte cryptographique **SHA-256** pour sceller chaque décision de manière immuable.
* **Journal d'Audit Temps Réel :** Traçabilité complète de tous les événements de la plateforme.

---

## ⚙️ Démarrage Local Rapide

Pour lancer le serveur localement :

1. Ouvrez PowerShell dans le dossier du projet.
2. Exécutez :
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\server.ps1
   ```
3. Accédez aux interfaces :
   * **Application Mobile :** [http://localhost:8080/](http://localhost:8080/)
   * **Console Admin :** [http://localhost:8080/admin.html](http://localhost:8080/admin.html)

---

## 🔒 Règles de Gestion & Engagements

1. **Nom de la marque :** Strictement **Difonssé**.
2. **Vocabulaire standardisé :** Terminologie automobile et marchande (vendeur, boutique, pièces), sans terme ambigu.
3. **Séquestre Garanti :** Aucun versement n'est fait au vendeur sans validation formelle par le mécanicien ou expiration sans litige des 48h d'essai.
4. **Déploiement Continu :** Chaque évolution validée est automatiquement committée et déployée sur GitHub (`origin/main`), déclenchant la mise à jour Vercel.
