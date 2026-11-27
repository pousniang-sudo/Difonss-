// api/index.js — API REST & Serverless Handler pour Vercel & Node.js
// Plateforme Difonsé — Pièces Détachées, Paiement Direct & Retainer Plateforme (Sénégal)

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const url = require('url');

// Supabase Server Configuration
const SUPABASE_URL = process.env.SUPABASE_URL || "https://qqhgxnizhxfqanswjpmg.supabase.co";
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFxaGd4bml6aHhmcWFuc3dqcG1nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUyOTAzMTAsImV4cCI6MjExMDg2NjMxMH0.PQ9qZ1HrSzq4u7EbOwa3PqTdY5Me9ECzx2MPIeylq-M";
const SUPABASE_PUBLISHABLE_KEY = process.env.SUPABASE_PUBLISHABLE_KEY || "sb_publishable_Ae2cpdJhhmU15DUD4-iiTA_BX09Wf-a";
const SUPABASE_SECRET_KEY = process.env.SUPABASE_SECRET_KEY || "";
const SUPABASE_JWKS_URL = process.env.SUPABASE_JWKS_URL || `${SUPABASE_URL}/auth/v1/.well-known/jwks.json`;

let supabaseServerClient = null;
try {
  const { createClient } = require('@supabase/supabase-js');
  const activeKey = (SUPABASE_SECRET_KEY && !SUPABASE_SECRET_KEY.includes('••') && SUPABASE_SECRET_KEY.length > 20) ? SUPABASE_SECRET_KEY : SUPABASE_ANON_KEY;
  supabaseServerClient = createClient(SUPABASE_URL, activeKey);
} catch (e) {
  // Optional in environments where @supabase/supabase-js is not pre-installed
}

// Chargement des données JSON avec fallback
function loadDataFile(filename, fallback = []) {
  try {
    const fullPath = path.join(process.cwd(), 'data', filename);
    if (fs.existsSync(fullPath)) {
      return JSON.parse(fs.readFileSync(fullPath, 'utf8'));
    }
  } catch (e) {
    console.warn(`[Difonsé API] Erreur lecture ${filename}:`, e.message);
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
  {
    id: "p1",
    name: "Alternateur 150A Original Valéo",
    oem: "27060-0L020",
    vehicle: "Toyota Hilux Vigo 2.5 D-4D (2011-2016)",
    category: "electricite",
    condition: "occasion",
    conditionLabel: "Occasion Testée",
    bankPrice: 45000,
    commission: 4500,
    publicPrice: 49500,
    vendorId: "usr_seller_1",
    vendor: "Boutique Modou Pikine",
    hub: "Pikine",
    image: "https://images.unsplash.com/photo-1517524008697-84bbe3c3fd98?auto=format&fit=crop&w=800&q=80",
    gallery: [
      "https://images.unsplash.com/photo-1517524008697-84bbe3c3fd98?auto=format&fit=crop&w=800&q=80",
      "https://images.unsplash.com/photo-1619642751034-765dfdf7c58e?auto=format&fit=crop&w=800&q=80",
      "https://images.unsplash.com/photo-1558981403-c5f9899a28bc?auto=format&fit=crop&w=800&q=80",
      "https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=800&q=80"
    ],
    description: "Alternateur d'origine Valéo 150A révisé et testé sur banc d'essai à Dakar. Spécialement adapté pour les Toyota Hilux Vigo circulant en conditions sévères.",
    specs: {
      oem: "27060-0L020",
      brand: "Valéo OEM (Fournisseur Première Monte)",
      vehicle: "Toyota Hilux Vigo, Fortuner, HiAce",
      engine: "2.5 D-4D (2KD-FTV) & 3.0 D-4D (1KD-FTV)",
      years: "2005 - 2016",
      position: "Compartiment moteur avant droit, courroie striée",
      power: "12 Volts · 150 Ampères réels",
      testing: "Testé sur banc électrique 14.4V sous charge continue",
      warranty: "Garantie Difonsé 2 jours pour vérification et montage avec votre mécanicien"
    },
    stock: 3,
    compatibleCar: "Toyota Hilux"
  }
]);

let orders = loadDataFile('orders.json', [
  { id: "CMD-9281", productId: "p1", partName: "Plaquettes de Frein Avant Céramique Brembo", clientName: "Ousmane Niang", clientPhone: "+221 77 123 45 67", vendorId: "usr_seller_1", vendorName: "Boutique Modou", vendorBankPrice: 45000, commission: 4500, totalPaid: 49500, provider: "Wave", pickupCode: "PK-482", step: 3, stepLabel: "Pièce livrée au Garage · Montage & Essai en cours (48h)", actionRequired: "Mécanicien : Tester la pièce sur le véhicule et valider conformité", timeline: "Fonds sécurisés Kooru Difonsé. Livré au garage de Ouakam.", createdAt: new Date().toISOString() }
]);

