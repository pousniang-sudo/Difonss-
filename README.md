# Difonssé — Marketplace de Pièces Détachées Automobiles avec Paiement Direct & Retainer Plateforme

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Fpousniang-sudo%2FDifonss-)

Plateforme sénégalaise innovante dédiée au commerce de pièces détachées automobiles neuves et d'occasion (Pikine, Dakar). **Difonssé** connecte les acheteurs (propriétaires de véhicules, mécaniciens, flottes) et les échoppes marchandes de Dakar.

Dans le nouveau **Business Model**, l'acheteur paye via la plateforme (Wave ou Orange Money). La plateforme **prélève son retainer de service (10%) et rémunère directement le vendeur** au comptant (zéro séquestre vendeur). Le coursier Tiak-Tiak récupère la pièce payée à l'échoppe grâce à un code de retrait pour livraison au garage.

---

## 🚀 Déploiement sur Vercel (Production)

Le projet est déployé en continu sur **Vercel** :

* **URL de Production :** [https://difonss.vercel.app](https://difonss.vercel.app)
* **Dépôt GitHub :** [https://github.com/pousniang-sudo/Difonss-](https://github.com/pousniang-sudo/Difonss-)

> **Note :** Chaque nouveau commit poussé sur la branche `main` déclenche un redéploiement automatique instantané sur Vercel.

---

## 🏛️ Architecture & Nouveau Business Model

Le projet sépare strictement les interfaces clients (acheteurs/vendeurs), l'administration DG et l'API :

```
Difonssé/
├── index.html        # Front-End Mobile-First (Acheteurs & Vendeurs différenciés)
├── admin.html        # Back-End Superviseur & Cockpit DG (Strictement séparé)
├── vercel.json       # Configuration de routage & Serverless Vercel
├── package.json      # Manifeste Node.js pour Vercel
├── api/
│   └── index.js      # API REST Serverless Node.js (Vercel & cloud)
├── server.ps1        # Serveur Web & API REST PowerShell natif (local port 8080)
├── data/             # Base de données JSON
│   ├── products.json   # Catalogue pièces (OEM, compatibilités, photos)
│   ├── orders.json     # Commandes, retainers & flux de paiement direct
│   ├── users.json      # Profils acheteurs (avec solvabilité) & vendeurs
│   ├── disputes.json   # Dossiers de litige & arbitrages
│   ├── payouts.json    # Demandes de retraits vendeurs
│   └── activities.json # Journal d'audit temps réel
└── README.md
```

### 💼 Flux Financier (Nouveau Business Model)
1. **Sélection de la pièce :** L'acheteur choisit sa pièce compatible.
2. **Paiement via Difonssé :** L'acheteur règle le montant total (Prix Vendeur Net + Retainer Plateforme 10%) via Wave ou Orange Money.
3. **Prélèvement du Retainer :** Difonssé conserve son retainer (10%) pour la mise en relation et la logistique.
4. **Paiement Direct du Vendeur :** Le vendeur est rémunéré directement et immédiatement (crédit instantané de son solde disponible, zéro séquestre vendeur).
5. **Livraison Tiak-Tiak :** Le coursier se rend à l'échoppe et récupère la pièce contre le code sécurisé (`PK-XXX`).

---

## 📱 1. Front-End Mobile (`index.html`)

Accessible sur mobile à l'adresse locale `http://localhost:8080/` ou sur l'URL Vercel de production :

* **Identification & Traçabilité Complète :**
  * Connexion séparée avec saisie obligatoire du **Nom & Prénom** pour acheteurs et vendeurs.
  * Passeport et indicateur de **Solvabilité Acheteur** (ex: *🛡️ Solvabilité 98/100 · Solvable Vérifié*) pour tracer toutes les transactions.
* **Parcours Acheteur & Panier Multi-Achats :**
  * Véhicule actif en atelier (ex: Toyota Hilux 2.5 D-4D).
  * Catalogue interactif avec double option : **« + Panier »** pour regrouper ses pièces ou **« Payer Direct »**.
  * **Onglet Panier dans la navigation du bas** avec compteur dynamique en temps réel.
  * Gestion complète du panier : sélection/désélection individuelle par case à cocher, « Tout sélectionner », suppression ou paiement d'une pièce seule.
  * **Achat groupé multi-pièces :** Règlement en une seule opération Wave ou Orange Money de plusieurs pièces avec ventilation automatique des retainers Difonssé et crédit direct de chaque vendeur échoppe.
  * Suivi des commandes reçues et remises aux coursiers Tiak-Tiak avec codes de retrait individuels.
  * Bouton **« Devenir Vendeur »** pour enregistrer une échoppe.
* **Parcours Vendeur (Nouveau BM) :**
  * Bannière informative du nouveau modèle sans séquestre.
  * Cartes de solde : **Solde Disponible Encaissé** vs **Retainers Difonssé Déduits (10%)**.
  * Formulaire de mise en vente avec calculateur en direct : *Prix Vendeur Net* + *Retainer Plateforme* = *Prix Affiché Client*.
  * Commandes reçues avec statut payé d'office et remise au coursier Tiak-Tiak.
  * Demandes de retraits instantanés vers Wave ou Orange Money.
* **Sécurité & Confidentialité :** Aucun lien ou mention du tableau de bord d'administration n'apparaît sur le front-end client.

---

## 🛡️ 2. Back-End Admin & Cockpit de Supervision (`admin.html`)

Interface réservée à la direction générale et aux superviseurs (`/admin` ou `/admin.html`) :

* **Métriques Consolidées :** Volume d'affaires brut (GMV), **Versements directs aux vendeurs**, **Retainers Difonssé encaissés (10%)**, litiges et remboursements.
* **Registre Transaction par Transaction :** Visualisation détaillée de chaque commande avec ventilation *Prix Client*, *Retainer Plateforme (10%)*, *Net Vendeur Payé*, et statut immédiat.
* **Chambre d'Arbitrage des Litiges :** Résolution des contestations avec calcul d'empreinte cryptographique **SHA-256**.
* **Journal d'Audit Temps Réel :** Traçabilité exhaustive de tous les événements de la plateforme.

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
2. **Vocabulaire standardisé :** Terminologie automobile et marchande, sans terme ambigu.
3. **Paiement Direct :** Le vendeur perçoit son montant net sans délai de séquestre dès l'encaissement acheteur.
4. **Déploiement Continu :** Chaque évolution validée est automatiquement committée et déployée sur GitHub (`origin/main`), assurant la synchronisation instantanée de Vercel.
