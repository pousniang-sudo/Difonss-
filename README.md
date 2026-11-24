# Difonsé — Marketplace de Pièces Détachées Automobiles avec Paiement Direct, Retainer & Garantie 2 Jours

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Fpousniang-sudo%2FDifonss-)

Plateforme sénégalaise innovante dédiée au commerce de pièces détachées automobiles neuves et d'occasion (Pikine, Dakar). **Difonsé** connecte les acheteurs (propriétaires de véhicules, mécaniciens, flottes) et les boutiques marchandes de Dakar.

Dans le **Business Model**, l'acheteur paye via la plateforme (Wave ou Orange Money). La plateforme **prélève son retainer de service (10%) et rémunère directement le vendeur**. Le coursier Tiak-Tiak récupère la pièce payée chez le vendeur grâce à un code de retrait pour livraison au garage. Chaque pièce bénéficie d'une **garantie de conformité de 2 jours maximum** : si la pièce s'avère non conforme lors du montage au garage, le client peut demander son retour et obtenir un **remboursement intégral**.

---

## 🚀 Déploiement sur Vercel (Production)

Le projet est déployé en continu sur **Vercel** :

* **URL de Production :** [https://difonss.vercel.app](https://difonss.vercel.app)
* **Dépôt GitHub :** [https://github.com/pousniang-sudo/Difonss-](https://github.com/pousniang-sudo/Difonss-)

> **Note :** Chaque nouveau commit poussé sur la branche `main` déclenche un redéploiement automatique instantané sur Vercel.

---

## 🏛️ Architecture & Business Model

Le projet sépare strictement les interfaces clients (acheteurs/vendeurs), l'administration DG et l'API :

```
Difonsé/
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
│   ├── payouts.json    # Demandes de retraits vendeurs & remboursements
│   └── activities.json # Journal d'audit temps réel
└── README.md
```

### 💼 Flux Financier & Garantie Conformité 2 Jours
1. **Sélection de la pièce :** L'acheteur choisit sa pièce compatible (achat unitaire ou via le panier multi-achats).
2. **Paiement via Difonsé :** L'acheteur règle le montant total (Prix Vendeur Net + Retainer Plateforme 10%) via Wave ou Orange Money.
3. **Prélèvement du Retainer :** Difonsé conserve son retainer (10%) pour la mise en relation, la logistique et l'assurance conformité.
4. **Paiement Direct du Vendeur :** Le vendeur perçoit son montant net sans délai (crédit direct sur son solde disponible).
5. **Livraison Tiak-Tiak :** Le coursier récupère la pièce chez le vendeur avec le code de retrait (`PK-XXX`) et la remet au garage.
6. **Garantie de Conformité 2 Jours (48h max) :**
   * **Pièce conforme :** Le client valide la conformité et clôt la commande.
   * **Pièce non conforme :** Le client clique sur « Retourner Pièce (Remboursement) ». Un coursier est dépêché pour restituer la pièce au vendeur et un remboursement intégral immédiat est émis vers le compte Wave/Orange Money de l'acheteur.

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
  * **Achat groupé multi-pièces :** Règlement en une seule opération Wave ou Orange Money de plusieurs pièces avec ventilation automatique des retainers Difonsé et crédit direct de chaque vendeur.
  * **Suivi des Commandes & Garantie 2 Jours :** Compte à rebours 48h affiché sur chaque commande livrée avec bouton de validation conforme ou bouton de demande de retour immédiat avec remboursement.
  * Bouton **« Devenir Vendeur »** pour enregistrer une boutique.
* **Parcours Vendeur :**
  * Cartes de solde : **Solde Disponible Encaissé** vs **Retainers Difonsé Déduits (10%)**.
  * Formulaire de mise en vente avec calculateur en direct : *Prix Vendeur Net* + *Retainer Plateforme* = *Prix Affiché Client*.
  * Commandes reçues avec statut payé et remise au coursier Tiak-Tiak.
  * Demandes de retraits instantanés vers Wave ou Orange Money.
* **Sécurité & Confidentialité :** Aucun lien ou mention du tableau de bord d'administration n'apparaît sur le front-end client.

---

## 🛡️ 2. Back-End Admin & Cockpit de Supervision (`admin.html`)

Interface réservée à la direction générale et aux superviseurs (`/admin` ou `/admin.html`) :

* **Métriques Consolidées :** Volume d'affaires brut (GMV), **Versements directs aux vendeurs**, **Retainers Difonsé encaissés (10%)**, retours sous garantie et remboursements.
* **Registre Transaction par Transaction :** Visualisation détaillée de chaque commande avec ventilation *Prix Client*, *Retainer Plateforme (10%)*, *Net Vendeur Payé*, et statut immédiat.
* **Supervision Garantie 2 Jours & Retours :** Suivi en temps réel des commandes en période d'essai de 48h, validation de conformité et exécution des remboursements en un clic avec traçabilité intégrale.
* **Chambre d'Arbitrage des Litiges :** Résolution des contestations avec calcul d'empreinte cryptographique **SHA-256**.
* **Journal d'Audit Temps Réel :** Traçabilité exhaustive de tous les flux et actions de la plateforme.

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

1. **Nom de la marque :** Strictement **Difonsé**.
2. **Vocabulaire standardisé :** Terminologie automobile et marchande, sans terme ambigu.
3. **Paiement Direct & Retainer :** Le vendeur perçoit son montant net dès le règlement acheteur, la plateforme conservant son retainer de 10%.
4. **Garantie de Conformité 2 Jours :** Essai garanti de 48h en atelier avec retour de pièce et remboursement intégral si non conforme.
5. **Déploiement Continu :** Chaque évolution validée est automatiquement committée et déployée sur GitHub (`origin/main`), assurant la synchronisation instantanée de Vercel.
