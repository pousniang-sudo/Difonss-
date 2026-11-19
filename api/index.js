// api/index.js — API REST & Serverless Handler pour Vercel & Node.js
// Plateforme Difonssé — Pièces Détachées & Séquestre Mobile Money (Sénégal)

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const url = require('url');

// Chargement des données JSON avec fallback
function loadDataFile(filename, fallback = []) {
  try {
    const fullPath = path.join(process.cwd(), 'data', filename);
    if (fs.existsSync(fullPath)) {
      return JSON.parse(fs.readFileSync(fullPath, 'utf8'));
    }
  } catch (e) {
    console.warn(`[Difonssé API] Erreur lecture ${filename}:`, e.message);
  }
  return fallback;
}

// Sauvegarde facultative (compatible Serverless)
function saveDataFile(filename, data) {
  try {
    const fullPath = path.join(process.cwd(), 'data', filename);
    fs.writeFileSync(fullPath, JSON.stringify(data, null, 2), 'utf8');
  } catch (e) {
    // Les conteneurs Vercel peuvent être read-only en production
  }
}

// État en mémoire initialisé
let products = loadDataFile('products.json', [
  { id: "p1", name: "Plaquettes de Frein Avant Céramique Brembo", oem: "04465-05240", vehicle: "Toyota Hilux Vigo 2.5 D-4D", category: "Freinage", condition: "neuf", conditionLabel: "Neuf d'Origine OEM", bankPrice: 45000, commission: 4500, publicPrice: 49500, vendorId: "usr_seller_1", vendor: "Échoppe Modou", hub: "Pikine", image: "https://images.unsplash.com/photo-1558981403-c5f9899a28bc?auto=format&fit=crop&w=600&q=80", stock: 4, compatibleCar: "Toyota Hilux 2KD / Vigo" },
  { id: "p2", name: "Alternateur 150A Original Valéo", oem: "27060-0L040", vehicle: "Toyota Hilux / Fortuner 2.5", category: "Électricité", condition: "occasion", conditionLabel: "Occasion Testée", bankPrice: 50000, commission: 5000, publicPrice: 55000, vendorId: "usr_seller_2", vendor: "Comptoir Colobane Pièces", hub: "Colobane", image: "https://images.unsplash.com/photo-1486006920555-c77dce18193b?auto=format&fit=crop&w=600&q=80", stock: 2, compatibleCar: "Toyota Hilux / Hiace / Fortuner" },
  { id: "p3", name: "Injecteur Common Rail Bosch", oem: "0445110368", vehicle: "Toyota Hilux 2KD-FTV", category: "Moteur", condition: "neuf", conditionLabel: "Neuf d'Origine OEM", bankPrice: 80000, commission: 8000, publicPrice: 88000, vendorId: "usr_seller_1", vendor: "Échoppe Modou", hub: "Pikine", image: "https://images.unsplash.com/photo-1619642751034-765dfdf7c58e?auto=format&fit=crop&w=600&q=80", stock: 6, compatibleCar: "Toyota Hilux 2.5 D-4D 2005-2015" }
]);

let orders = loadDataFile('orders.json', [
  { id: "CMD-9281", productId: "p1", partName: "Plaquettes de Frein Avant Céramique Brembo", clientName: "Ousmane Niang", clientPhone: "+221 77 123 45 67", vendorId: "usr_seller_1", vendorName: "Échoppe Modou", vendorBankPrice: 45000, commission: 4500, totalPaid: 49500, provider: "Wave", pickupCode: "PK-482", step: 3, stepLabel: "Pièce livrée au Garage · Montage & Essai en cours (48h)", actionRequired: "Mécanicien : Tester la pièce sur le véhicule et valider conformité", timeline: "Fonds sécurisés Kooru Difonssé. Livré au garage de Ouakam.", createdAt: new Date().toISOString() }
]);