let users = loadDataFile('users.json', [
  { id: "usr_buyer_1", role: "buyer", name: "Ousmane Niang", phone: "+221 77 123 45 67", currentVehicle: "Toyota Hilux 2.5 D-4D 2KD", garage: "Garage Expert Ouakam" },
  { id: "usr_seller_1", role: "seller", name: "Modou Fall", shopName: "Boutique Modou", ninea: "00458921-2K", boxNumber: "Box #42", phone: "+221 77 890 45 12", hub: "Pikine", availableBalance: 125000, totalSales: 850000, rating: 4.9, isOpen: true }
]);

let disputes = loadDataFile('disputes.json', [
  { id: "DIF-2026-000089", orderId: "CMD-8832", partName: "Alternateur 150A Original Valéo", buyerName: "Amadou Diallo (Garage Dakar)", buyerPhone: "+221 77 555 44 33", vendorName: "Comptoir Colobane Pièces", vendorPhone: "+221 77 890 45 12", amount: 49500, provider: "Wave", reason: "Pièce non conforme / Connecteur incompatible 2KD", buyerStatement: "Le mécanicien a constaté lors de la pose que la cosse d'excitation ne correspond pas au faisceau 2KD-FTV.", vendorStatement: "La référence envoyée est pourtant compatible selon mon catalogue.", status: "OPEN", statusLabel: "Litige Ouvert · Fonds Gelés", actionRequired: "Arbitrage Superviseur requis (Remboursement ou Déblocage)", createdAt: new Date().toISOString() }
]);

let payouts = loadDataFile('payouts.json', [
  { id: "pay_101", vendorId: "usr_seller_1", vendorName: "Boutique Modou", amount: 75000, provider: "Wave", recipientPhone: "+221 77 890 45 12", status: "COMPLETED", actionRequired: "Aucune (Virement automatique exécuté)", timestamp: new Date().toISOString() }
]);