let users = loadDataFile('users.json', [
  { id: "usr_buyer_1", role: "buyer", name: "Ousmane Niang", phone: "+221 77 123 45 67", currentVehicle: "Toyota Hilux 2.5 D-4D 2KD", garage: "Garage Expert Ouakam" },
  { id: "usr_seller_1", role: "seller", name: "Modou Fall", shopName: "Échoppe Modou", ninea: "00458921-2K", boxNumber: "Box #42", phone: "+221 77 890 45 12", hub: "Pikine", availableBalance: 125000, escrowBalance: 45000, totalSales: 850000, rating: 4.9, isOpen: true }
]);

let disputes = loadDataFile('disputes.json', [
  { id: "DIF-2026-000089", orderId: "CMD-8832", partName: "Alternateur 150A Original Valéo", buyerName: "Amadou Diallo (Garage Dakar)", buyerPhone: "+221 77 555 44 33", vendorName: "Comptoir Colobane Pièces", vendorPhone: "+221 77 890 45 12", amount: 49500, provider: "Wave", reason: "Pièce non conforme / Connecteur incompatible 2KD", buyerStatement: "Le mécanicien a constaté lors de la pose que la cosse d'excitation ne correspond pas au faisceau 2KD-FTV.", vendorStatement: "La référence envoyée est pourtant compatible selon mon catalogue.", status: "OPEN", statusLabel: "Litige Ouvert · Fonds Gelés", actionRequired: "Arbitrage Superviseur requis (Remboursement ou Déblocage)", createdAt: new Date().toISOString() }
]);

let payouts = loadDataFile('payouts.json', [
  { id: "pay_101", vendorId: "usr_seller_1", vendorName: "Échoppe Modou", amount: 75000, provider: "Wave", recipientPhone: "+221 77 890 45 12", status: "COMPLETED", actionRequired: "Aucune (Virement automatique exécuté)", timestamp: new Date().toISOString() }
]);

let activities = loadDataFile('activities.json', [
  { id: "act_1", section: "escrow", actor: "Plateforme Difonssé", action: "FUNDS_LOCKED", details: "Fonds bloqués sous séquestre pour CMD-9281 (49 500 FCFA)", amount: 49500, icon: "lock", timestamp: new Date().toISOString() }
]);

function logActivity(section, actor, action, details, amount = 0, icon = "info") {
  const item = {
    id: "act_" + Date.now(),
    section,
    actor,
    action,
    details,
    amount: Number(amount) || 0,
    icon,
    timestamp: new Date().toISOString()
  };
  activities.unshift(item);
  if (activities.length > 50) activities.pop();
  saveDataFile('activities.json', activities);
}

// Handler HTTP principal compatible Vercel Serverless & Node.js
module.exports = async function handler(req, res) {
  // En-têtes CORS universels
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.statusCode = 200;
    return res.end();
  }

  const parsedUrl = url.parse(req.url, true);
  let pathname = parsedUrl.pathname || '/';

  // Normalisation du chemin (supprime /api si présent ou double slash)
  if (!pathname.startsWith('/api') && !pathname.startsWith('/')) {
    pathname = '/' + pathname;
  }
  const route = pathname.replace(/^\/api/, '');

  // Helper pour lire le body JSON
  async function parseBody() {
    if (req.body && typeof req.body === 'object') return req.body;
    return new Promise((resolve) => {
      let data = '';
      req.on('data', chunk => { data += chunk; });
      req.on('end', () => {
        try {
          resolve(data ? JSON.parse(data) : {});
        } catch (e) {
          resolve({});
        }
      });
    });
  }

  // Réponse JSON standard
  function sendJson(statusCode, data) {
    res.statusCode = statusCode;
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.end(JSON.stringify(data));
  }

  // ROUTE 1: GET /api/stats
  if (route === '/stats' && req.method === 'GET') {
    let totEscrow = 0;
    let totComm = 0;
    let totGmv = 0;
    let activeCount = 0;
    let totPendingRefunds = 0;

    orders.forEach(o => {
      totGmv += (o.totalPaid || 0);
      if (o.step < 4) {
        totEscrow += (o.totalPaid || 0);
        activeCount++;
      } else {
        totComm += (o.commission || 0);
      }
    });

    disputes.forEach(d => {
      if (d.status === 'OPEN') {
        totPendingRefunds += (d.amount || 0);
      }
    });

    const openDisputesCount = disputes.filter(d => d.status === 'OPEN').length;

    return sendJson(200, {
      totalEscrow: totEscrow,
      totalCommissions: totComm,
      totalGMV: totGmv,
      activeEscrowOrders: activeCount,
      pendingRefundsAmount: totPendingRefunds,
      openDisputesCount: openDisputesCount,
      totalProducts: products.length,
      totalActivities: activities.length,
      totalPayouts: payouts.length,
      activityCounts: {
        buyer: activities.filter(a => a.section === 'buyer').length,
        seller: activities.filter(a => a.section === 'seller').length,
        escrow: activities.filter(a => a.section === 'escrow').length,
        total: activities.length
      }
    });
  }

  // ROUTE 2: GET /api/activities
  if (route === '/activities' && req.method === 'GET') {
    const sec = parsedUrl.query.section;
    if (sec && sec !== 'all') {
      return sendJson(200, activities.filter(a => a.section === sec));
    }
    return sendJson(200, activities);
  }

  // ROUTE 3: POST /api/activities
  if (route === '/activities' && req.method === 'POST') {
    const body = await parseBody();
    logActivity(body.section, body.actor, body.action, body.details, body.amount, body.icon);
    return sendJson(200, { success: true, message: 'Activity logged' });
  }

  // ROUTE 4: GET /api/products
  if (route === '/products' && req.method === 'GET') {
    return sendJson(200, products);
  }

  // ROUTE 5: POST /api/products
  if (route === '/products' && req.method === 'POST') {
    const body = await parseBody();
    const bPrice = Number(body.bankPrice) || 0;
    const comm = Math.round(bPrice * 0.10);
    const pubPrice = bPrice + comm;

    const newP = {
      id: "p_" + Date.now(),
      name: body.name,
      oem: body.oem || "OEM-" + Math.floor(1000 + Math.random() * 9000),
      vehicle: body.vehicle,
      category: body.category,
      condition: body.condition,
      conditionLabel: body.condition === "neuf" ? "Neuf d'Origine OEM" : (body.condition === "occasion" ? "Occasion Testée" : "Adaptable Certifié"),
      bankPrice: bPrice,
      commission: comm,
      publicPrice: pubPrice,
      vendorId: body.vendorId || "usr_seller_1",
      vendor: body.vendor || "Échoppe Modou",
      hub: body.hub || "Pikine",
      image: body.image || "https://images.unsplash.com/photo-1486006920555-c77dce18193b?auto=format&fit=crop&w=600&q=80",
      stock: Number(body.stock) || 1,
      compatibleCar: body.compatibleCar || body.vehicle
    };

    products.unshift(newP);
    saveDataFile('products.json', products);
    logActivity("seller", newP.vendor, "ADD_PRODUCT", `Mise en vente: ${newP.name} (Prix banque: ${newP.bankPrice} FCFA | Client: ${newP.publicPrice} FCFA)`, newP.bankPrice, "add_circle");
    return sendJson(200, { success: true, product: newP });
  }

  // ROUTE 6: GET /api/orders
  if (route === '/orders' && req.method === 'GET') {
    return sendJson(200, orders);
  }

  // ROUTE 7: POST /api/orders
  if (route === '/orders' && req.method === 'POST') {
    const body = await parseBody();
    const cmdId = "CMD-" + Math.floor(1000 + Math.random() * 9000);
    const pkCode = "PK-" + Math.floor(100 + Math.random() * 900);

    const newO = {
      id: cmdId,
      productId: body.productId,
      partName: body.partName,
      clientName: body.clientName,
      clientPhone: body.clientPhone,
      vendorId: body.vendorId,
      vendorName: body.vendorName,
      vendorBankPrice: Number(body.vendorBankPrice) || 0,
      commission: Number(body.commission) || 0,
      totalPaid: Number(body.totalPaid) || 0,
      provider: body.provider || "Wave",
      pickupCode: pkCode,
      step: 2,
      stepLabel: "Fonds Séquestrés · Tiak-Tiak en route vers l'échoppe",
      actionRequired: `Vendeur : Remettre la pièce au coursier contre le code ${pkCode}`,
      timeline: `Commande créée via ${body.provider}. Code retrait: ${pkCode}`,
      createdAt: new Date().toISOString()
    };

    orders.unshift(newO);
    saveDataFile('orders.json', orders);

    // Mise à jour solde sous séquestre vendeur
    users.forEach(u => {
      if (u.shopName === newO.vendorName || u.id === newO.vendorId) {
        u.escrowBalance = (u.escrowBalance || 0) + newO.vendorBankPrice;
      }
    });
    saveDataFile('users.json', users);

    logActivity("buyer", newO.clientName, "ORDER_PLACED", `Achat avec séquestre: ${newO.partName} (${newO.totalPaid} FCFA) via ${newO.provider}`, newO.totalPaid, "shopping_bag");
    logActivity("escrow", "Plateforme Difonssé", "FUNDS_LOCKED", `Fonds bloqués sous séquestre pour ${newO.id} (Prix vendeur: ${newO.vendorBankPrice} | Commission: ${newO.commission})`, newO.totalPaid, "lock");

    return sendJson(200, { success: true, order: newO });
  }

  // ROUTE 8: POST /api/orders/advance
  if (route === '/orders/advance' && req.method === 'POST') {
    const body = await parseBody();
    let found = null;
    orders.forEach(o => {
      if (o.id === body.id) {
        o.step = 3;
        o.stepLabel = "Pièce livrée au Garage · Montage & Essai en cours (48h)";
        o.actionRequired = "Mécanicien : Tester la pièce sur le véhicule et valider conformité";
        o.timeline = `Remise effectuée au coursier avec code ${o.pickupCode}. Délai d'essai démarré.`;
        found = o;
      }
    });
    saveDataFile('orders.json', orders);

    if (found) {
      logActivity("seller", found.vendorName, "COURIER_PICKUP", `Pièce remise au coursier pour ${found.id} contre code ${found.pickupCode}`, 0, "local_shipping");
      logActivity("escrow", "Plateforme Difonssé", "TEST_PERIOD_STARTED", `Délai d'essai 48h démarré pour ${found.id}`, 0, "timer");
    }

    return sendJson(200, { success: true, order: found });
  }

  // ROUTE 9: POST /api/orders/confirm
  if (route === '/orders/confirm' && req.method === 'POST') {
    const body = await parseBody();
    let found = null;
    orders.forEach(o => {
      if (o.id === body.id) {
        o.step = 4;
        o.stepLabel = "Pièce Conforme Validée · Fonds Débloqués";
        o.actionRequired = "Aucune action requise (Terminé)";
        o.timeline = "Validé conforme par le mécanicien au garage. Vendeur crédité.";
        found = o;
      }
    });
    saveDataFile('orders.json', orders);

    if (found) {
      users.forEach(u => {
        if (u.shopName === found.vendorName || u.id === found.vendorId) {
          u.escrowBalance = Math.max(0, (u.escrowBalance || 0) - found.vendorBankPrice);
          u.availableBalance = (u.availableBalance || 0) + found.vendorBankPrice;
          u.totalSales = (u.totalSales || 0) + found.vendorBankPrice;
        }
      });
      saveDataFile('users.json', users);

      logActivity("buyer", found.clientName, "CONFORMITY_CONFIRMED", `Montage validé conforme pour ${found.id}`, 0, "verified");
      logActivity("escrow", "Plateforme Difonssé", "FUNDS_RELEASED", `Libération du séquestre : ${found.vendorBankPrice} FCFA versés au vendeur ${found.vendorName}`, found.vendorBankPrice, "payments");
    }

    return sendJson(200, { success: true, order: found });
  }

  // ROUTE 10: POST /api/orders/dispute
  if (route === '/orders/dispute' && req.method === 'POST') {
    const body = await parseBody();
    let foundOrder = null;
    orders.forEach(o => {
      if (o.id === body.orderId) {
        o.step = 5;
        o.stepLabel = "Litige Ouvert · Séquestre Gelé";
        o.actionRequired = "Superviseur : Arbitrage contradictoire requis";
        o.timeline = "Litige déclaré par le garage : " + body.reason;
        foundOrder = o;
      }
    });
    saveDataFile('orders.json', orders);

    const newDisp = {
      id: "DIF-" + new Date().getFullYear() + "-" + Math.floor(100000 + Math.random() * 900000),
      orderId: body.orderId,
      partName: foundOrder ? foundOrder.partName : "Pièce",
      buyerName: foundOrder ? foundOrder.clientName : "Acheteur",
      buyerPhone: foundOrder ? foundOrder.clientPhone : "",
      vendorName: foundOrder ? foundOrder.vendorName : "Vendeur",
      vendorPhone: "+221 77 890 45 12",
      amount: foundOrder ? foundOrder.totalPaid : 0,
      provider: foundOrder ? foundOrder.provider : "Wave",
      reason: body.reason,
      buyerStatement: body.buyerStatement,
      vendorStatement: "En attente de retour de la pièce pour vérification en boutique.",
      status: "OPEN",
      statusLabel: "Litige Ouvert · Fonds Gelés",
      actionRequired: "Arbitrage Superviseur requis (Remboursement ou Déblocage)",
      createdAt: new Date().toISOString()
    };

    disputes.unshift(newDisp);
    saveDataFile('disputes.json', disputes);

    logActivity("buyer", newDisp.buyerName, "DISPUTE_OPENED", `Litige ouvert ${newDisp.id} pour commande ${newDisp.orderId} (${newDisp.reason})`, newDisp.amount, "report_problem");
    logActivity("escrow", "Plateforme Difonssé", "FUNDS_FROZEN", `Séquestre gelé pour litige ${newDisp.id} (${newDisp.amount} FCFA)`, newDisp.amount, "gavel");

    return sendJson(200, { success: true, dispute: newDisp });
  }

  // ROUTE 11: GET /api/disputes
  if (route === '/disputes' && req.method === 'GET') {
    return sendJson(200, disputes);
  }

  // ROUTE 12: POST /api/disputes/arbitrate (SHA-256 Seal)
  if (route === '/disputes/arbitrate' && req.method === 'POST') {
    const body = await parseBody();
    const dId = body.dossierId;
    const decision = body.decision || "REFUND_BUYER";
    let targetDisp = null;

    disputes.forEach(d => {
      if (d.id === dId || d.orderId === dId) {
        d.status = "RESOLVED";
        d.statusLabel = decision === "REFUND_BUYER" ? "Résolu · Remboursement Acheteur Scellé" : "Résolu · Fonds Libérés Vendeur";
        d.actionRequired = "Dossier clos (Archivé)";
        targetDisp = d;
      }
    });
    saveDataFile('disputes.json', disputes);

    // Calcul de l'empreinte cryptographique SHA-256
    const nowStr = new Date().toISOString();
    const amt = targetDisp ? targetDisp.amount : 49500;
    const recip = targetDisp ? targetDisp.buyerName : "Acheteur";
    const rawSign = `${dId}_${amt}_${recip}_${nowStr}_ESCROW_ARBITRATION_FINAL`;
    const sha256Seal = crypto.createHash('sha256').update(rawSign, 'utf8').digest('hex');

    if (targetDisp) {
      orders.forEach(o => {
        if (o.id === targetDisp.orderId) {
          o.step = 6;
          o.stepLabel = "Remboursement Intégral Scellé SHA-256";
          o.actionRequired = "Dossier archivé · Empreinte " + sha256Seal.substring(0, 12) + "...";
          o.timeline = "Litige clos. Remboursement Wave exécuté avec sceau SHA-256.";
        }
      });
      saveDataFile('orders.json', orders);
    }

    logActivity("escrow", "Comité d'Arbitrage Difonssé", "ARBITRATION_RESOLVED", `Litige ${dId} scellé SHA-256 (${sha256Seal.substring(0, 16)}...). Remboursement intégral de ${amt} FCFA via Wave.`, amt, "verified_user");

    return sendJson(200, {
      success: true,
      dossierId: dId,
      decision,
      sha256Seal,
      amount: amt,
      status: "RESOLVED",
      message: "Litige scellé et exécuté avec succès."
    });
  }

  // ROUTE 13: GET /api/payouts
  if (route === '/payouts' && req.method === 'GET') {
    return sendJson(200, payouts);
  }

  // ROUTE 14: POST /api/payouts
  if (route === '/payouts' && req.method === 'POST') {
    const body = await parseBody();
    const amt = Number(body.amount) || 0;
    const phone = body.phone;
    const prov = body.provider || "Wave";

    let vUser = users.find(u => u.role === "seller");
    if (vUser && vUser.availableBalance >= amt) {
      vUser.availableBalance -= amt;
    }
    saveDataFile('users.json', users);

    const newPay = {
      id: "pay_" + Math.floor(100 + Math.random() * 900),
      vendorId: vUser ? vUser.id : "usr_seller_1",
      vendorName: vUser ? vUser.shopName : "Échoppe Modou",
      amount: amt,
      provider: prov,
      recipientPhone: phone,
      status: "COMPLETED",
      actionRequired: "Aucune (Virement automatique exécuté)",
      timestamp: new Date().toISOString()
    };

    payouts.unshift(newPay);
    saveDataFile('payouts.json', payouts);

    logActivity("seller", newPay.vendorName, "PAYOUT_TRANSFER", `Virement ${prov} effectué avec succès vers ${phone} (${amt} FCFA)`, amt, "arrow_circle_up");

    return sendJson(200, {
      success: true,
      payout: newPay,
      newBalance: vUser ? vUser.availableBalance : 0
    });
  }

  // ROUTE 15: GET /api/users
  if (route === '/users' && req.method === 'GET') {
    return sendJson(200, users);
  }

  // ROUTE 16: POST /api/users/upgrade-seller
  if (route === '/users/upgrade-seller' && req.method === 'POST') {
    const body = await parseBody();
    const newSeller = {
      id: "usr_seller_" + Date.now(),
      role: "seller",
      name: body.name,
      shopName: body.shopName,
      ninea: body.ninea || "00" + Math.floor(1000000 + Math.random() * 9000000) + "-2K",
      boxNumber: body.boxNumber || "Box #" + Math.floor(10 + Math.random() * 290),
      phone: body.phone,
      hub: body.hub || "Pikine",
      availableBalance: 0,
      escrowBalance: 0,
      totalSales: 0,
      rating: 5.0,
      isOpen: true,
      registeredAt: new Date().toISOString()
    };

    users.unshift(newSeller);
    saveDataFile('users.json', users);

    logActivity("seller", newSeller.shopName, "SELLER_REGISTERED", `Nouvelle échoppe créée : ${newSeller.shopName} au hub ${newSeller.hub}`, 0, "store");

    return sendJson(200, { success: true, seller: newSeller });
  }

  // ROUTE 17: POST /api/auth/login
  if (route === '/auth/login' && req.method === 'POST') {
    const body = await parseBody();
    const matched = users.find(u => u.role === body.role);

    if (matched) {
      logActivity(matched.role, matched.name, "LOGIN", `Connexion réussie à l'espace ${matched.role}`, 0, "login");
      return sendJson(200, { success: true, user: matched });
    } else {
      return sendJson(404, { success: false, message: "Utilisateur non trouvé" });
    }
  }

  // 404 Route non trouvée
  return sendJson(404, { error: `Route API introuvable: ${pathname}` });
};