let activities = loadDataFile('activities.json', [
  { id: "act_1", section: "orders", actor: "Plateforme Difonsé", action: "ORDER_PAID", details: "Paiement direct reçu pour CMD-9281 (49 500 FCFA)", amount: 49500, icon: "payments", timestamp: new Date().toISOString() }
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

  if (supabaseServerClient) {
    try {
      supabaseServerClient.from('activities').insert([{
        id: item.id,
        section: item.section,
        actor: item.actor,
        action: item.action,
        details: item.details,
        amount: item.amount,
        icon: item.icon,
        created_at: item.timestamp
      }]).then(() => {}).catch(() => {});
    } catch (e) {}
  }
}

// Synchronisation automatique et traçabilité des utilisateurs dans Supabase (Profiles & User Connections)
function syncUserProfileToSupabase(profile) {
  if (!supabaseServerClient || !profile || !profile.phone) return;
  try {
    const pFirst = profile.firstName || (profile.name ? profile.name.split(' ')[0] : 'Utilisateur');
    const pLast = profile.lastName || (profile.name ? profile.name.split(' ').slice(1).join(' ') : 'Difonsé');
    const pOrg = profile.shopName || profile.garageName || profile.organization || '';
    const pHub = profile.location || profile.hub || 'Dakar';
    const pAddr = profile.address || profile.deliveryAddress || null;
    const pGps = profile.gps || (profile.deliveryGps ? (typeof profile.deliveryGps === 'object' ? JSON.stringify(profile.deliveryGps) : String(profile.deliveryGps)) : null);
    const pRole = profile.role || 'buyer';
    const pScore = Number(profile.solvencyScore) || 98;
    const pStatus = profile.solvencyStatus || (pRole === 'seller' ? 'Vendeur Certifié' : 'Solvable Vérifié');

    const vCode = profile.vendorCode || profile.vendor_code || null;
    const availBal = Number(profile.availableBalance || profile.available_balance) || 0;
    const totSales = Number(profile.totalSales || profile.total_sales) || 0;

    supabaseServerClient.from('profiles').upsert([{
      phone: profile.phone,
      first_name: pFirst,
      last_name: pLast,
      role: pRole,
      organization: pOrg,
      hub: pHub,
      address: pAddr,
      gps: pGps,
      solvency_score: pScore,
      solvency_status: pStatus,
      vendor_code: vCode,
      available_balance: availBal,
      total_sales: totSales,
      last_login: new Date().toISOString()
    }], { onConflict: 'phone' }).then(() => {}).catch(() => {});

    supabaseServerClient.from('user_connections').insert([{
      first_name: pFirst,
      last_name: pLast,
      phone: profile.phone,
      role: pRole,
      organization: pOrg,
      hub: pHub,
      solvency_score: pScore,
      user_agent: 'API Backend Server (Vercel)',
      connected_at: new Date().toISOString()
    }]).then(() => {}).catch(() => {});
  } catch (e) {}
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

  // ROUTE 0: GET /api/supabase/health
  if (route === '/supabase/health' && req.method === 'GET') {
    return sendJson(200, {
      status: "connected",
      supabaseUrl: SUPABASE_URL,
      publishableKey: SUPABASE_PUBLISHABLE_KEY,
      jwksUrl: SUPABASE_JWKS_URL,
      serverClientReady: !!supabaseServerClient
    });
  }

  // ROUTE 1: GET /api/stats (Nouveau BM: Retainers collectés & Paiements directs vendeurs)
  if (route === '/stats' && req.method === 'GET') {
    let totRetainer = 0;
    let totVendorPayouts = 0;
    let totGmv = 0;
    let activeCount = 0;
    let totPendingRefunds = 0;

    orders.forEach(o => {
      totGmv += (o.totalPaid || 0);
      const ret = (o.platformRetainer != null) ? o.platformRetainer : (o.commission || Math.round((o.vendorBankPrice || 0) * 0.10));
      totRetainer += ret;
      const vNet = (o.vendorNetPrice != null) ? o.vendorNetPrice : (o.vendorBankPrice || (o.totalPaid - ret));
      totVendorPayouts += vNet;
      if (o.step < 4) {
        activeCount++;
      }
    });

    disputes.forEach(d => {
      if (d.status === 'OPEN') {
        totPendingRefunds += (d.amount || 0);
      }
    });

    const openDisputesCount = disputes.filter(d => d.status === 'OPEN').length;

    return sendJson(200, {
      totalCommissions: totRetainer,
      totalRetainers: totRetainer,
      totalVendorPayouts: totVendorPayouts,
      totalGMV: totGmv,
      activeOrders: activeCount,
      activeEscrowOrders: activeCount,
      pendingRefundsAmount: totPendingRefunds,
      openDisputesCount: openDisputesCount,
      totalProducts: products.length,
      totalActivities: activities.length,
      totalPayouts: payouts.length,
      activityCounts: {
        buyer: activities.filter(a => a.section === 'buyer').length,
        seller: activities.filter(a => a.section === 'seller').length,
        platform: activities.filter(a => a.section === 'platform' || a.section === 'escrow').length,
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

    const img = body.image || "https://images.unsplash.com/photo-1619642751034-765dfdf7c58e?auto=format&fit=crop&w=800&q=80";
    const gallery = Array.isArray(body.gallery) && body.gallery.length > 0 ? body.gallery : [
      img,
      "https://images.unsplash.com/photo-1517524008697-84bbe3c3fd98?auto=format&fit=crop&w=800&q=80",
      "https://images.unsplash.com/photo-1558981403-c5f9899a28bc?auto=format&fit=crop&w=800&q=80",
      "https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=800&q=80"
    ];

    const condLabel = body.conditionLabel || (body.condition === "neuf" ? "Neuf d'Origine OEM" : (body.condition === "occasion" ? "Occasion Testée" : "Adaptable Certifié"));
    const oemCode = body.oem || "OEM-" + Math.floor(1000 + Math.random() * 9000);
    const veh = body.vehicle || "Toyota Hilux Vigo 2.5 D-4D";

    const desc = body.description || `Pièce ${body.name || 'détachée'} (${condLabel}) certifiée compatible pour ${veh}. Contrôlée et testée sur banc d'essai à Dakar avant mise en stock. Conforme aux spécifications constructeur avec garantie conformité Difonsé de 2 jours après livraison.`;

    const specs = (body.specs && typeof body.specs === 'object') ? body.specs : {
      oem: oemCode,
      brand: body.brand || "OEM Constructeur",
      vehicle: veh,
      engine: body.engine || "2.5 D-4D / 3.0 D-4D Diesel",
      years: body.years || "2005 - 2016",
      position: body.position || "Compartiment Moteur / Châssis",
      power: body.power || "Standard OEM vérifié",
      testing: "Testé et certifié opérationnel 100% sur banc d'essai",
      warranty: "Garantie Difonsé 2 jours (48h pour montage mécanicien)"
    };

    const vCode = body.vendorCode || body.vendor_code || ("VND-" + (body.vendorPhone ? body.vendorPhone.replace(/[^0-9]/g, '').slice(-6) : Math.floor(100000 + Math.random() * 900000)));
    const vPhone = body.vendorPhone || body.vendor_phone || "";

    const newP = {
      id: "p_" + Date.now(),
      name: body.name || body.title || "Pièce Auto",
      oem: oemCode,
      vehicle: veh,
      category: body.category,
      condition: body.condition,
      conditionLabel: condLabel,
      bankPrice: bPrice,
      commission: comm,
      publicPrice: pubPrice,
      vendorId: body.vendorId || "usr_seller_1",
      vendor: body.vendor || "Boutique Modou Pikine",
      vendorCode: vCode,
      vendorPhone: vPhone,
      hub: body.hub || "Pikine",
      image: img,
      gallery: gallery,
      description: desc,
      specs: specs,
      stock: Number(body.stock) || 1,
      compatibleCar: body.compatibleCar || veh
    };

    products.unshift(newP);
    saveDataFile('products.json', products);
    logActivity("seller", newP.vendor, "ADD_PRODUCT", `Mise en vente: ${newP.name} (Prix banque: ${newP.bankPrice} FCFA | Client: ${newP.publicPrice} FCFA)`, newP.bankPrice, "add_circle");

    if (supabaseServerClient) {
      try {
        supabaseServerClient.from('products').insert([{
          id: newP.id,
          name: newP.name,
          oem: newP.oem,
          vehicle: newP.vehicle,
          category: newP.category,
          condition: newP.condition,
          condition_label: newP.conditionLabel,
          bank_price: newP.bankPrice,
          commission: newP.commission,
          public_price: newP.publicPrice,
          vendor: newP.vendor,
          vendor_id: newP.vendorId,
          vendor_code: newP.vendorCode,
          vendor_phone: newP.vendorPhone,
          hub: newP.hub,
          stock: newP.stock,
          image: newP.image,
          compatible_car: newP.compatibleCar
        }]).then(() => {}).catch(() => {});
      } catch (e) {}
    }

    return sendJson(200, { success: true, product: newP });
  }

  // ROUTE 5-B: POST /api/products/update (Modifier nom, spécifications, prix, stock d'une pièce)
  if (route === '/products/update' && req.method === 'POST') {
    const body = await parseBody();
    const found = products.find(p => p.id === body.id);
    if (!found) return sendJson(404, { error: "Pièce introuvable" });

    if (body.name) found.name = body.name;
    if (body.oem != null) {
      found.oem = body.oem;
      if (found.specs) found.specs.oem = body.oem;
    }
    if (body.vehicle) {
      found.vehicle = body.vehicle;
      found.compatibleCar = body.vehicle;
      if (found.specs) found.specs.vehicle = body.vehicle;
    }
    if (body.category) found.category = body.category;
    if (body.condition) {
      found.condition = body.condition;
      found.conditionLabel = body.condition === "neuf" ? "Neuf d'Origine OEM" : (body.condition === "occasion" ? "Occasion Testée" : "Adaptable Certifié");
    }
    if (body.bankPrice != null) {
      const bPrice = Number(body.bankPrice) || 0;
      const comm = Math.round(bPrice * 0.10);
      found.bankPrice = bPrice;
      found.commission = comm;
      found.publicPrice = bPrice + comm;
    }
    if (body.stock != null) found.stock = Number(body.stock);
    if (body.image) {
      found.image = body.image;
      if (!found.gallery || found.gallery.length === 0) {
        found.gallery = [body.image];
      } else {
        found.gallery[0] = body.image;
      }
    }
    if (Array.isArray(body.gallery) && body.gallery.length > 0) {
      found.gallery = body.gallery;
    }
    if (body.description) {
      found.description = body.description;
    }
    if (body.specs && typeof body.specs === 'object') {
      found.specs = Object.assign({}, found.specs || {}, body.specs);
    }

    saveDataFile('products.json', products);
    logActivity("seller", found.vendor, "UPDATE_PRODUCT", `Modification pièce: ${found.name} (Prix net: ${found.bankPrice} FCFA, Stock: ${found.stock})`, found.bankPrice, "edit");
    return sendJson(200, { success: true, product: found });
  }

  // ROUTE 5-C: POST /api/products/delete (Enlever une pièce du catalogue)
  if (route === '/products/delete' && req.method === 'POST') {
    const body = await parseBody();
    const idx = products.findIndex(p => p.id === body.id);
    if (idx === -1) return sendJson(404, { error: "Pièce introuvable" });

    const removed = products.splice(idx, 1)[0];
    saveDataFile('products.json', products);
    logActivity("seller", removed.vendor, "DELETE_PRODUCT", `Pièce retirée du catalogue: ${removed.name}`, 0, "delete");
    return sendJson(200, { success: true, id: body.id });
  }

  // ROUTE 6: GET /api/orders
  if (route === '/orders' && req.method === 'GET') {
    return sendJson(200, orders);
  }

  // ROUTE 7: POST /api/orders (Paiement Direct Vendeur & Retainer Plateforme - Unitaire ou Panier Multi-pièces)
  if (route === '/orders' && req.method === 'POST') {
    const body = await parseBody();

    const rawItems = (body.items && Array.isArray(body.items) && body.items.length > 0)
      ? body.items
      : [body];

    const createdOrders = [];

    rawItems.forEach(item => {
      const cmdId = "CMD-" + Math.floor(1000 + Math.random() * 9000);
      const pkCode = "PK-" + Math.floor(100 + Math.random() * 900);
      const vBank = Number(item.vendorBankPrice) || Number(item.vendorNetPrice) || Number(item.bankPrice) || 0;
      const retainer = Number(item.platformRetainer) || Number(item.commission) || Math.round(vBank * 0.10);
      const total = Number(item.totalPaid) || (vBank + retainer);

      const clientFirstName = item.clientFirstName || body.clientFirstName || (body.clientName ? body.clientName.split(' ')[0] : 'Acheteur');
      const clientLastName = item.clientLastName || body.clientLastName || (body.clientName ? body.clientName.split(' ').slice(1).join(' ') : 'Difonsé');
      const clientFullName = item.clientName || body.clientName || `${clientFirstName} ${clientLastName}`.trim();
      const clientPhone = item.clientPhone || body.clientPhone || '';
      const solvencyScore = Number(item.solvencyScore || body.solvencyScore || 98);
      const solvencyStatus = item.solvencyStatus || body.solvencyStatus || 'Solvable Vérifié';
      const provider = item.provider || body.provider || "Wave";

      const vCode = item.vendorCode || body.vendorCode || "";
      const vPhone = item.vendorPhone || body.vendorPhone || "";
      const vHub = item.vendorShopLocation || item.hub || body.hub || "Dakar";

      const newO = {
        id: cmdId,
        productId: item.productId || item.id,
        partName: item.partName || item.name,
        clientFirstName: clientFirstName,
        clientLastName: clientLastName,
        clientName: clientFullName,
        clientPhone: clientPhone,
        deliveryAddress: item.deliveryAddress || body.deliveryAddress || clientFullName,
        deliveryNotes: item.deliveryNotes || body.deliveryNotes || '',
        deliveryGps: item.deliveryGps || body.deliveryGps || null,
        solvencyScore: solvencyScore,
        solvencyStatus: solvencyStatus,
        vendorId: item.vendorId || "usr_seller_1",
        vendorName: item.vendorName || item.vendor || "Boutique Vendeur",
        vendorCode: vCode,
        vendorPhone: vPhone,
        vendorShopLocation: vHub,
        vendorBankPrice: vBank,
        vendorNetPrice: vBank,
        commission: retainer,
        platformRetainer: retainer,
        totalPaid: total,
        provider: provider,
        pickupCode: pkCode,
        step: 2,
        stepLabel: "Payé par Difonsé · Tiak-Tiak en route vers le vendeur",
        vendorPaymentStatus: "PAID_DIRECT",
        actionRequired: `Vendeur : Remettre la pièce payée au coursier contre le code ${pkCode}`,
        timeline: `Acheteur débité via ${provider}. Retainer Difonsé prélevé (${retainer} FCFA). Vendeur payé directement (${vBank} FCFA). Livraison : ${item.deliveryAddress || body.deliveryAddress || 'Dakar'}`,
        createdAt: new Date().toISOString()
      };

      orders.unshift(newO);
      createdOrders.push(newO);

      // Paiement direct du vendeur (crédit instantané du solde disponible)
      users.forEach(u => {
        if (u.id === newO.vendorId || u.shopName === newO.vendorName || (vPhone && u.phone && u.phone.replace(/[^0-9]/g, '').endsWith(vPhone.replace(/[^0-9]/g, '')))) {
          u.availableBalance = (u.availableBalance || 0) + vBank;
          u.totalSales = (u.totalSales || 0) + vBank;
          u.totalRetainerPaid = (u.totalRetainerPaid || 0) + retainer;
          u.escrowBalance = 0;
        }
      });

      logActivity("buyer", newO.clientName, "ORDER_PLACED", `Commande payée via ${provider} : ${newO.partName} (${newO.totalPaid} FCFA)`, newO.totalPaid, "shopping_bag");
      logActivity("platform", "Plateforme Difonsé", "RETAINER_COLLECTED", `Retainer plateforme prélevé : ${retainer} FCFA sur commande ${newO.id}`, retainer, "savings");
      logActivity("seller", newO.vendorName, "DIRECT_PAYMENT_RECEIVED", `Paiement direct reçu : ${vBank} FCFA pour ${newO.partName}`, vBank, "payments");

      if (supabaseServerClient) {
        try {
          supabaseServerClient.from('orders').insert([{
            id: newO.id,
            product_id: newO.productId,
            part_name: newO.partName,
            client_first_name: newO.clientFirstName,
            client_last_name: newO.clientLastName,
            client_name: newO.clientName,
            client_phone: newO.clientPhone,
            delivery_address: newO.deliveryAddress,
            delivery_notes: newO.deliveryNotes,
            delivery_gps: newO.deliveryGps,
            solvency_score: newO.solvencyScore,
            solvency_status: newO.solvencyStatus,
            vendor_id: newO.vendorId,
            vendor_code: newO.vendorCode,
            vendor_name: newO.vendorName,
            vendor_shop_location: newO.vendorShopLocation,
            vendor_phone: newO.vendorPhone,
            payment_provider: newO.provider,
            vendor_bank_price: newO.vendorBankPrice,
            vendor_net_price: newO.vendorNetPrice,
            commission: newO.commission,
            platform_retainer: newO.platformRetainer,
            total_paid: newO.totalPaid,
            pickup_code: newO.pickupCode,
            step: newO.step,
            step_label: newO.stepLabel,
            vendor_payment_status: newO.vendorPaymentStatus,
            action_required: newO.actionRequired,
            timeline: newO.timeline,
            created_at: newO.createdAt
          }]).then(() => {}).catch(() => {});
        } catch (e) {}

        // Enregistrement et synchronisation automatique du profil acheteur dans Supabase
        syncUserProfileToSupabase({
          phone: clientPhone,
          firstName: clientFirstName,
          lastName: clientLastName,
          role: 'buyer',
          organization: body.garageName || 'Garage Client Difonsé',
          hub: 'Dakar',
          address: newO.deliveryAddress,
          deliveryGps: newO.deliveryGps,
          solvencyScore: solvencyScore,
          solvencyStatus: solvencyStatus
        });
      }
    });

    saveDataFile('orders.json', orders);
    saveDataFile('users.json', users);

    return sendJson(200, {
      success: true,
      count: createdOrders.length,
      order: createdOrders[0],
      orders: createdOrders
    });
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
      logActivity("platform", "Plateforme Difonsé", "TEST_PERIOD_STARTED", `Délai d'essai 48h démarré pour ${found.id}`, 0, "timer");
    }

    return sendJson(200, { success: true, order: found });
  }

  // ROUTE 9: POST /api/orders/confirm (Clôture de la transaction après essai conforme au garage)
  if (route === '/orders/confirm' && req.method === 'POST') {
    const body = await parseBody();
    let found = null;
    orders.forEach(o => {
      if (o.id === body.id) {
        o.step = 4;
        o.stepLabel = "Pièce Conforme Validée · Transaction Clôturée";
        o.actionRequired = "Aucune action requise (Terminé)";
        o.timeline = "Validé conforme par le mécanicien au garage. Transaction finalisée avec succès (Vendeur payé directement à la commande).";
        found = o;
      }
    });
    saveDataFile('orders.json', orders);

    if (found) {
      users.forEach(u => {
        if (u.shopName === found.vendorName || u.id === found.vendorId) {
          u.escrowBalance = 0;
          if (found.vendorPaymentStatus !== "PAID_DIRECT") {
            u.availableBalance = (u.availableBalance || 0) + (found.vendorNetPrice || found.vendorBankPrice);
            u.totalSales = (u.totalSales || 0) + (found.vendorNetPrice || found.vendorBankPrice);
          }
        }
      });
      saveDataFile('users.json', users);

      logActivity("buyer", found.clientName, "CONFORMITY_CONFIRMED", `Montage validé conforme pour ${found.id}`, 0, "verified");
      logActivity("platform", "Plateforme Difonsé", "TRANSACTION_FINALIZED", `Transaction ${found.id} clôturée : Vendeur ${found.vendorName} rémunéré directement, retainer encaissé`, 0, "task_alt");
    }

    return sendJson(200, { success: true, order: found });
  }

  // ROUTE 9b: POST /api/orders/return (Garantie conformité 2 jours max : Retour pièce non conforme & Remboursement)
  if (route === '/orders/return' && req.method === 'POST') {
    const body = await parseBody();
    const orderId = body.id || body.orderId;
    let found = null;
    orders.forEach(o => {
      if (o.id === orderId) {
        o.step = 5;
        o.status = "RETURNED_REFUNDED";
        o.stepLabel = "Pièce Non Conforme Retournée · Remboursement Effectué (Garantie 2 Jours)";
        o.actionRequired = "Coursier Tiak-Tiak : Restituer la pièce au vendeur · Acheteur remboursé via Wave/OM";
        o.timeline = `Garantie conformité 2 jours invoquée : ${body.reason || "Pièce non conforme retournée"}. Remboursement intégral de ${o.totalPaid} FCFA exécuté vers l'acheteur via ${o.provider}.`;
        found = o;
      }
    });
    saveDataFile('orders.json', orders);

    if (found) {
      // Enregistrer le remboursement acheteur dans payouts.json
      const refundRecord = {
        id: "PAY-REF-" + Math.floor(1000 + Math.random() * 9000),
        vendor: found.clientName,
        phone: found.clientPhone || "+221 77 450 12 34",
        amount: found.totalPaid,
        provider: found.provider || "Wave",
        status: "COMPLETED",
        statusLabel: "Remboursement Exécuté (Garantie 2 Jours)",
        type: "REFUND_NON_COMPLIANT_PART",
        orderId: found.id,
        createdAt: new Date().toISOString()
      };
      payouts.unshift(refundRecord);
      saveDataFile('payouts.json', payouts);

      logActivity("buyer", found.clientName, "PART_RETURN_REQUESTED", `Retour pièce non conforme sous garantie 2 jours pour ${found.id} (${found.partName})`, found.totalPaid, "replay");
      logActivity("platform", "Plateforme Difonsé", "BUYER_REFUNDED", `Remboursement intégral effectué : ${found.totalPaid} FCFA à ${found.clientName} via ${found.provider} (Garantie 48h conformité)`, found.totalPaid, "payments");
      logActivity("seller", found.vendorName, "RETURN_DISPATCHED", `Coursier Tiak-Tiak mandaté pour restitution de ${found.partName} au vendeur`, 0, "local_shipping");
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
        o.stepLabel = "Litige Ouvert · Arbitrage en Cours";
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
    logActivity("arbitration", "Plateforme Difonsé", "DISPUTE_OPENED", `Dossier litige ouvert ${newDisp.id} (${newDisp.amount} FCFA)`, newDisp.amount, "gavel");

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
    const rawSign = `${dId}_${amt}_${recip}_${nowStr}_DIFONSE_ARBITRATION_FINAL`;
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

    logActivity("arbitration", "Comité d'Arbitrage Difonsé", "ARBITRATION_RESOLVED", `Litige ${dId} scellé SHA-256 (${sha256Seal.substring(0, 16)}...). Remboursement intégral de ${amt} FCFA via Wave.`, amt, "verified_user");

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
      vendorName: vUser ? vUser.shopName : "Boutique Modou",
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
      name: body.name || body.title || "Pièce Auto",
      shopName: body.shopName,
      ninea: body.ninea || "00" + Math.floor(1000000 + Math.random() * 9000000) + "-2K",
      boxNumber: body.boxNumber || "Box #" + Math.floor(10 + Math.random() * 290),
      phone: body.phone,
      hub: body.hub || "Pikine",
      availableBalance: 0,
      totalSales: 0,
      rating: 5.0,
      isOpen: true,
      registeredAt: new Date().toISOString()
    };

    users.unshift(newSeller);
    saveDataFile('users.json', users);

    logActivity("seller", newSeller.shopName, "SELLER_REGISTERED", `Nouvelle boutique créée : ${newSeller.shopName} au hub ${newSeller.hub}`, 0, "store");

    return sendJson(200, { success: true, seller: newSeller });
  }

  // ROUTE 17: POST /api/auth/login
  if (route === '/auth/login' && req.method === 'POST') {
    const body = await parseBody();
    const firstName = (body.firstName || '').trim();
    const lastName = (body.lastName || '').trim();
    const phone = (body.phone || '').trim();
    const role = body.role || 'buyer';

    const cleanPh = phone.replace(/[^0-9]/g, '');
    let matched = null;
    if (body.id) {
      matched = users.find(u => u.id === body.id);
    }
    if (!matched && cleanPh) {
      const phSuffix = cleanPh.slice(-9);
      matched = users.find(u => {
        const uClean = (u.phone || '').replace(/[^0-9]/g, '');
        return uClean.endsWith(phSuffix) && u.role === role;
      });
    }

    const isDemoModou = (role === 'seller' && cleanPh.endsWith('778904512') && firstName.toLowerCase().trim() === 'modou' && lastName.toLowerCase().trim() === 'ndiaye');
    const isDemoAmadou = (role === 'buyer' && cleanPh.endsWith('774501234') && firstName.toLowerCase().trim() === 'amadou' && lastName.toLowerCase().trim() === 'diallo');

    const finalFirst = firstName || (matched ? matched.firstName : (isDemoAmadou ? 'Amadou' : (isDemoModou ? 'Modou' : '')));
    const finalLast = lastName || (matched ? matched.lastName : (isDemoAmadou ? 'Diallo' : (isDemoModou ? 'Ndiaye' : '')));
    const fullName = (finalFirst || finalLast) ? `${finalFirst} ${finalLast}`.trim() : (isDemoAmadou ? 'Amadou Diallo' : (isDemoModou ? 'Modou Ndiaye' : 'Utilisateur Difonsé'));

    const userId = matched ? matched.id : (isDemoModou ? 'usr_seller_1' : (isDemoAmadou ? 'usr_buyer_1' : (body.id || `usr_${role}_${cleanPh || Date.now()}`)));
    const vCode = (matched && matched.vendorCode) || body.vendorCode || (cleanPh ? `VND-${cleanPh.slice(-6)}` : `VND-${Math.floor(100000 + Math.random() * 900000)}`);

    const userSession = {
      id: userId,
      vendorCode: role === 'seller' ? vCode : null,
      role: role,
      firstName: finalFirst,
      lastName: finalLast,
      name: fullName,
      phone: phone || (matched ? matched.phone : (isDemoAmadou ? '+221 77 450 12 34' : (isDemoModou ? '+221 77 890 45 12' : ''))),
      garageName: body.garageName || (matched && matched.garageName) || (isDemoAmadou ? 'Garage Castors Dakar' : ''),
      shopName: body.shopName || (matched && matched.shopName) || (isDemoModou ? 'Boutique Modou Pièces Auto' : ''),
      location: body.location || body.hub || (matched && matched.location) || 'Dakar',
      hub: body.location || body.hub || (matched && matched.hub) || 'Dakar',
      activeCar: body.activeCar || (matched && matched.activeCar) || (isDemoAmadou ? 'Toyota Hilux Vigo 2.5 D-4D' : ''),
      solvencyScore: (matched && matched.solvencyScore) || (role === 'buyer' ? 98 : 95),
      solvencyStatus: (matched && matched.solvencyStatus) || (role === 'buyer' ? 'Solvable Vérifié' : 'Vendeur Certifié'),
      solvencyDetails: 'Client vérifié par Wave / Orange Money sans défaut de paiement.',
      availableBalance: (matched && matched.availableBalance != null) ? matched.availableBalance : (isDemoModou ? 570000 : 0),
      totalSales: (matched && matched.totalSales != null) ? matched.totalSales : (isDemoModou ? 2390000 : 0),
      rating: (matched && matched.rating) || 5.0,
      isOpen: true
    };

    // Sauvegarde en mémoire & persistante du profil utilisateur
    const matchIdx = users.findIndex(u => u.phone === userSession.phone && u.role === userSession.role);
    if (matchIdx >= 0) {
      users[matchIdx] = { ...users[matchIdx], ...userSession };
    } else {
      users.push(userSession);
    }
    saveDataFile('users.json', users);

    // Synchronisation automatique et instantanée dans Supabase (Profiles & User Connections)
    syncUserProfileToSupabase(userSession);

    logActivity(userSession.role, userSession.name, "LOGIN", `Connexion réussie : ${userSession.name} (${userSession.role === 'buyer' ? 'Acheteur · Solvabilité ' + userSession.solvencyScore + '/100' : 'Vendeur'})`, 0, "login");
    return sendJson(200, { success: true, user: userSession });
  }

  // ROUTE 18: GET /api/profiles (Liste complète des profils inscrits pour le Super Admin)
  if (route === '/profiles' && req.method === 'GET') {
    if (supabaseServerClient) {
      try {
        const { data: dbProfiles, error } = await supabaseServerClient
          .from('profiles')
          .select('*')
          .order('created_at', { ascending: false });
        if (!error && dbProfiles && dbProfiles.length > 0) {
          return sendJson(200, dbProfiles);
        }
      } catch (e) {}
    }
    return sendJson(200, users);
  }

  // ROUTE 19: POST /api/profiles (Enregistrement ou mise à jour directe d'un profil)
  if (route === '/profiles' && req.method === 'POST') {
    const body = await parseBody();
    const phone = (body.phone || '').trim();
    if (!phone) return sendJson(400, { error: "Numéro de téléphone requis" });
    const userProfile = {
      phone: phone,
      firstName: (body.firstName || '').trim(),
      lastName: (body.lastName || '').trim(),
      name: `${body.firstName || ''} ${body.lastName || ''}`.trim(),
      role: body.role || 'buyer',
      shopName: body.shopName || '',
      garageName: body.garageName || '',
      organization: body.organization || body.shopName || body.garageName || '',
      hub: body.hub || body.location || 'Dakar',
      address: body.address || '',
      gps: body.gps || null,
      solvencyScore: Number(body.solvencyScore) || 98,
      solvencyStatus: body.solvencyStatus || 'Solvable Vérifié'
    };

    const matchIdx = users.findIndex(u => u.phone === userProfile.phone && u.role === userProfile.role);
    if (matchIdx >= 0) {
      users[matchIdx] = { ...users[matchIdx], ...userProfile };
    } else {
      users.push(userProfile);
    }
    saveDataFile('users.json', users);

    syncUserProfileToSupabase(userProfile);
    return sendJson(200, { success: true, profile: userProfile });
  }

  // 404 Route non trouvée
  return sendJson(404, { error: `Route API introuvable: ${pathname}` });
};
