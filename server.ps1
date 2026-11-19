$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Start()
Write-Output "Backend REST API & Web Server listening on http://localhost:8080/"

$baseDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($baseDir)) {
    $baseDir = (Get-Location).Path
}
$dataDir = Join-Path $baseDir "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

function Helper-ReadJsonFile($fileName) {
    $p = Join-Path $dataDir $fileName
    if (Test-Path -LiteralPath $p) {
        $content = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
        return $content
    }
    return "[]"
}

function Helper-WriteJsonFile($fileName, $obj) {
    $p = Join-Path $dataDir $fileName
    $json = $obj | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($p, $json, [System.Text.Encoding]::UTF8)
}

function Helper-LogActivity($section, $actor, $action, $details, $amount, $icon) {
    try {
        $actsJson = Helper-ReadJsonFile "activities.json"
        $acts = $actsJson | ConvertFrom-Json
        if ($null -eq $acts) { $acts = @() }

        $newAct = [PSCustomObject]@{
            id = "act_" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            timestamp = [DateTime]::UtcNow.ToString("o")
            section = $section
            actor = $actor
            action = $action
            details = $details
            amount = [int]$amount
            icon = $icon
        }

        $allActs = @($newAct) + @($acts)
        if ($allActs.Count -gt 200) {
            $allActs = $allActs[0..199]
        }
        Helper-WriteJsonFile "activities.json" $allActs
    } catch {
        Write-Output "Error logging activity: $_"
    }
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        # CORS
        $response.AddHeader("Access-Control-Allow-Origin", "*")
        $response.AddHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        $response.AddHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")

        if ($request.HttpMethod -eq "OPTIONS") {
            $response.StatusCode = 200
            $response.Close()
            continue
        }

        $rawPath = [System.Uri]::UnescapeDataString($request.Url.LocalPath)

        # ----------------- REST API ROUTES -----------------
        if ($rawPath.StartsWith("/api/")) {
            $response.ContentType = "application/json; charset=utf-8"
            $respObj = $null

            # Read Body if POST / PUT
            $bodyText = ""
            if ($request.HasEntityBody) {
                $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
                $bodyText = $reader.ReadToEnd()
                $reader.Close()
            }
            $bodyObj = $null
            if (-not [string]::IsNullOrWhiteSpace($bodyText)) {
                try { $bodyObj = $bodyText | ConvertFrom-Json } catch { $bodyObj = $null }
            }

            # 1. GET /api/stats (Platform global aggregated audit metrics)
            if ($rawPath -eq "/api/stats" -and $request.HttpMethod -eq "GET") {
                $orders = (Helper-ReadJsonFile "orders.json") | ConvertFrom-Json
                $acts = (Helper-ReadJsonFile "activities.json") | ConvertFrom-Json
                $prods = (Helper-ReadJsonFile "products.json") | ConvertFrom-Json
                $disputes = (Helper-ReadJsonFile "disputes.json") | ConvertFrom-Json
                $payouts = (Helper-ReadJsonFile "payouts.json") | ConvertFrom-Json

                $totEscrow = 0
                $totComm = 0
                $totGmv = 0
                $activeCount = 0
                $totPendingRefunds = 0

                foreach ($o in $orders) {
                    $totGmv += $o.totalPaid
                    if ($o.step -lt 4) {
                        $totEscrow += $o.totalPaid
                        $activeCount++
                    } else {
                        $totComm += $o.commission
                    }
                }

                if ($null -ne $disputes) {
                    foreach ($d in $disputes) {
                        if ($d.status -eq "OPEN") {
                            $totPendingRefunds += $d.amount
                        }
                    }
                }

                $buyerActs = ($acts | Where-Object { $_.section -eq "buyer" }).Count
                $sellerActs = ($acts | Where-Object { $_.section -eq "seller" }).Count
                $escrowActs = ($acts | Where-Object { $_.section -eq "escrow" }).Count

                $openDisputesCount = if ($disputes) { ($disputes | Where-Object { $_.status -eq "OPEN" }).Count } else { 0 }

                $respObj = @{
                    totalEscrow = $totEscrow
                    totalCommissions = $totComm
                    totalGMV = $totGmv
                    activeEscrowOrders = $activeCount
                    pendingRefundsAmount = $totPendingRefunds
                    openDisputesCount = $openDisputesCount
                    totalProducts = if ($prods) { $prods.Count } else { 0 }
                    totalActivities = if ($acts) { $acts.Count } else { 0 }
                    totalPayouts = if ($payouts) { $payouts.Count } else { 0 }
                    activityCounts = @{
                        buyer = $buyerActs
                        seller = $sellerActs
                        escrow = $escrowActs
                        total = if ($acts) { $acts.Count } else { 0 }
                    }
                }
            }
            # 2. GET /api/activities
            elseif ($rawPath -eq "/api/activities" -and $request.HttpMethod -eq "GET") {
                $sec = $request.QueryString["section"]
                $all = (Helper-ReadJsonFile "activities.json") | ConvertFrom-Json
                if ($null -eq $all) { $all = @() }

                if (-not [string]::IsNullOrWhiteSpace($sec) -and $sec -ne "all") {
                    $filtered = $all | Where-Object { $_.section -eq $sec }
                    $respObj = @($filtered)
                } else {
                    $respObj = @($all)
                }
            }
            # 3. POST /api/activities
            elseif ($rawPath -eq "/api/activities" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    Helper-LogActivity $bodyObj.section $bodyObj.actor $bodyObj.action $bodyObj.details $bodyObj.amount $bodyObj.icon
                    $respObj = @{ success = $true; message = "Activity logged" }
                }
            }
            # 4. GET /api/products
            elseif ($rawPath -eq "/api/products" -and $request.HttpMethod -eq "GET") {
                $respObj = (Helper-ReadJsonFile "products.json") | ConvertFrom-Json
            }
            # 5. POST /api/products (Vendor adds a product with bank price)
            elseif ($rawPath -eq "/api/products" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $prods = (Helper-ReadJsonFile "products.json") | ConvertFrom-Json
                    if ($null -eq $prods) { $prods = @() }

                    $bPrice = [int]$bodyObj.bankPrice
                    $comm = [Math]::Round($bPrice * 0.10)
                    $pubPrice = $bPrice + $comm

                    $newP = [PSCustomObject]@{
                        id = "p_" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                        name = $bodyObj.name
                        oem = if ($bodyObj.oem) { $bodyObj.oem } else { "OEM-" + (Get-Random -Minimum 1000 -Maximum 9999) }
                        vehicle = $bodyObj.vehicle
                        category = $bodyObj.category
                        condition = $bodyObj.condition
                        conditionLabel = if ($bodyObj.condition -eq "neuf") { "Neuf d'Origine OEM" } elseif ($bodyObj.condition -eq "occasion") { "Occasion Testée" } else { "Adaptable Certifié" }
                        bankPrice = $bPrice
                        commission = $comm
                        publicPrice = $pubPrice
                        vendorId = if ($bodyObj.vendorId) { $bodyObj.vendorId } else { "usr_seller_1" }
                        vendor = if ($bodyObj.vendor) { $bodyObj.vendor } else { "Échoppe Modou" }
                        hub = if ($bodyObj.hub) { $bodyObj.hub } else { "Pikine" }
                        image = if ($bodyObj.image) { $bodyObj.image } else { "https://images.unsplash.com/photo-1486006920555-c77dce18193b?auto=format&fit=crop&w=600&q=80" }
                        stock = if ($bodyObj.stock) { [int]$bodyObj.stock } else { 1 }
                        compatibleCar = if ($bodyObj.compatibleCar) { $bodyObj.compatibleCar } else { $bodyObj.vehicle }
                    }

                    $allProds = @($newP) + @($prods)
                    Helper-WriteJsonFile "products.json" $allProds

                    Helper-LogActivity "seller" $newP.vendor "ADD_PRODUCT" ("Mise en vente: " + $newP.name + " (Prix banque: " + $newP.bankPrice + " FCFA | Prix client: " + $newP.publicPrice + " FCFA)") $newP.bankPrice "add_circle"
                    $respObj = @{ success = $true; product = $newP }
                }
            }
            # 6. GET /api/orders
            elseif ($rawPath -eq "/api/orders" -and $request.HttpMethod -eq "GET") {
                $respObj = (Helper-ReadJsonFile "orders.json") | ConvertFrom-Json
            }
            # 7. POST /api/orders (Acheteur places order with Escrow)
            elseif ($rawPath -eq "/api/orders" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $orders = (Helper-ReadJsonFile "orders.json") | ConvertFrom-Json
                    if ($null -eq $orders) { $orders = @() }

                    $cmdId = "CMD-" + (Get-Random -Minimum 1000 -Maximum 9999)
                    $pkCode = "PK-" + (Get-Random -Minimum 100 -Maximum 999)

                    $newO = [PSCustomObject]@{
                        id = $cmdId
                        productId = $bodyObj.productId
                        partName = $bodyObj.partName
                        clientName = $bodyObj.clientName
                        clientPhone = $bodyObj.clientPhone
                        vendorId = $bodyObj.vendorId
                        vendorName = $bodyObj.vendorName
                        vendorBankPrice = [int]$bodyObj.vendorBankPrice
                        commission = [int]$bodyObj.commission
                        totalPaid = [int]$bodyObj.totalPaid
                        provider = $bodyObj.provider
                        pickupCode = $pkCode
                        step = 2
                        stepLabel = "Fonds Séquestrés · Tiak-Tiak en route vers l'échoppe"
                        actionRequired = "Vendeur : Remettre la pièce au coursier contre le code $pkCode"
                        timeline = "Commande créée avec succès via " + $bodyObj.provider + ". Code retrait coursier: " + $pkCode
                        createdAt = [DateTime]::UtcNow.ToString("o")
                    }

                    $allOrders = @($newO) + @($orders)
                    Helper-WriteJsonFile "orders.json" $allOrders

                    # Update seller escrow balance
                    $users = (Helper-ReadJsonFile "users.json") | ConvertFrom-Json
                    foreach ($u in $users) {
                        if ($u.shopName -eq $newO.vendorName -or $u.id -eq $newO.vendorId) {
                            $u.escrowBalance += $newO.vendorBankPrice
                        }
                    }
                    Helper-WriteJsonFile "users.json" $users

                    Helper-LogActivity "buyer" $newO.clientName "ORDER_PLACED" ("Achat avec séquestre: " + $newO.partName + " (" + $newO.totalPaid + " FCFA) via " + $newO.provider) $newO.totalPaid "shopping_bag"
                    Helper-LogActivity "escrow" "Plateforme Difonssé" "FUNDS_LOCKED" ("Fonds bloqués sous séquestre pour " + $newO.id + " (Prix vendeur: " + $newO.vendorBankPrice + " | Commission: " + $newO.commission + ")") $newO.totalPaid "lock"

                    $respObj = @{ success = $true; order = $newO }
                }
            }
            # 8. POST /api/orders/advance (Vendor hands over to courier)
            elseif ($rawPath -eq "/api/orders/advance" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $orders = (Helper-ReadJsonFile "orders.json") | ConvertFrom-Json
                    $found = $null
                    foreach ($o in $orders) {
                        if ($o.id -eq $bodyObj.id) {
                            $o.step = 3
                            $o.stepLabel = "Pièce livrée au Garage · Montage & Essai en cours (48h)"
                            $o.actionRequired = "Mécanicien : Tester la pièce sur le véhicule et valider conformité"
                            $o.timeline = "Remise effectuée au coursier avec code " + $o.pickupCode + ". Délai d'essai démarré."
                            $found = $o
                        }
                    }
                    Helper-WriteJsonFile "orders.json" $orders

                    if ($null -ne $found) {
                        Helper-LogActivity "seller" $found.vendorName "COURIER_PICKUP" ("Pièce remise au coursier pour " + $found.id + " contre code " + $found.pickupCode) 0 "local_shipping"
                        Helper-LogActivity "escrow" "Plateforme Difonssé" "TEST_PERIOD_STARTED" ("Délai d'essai 48h démarré pour " + $found.id) 0 "timer"
                    }

                    $respObj = @{ success = $true; order = $found }
                }
            }
            # 9. POST /api/orders/confirm (Mechanic confirms conformity & releases funds)
            elseif ($rawPath -eq "/api/orders/confirm" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $orders = (Helper-ReadJsonFile "orders.json") | ConvertFrom-Json
                    $found = $null
                    foreach ($o in $orders) {
                        if ($o.id -eq $bodyObj.id) {
                            $o.step = 4
                            $o.stepLabel = "Pièce Conforme Validée · Fonds Débloqués"
                            $o.actionRequired = "Aucune action requise (Terminé)"
                            $o.timeline = "Validé conforme par le mécanicien au garage. Vendeur crédité."
                            $found = $o
                        }
                    }
                    Helper-WriteJsonFile "orders.json" $orders

                    # Move funds from escrow to available balance
                    $users = (Helper-ReadJsonFile "users.json") | ConvertFrom-Json
                    foreach ($u in $users) {
                        if ($u.shopName -eq $found.vendorName -or $u.id -eq $found.vendorId) {
                            $u.escrowBalance -= $found.vendorBankPrice
                            if ($u.escrowBalance -lt 0) { $u.escrowBalance = 0 }
                            $u.availableBalance += $found.vendorBankPrice
                            $u.totalSales += $found.vendorBankPrice
                        }
                    }
                    Helper-WriteJsonFile "users.json" $users

                    Helper-LogActivity "buyer" $found.clientName "CONFORMITY_CONFIRMED" ("Montage validé conforme pour " + $found.id) 0 "verified"
                    Helper-LogActivity "escrow" "Plateforme Difonssé" "FUNDS_RELEASED" ("Libération du séquestre : " + $found.vendorBankPrice + " FCFA versés au vendeur " + $found.vendorName) $found.vendorBankPrice "payments"

                    $respObj = @{ success = $true; order = $found }
                }
            }
            # 10. POST /api/orders/dispute (Buyer raises dispute on an order)
            elseif ($rawPath -eq "/api/orders/dispute" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $orders = (Helper-ReadJsonFile "orders.json") | ConvertFrom-Json
                    $foundOrder = $null
                    foreach ($o in $orders) {
                        if ($o.id -eq $bodyObj.orderId) {
                            $o.step = 5
                            $o.stepLabel = "Litige Ouvert · Séquestre Gelé"
                            $o.actionRequired = "Superviseur : Arbitrage contradictoire requis"
                            $o.timeline = "Litige déclaré par le garage : " + $bodyObj.reason
                            $foundOrder = $o
                        }
                    }
                    Helper-WriteJsonFile "orders.json" $orders

                    $disputes = (Helper-ReadJsonFile "disputes.json") | ConvertFrom-Json
                    if ($null -eq $disputes) { $disputes = @() }

                    $newDispId = "DIF-" + [DateTime]::UtcNow.Year + "-" + (Get-Random -Minimum 100000 -Maximum 999999)
                    $newDisp = [PSCustomObject]@{
                        id = $newDispId
                        orderId = $bodyObj.orderId
                        partName = if ($foundOrder) { $foundOrder.partName } else { "Pièce" }
                        buyerName = if ($foundOrder) { $foundOrder.clientName } else { "Acheteur" }
                        buyerPhone = if ($foundOrder) { $foundOrder.clientPhone } else { "" }
                        vendorName = if ($foundOrder) { $foundOrder.vendorName } else { "Vendeur" }
                        vendorPhone = "+221 77 890 45 12"
                        amount = if ($foundOrder) { $foundOrder.totalPaid } else { 0 }
                        provider = if ($foundOrder) { $foundOrder.provider } else { "Wave" }
                        reason = $bodyObj.reason
                        buyerStatement = $bodyObj.buyerStatement
                        vendorStatement = "En attente de retour de la pièce pour vérification en boutique."
                        status = "OPEN"
                        statusLabel = "Litige Ouvert · Fonds Gelés"
                        actionRequired = "Arbitrage Superviseur requis (Remboursement ou Déblocage)"
                        createdAt = [DateTime]::UtcNow.ToString("o")
                    }

                    $allDisps = @($newDisp) + @($disputes)
                    Helper-WriteJsonFile "disputes.json" $allDisps

                    Helper-LogActivity "buyer" $newDisp.buyerName "DISPUTE_OPENED" ("Litige ouvert " + $newDisp.id + " pour commande " + $newDisp.orderId + " (" + $newDisp.reason + ")") $newDisp.amount "report_problem"
                    Helper-LogActivity "escrow" "Plateforme Difonssé" "FUNDS_FROZEN" ("Séquestre gelé pour litige " + $newDisp.id + " (" + $newDisp.amount + " FCFA)") $newDisp.amount "gavel"

                    $respObj = @{ success = $true; dispute = $newDisp }
                }
            }
            # 11. GET /api/disputes
            elseif ($rawPath -eq "/api/disputes" -and $request.HttpMethod -eq "GET") {
                $respObj = (Helper-ReadJsonFile "disputes.json") | ConvertFrom-Json
            }
            # 12. POST /api/disputes/arbitrate (Admin resolves dispute with SHA-256 seal)
            elseif ($rawPath -eq "/api/disputes/arbitrate" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $dId = $bodyObj.dossierId
                    $decision = if ($bodyObj.decision) { $bodyObj.decision } else { "REFUND_BUYER" }
                    $disputes = (Helper-ReadJsonFile "disputes.json") | ConvertFrom-Json
                    $targetDisp = $null

                    foreach ($d in $disputes) {
                        if ($d.id -eq $dId -or $d.orderId -eq $dId) {
                            $d.status = "RESOLVED"
                            $d.statusLabel = if ($decision -eq "REFUND_BUYER") { "Résolu · Remboursement Acheteur Scellé" } else { "Résolu · Fonds Libérés Vendeur" }
                            $d.actionRequired = "Dossier clos (Archivé)"
                            $targetDisp = $d
                        }
                    }
                    Helper-WriteJsonFile "disputes.json" $disputes

                    # SHA-256 seal computation
                    $nowStr = [DateTime]::UtcNow.ToString("o")
                    $amt = if ($targetDisp) { $targetDisp.amount } else { 49500 }
                    $recip = if ($targetDisp) { $targetDisp.buyerName } else { "Acheteur" }
                    $rawSign = "${dId}_${amt}_${recip}_${nowStr}_ESCROW_ARBITRATION_FINAL"
                    $sha = [System.Security.Cryptography.SHA256]::Create()
                    $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($rawSign))
                    $sha256Seal = [BitConverter]::ToString($hashBytes).Replace("-","").ToLower()

                    # Update associated order
                    if ($null -ne $targetDisp) {
                        $orders = (Helper-ReadJsonFile "orders.json") | ConvertFrom-Json
                        foreach ($o in $orders) {
                            if ($o.id -eq $targetDisp.orderId) {
                                $o.step = 6
                                $o.stepLabel = "Remboursement Intégral Scellé SHA-256"
                                $o.actionRequired = "Dossier archivé · Empreinte " + $sha256Seal.Substring(0, 12) + "..."
                                $o.timeline = "Litige clos. Remboursement Wave exécuté avec sceau SHA-256."
                            }
                        }
                        Helper-WriteJsonFile "orders.json" $orders
                    }

                    Helper-LogActivity "escrow" "Comité d'Arbitrage Difonssé" "ARBITRATION_RESOLVED" ("Litige " + $dId + " scellé SHA-256 (" + $sha256Seal.Substring(0, 16) + "...). Remboursement intégral de " + $amt + " FCFA via Wave.") $amt "verified_user"

                    $respObj = @{
                        success = $true
                        dossierId = $dId
                        decision = $decision
                        sha256Seal = $sha256Seal
                        amount = $amt
                        status = "RESOLVED"
                        message = "Litige scellé et exécuté avec succès."
                    }
                }
            }
            # 13. GET /api/payouts
            elseif ($rawPath -eq "/api/payouts" -and $request.HttpMethod -eq "GET") {
                $respObj = (Helper-ReadJsonFile "payouts.json") | ConvertFrom-Json
            }
            # 14. POST /api/payouts (Vendor payout to Wave/OM)
            elseif ($rawPath -eq "/api/payouts" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $payouts = (Helper-ReadJsonFile "payouts.json") | ConvertFrom-Json
                    if ($null -eq $payouts) { $payouts = @() }

                    $amt = [int]$bodyObj.amount
                    $phone = $bodyObj.phone
                    $prov = $bodyObj.provider

                    $users = (Helper-ReadJsonFile "users.json") | ConvertFrom-Json
                    $vUser = $null
                    foreach ($u in $users) {
                        if ($u.role -eq "seller") {
                            $vUser = $u
                            if ($u.availableBalance -ge $amt) {
                                $u.availableBalance -= $amt
                            }
                            break
                        }
                    }
                    Helper-WriteJsonFile "users.json" $users

                    $newPay = [PSCustomObject]@{
                        id = "pay_" + (Get-Random -Minimum 100 -Maximum 999)
                        vendorId = if ($vUser) { $vUser.id } else { "usr_seller_1" }
                        vendorName = if ($vUser) { $vUser.shopName } else { "Échoppe Modou" }
                        amount = $amt
                        provider = $prov
                        recipientPhone = $phone
                        status = "COMPLETED"
                        actionRequired = "Aucune (Virement automatique exécuté)"
                        timestamp = [DateTime]::UtcNow.ToString("o")
                    }

                    $allPayouts = @($newPay) + @($payouts)
                    Helper-WriteJsonFile "payouts.json" $allPayouts

                    Helper-LogActivity "seller" $newPay.vendorName "PAYOUT_TRANSFER" ("Virement " + $prov + " effectué avec succès vers " + $phone + " (" + $amt + " FCFA)") $amt "arrow_circle_up"
                    $respObj = @{ success = $true; payout = $newPay; newBalance = if ($vUser) { $vUser.availableBalance } else { 0 } }
                }
            }
            # 15. GET /api/users
            elseif ($rawPath -eq "/api/users" -and $request.HttpMethod -eq "GET") {
                $respObj = (Helper-ReadJsonFile "users.json") | ConvertFrom-Json
            }
            # 16. POST /api/users/upgrade-seller (Buyer clicks "Devenir Vendeur")
            elseif ($rawPath -eq "/api/users/upgrade-seller" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $users = (Helper-ReadJsonFile "users.json") | ConvertFrom-Json
                    if ($null -eq $users) { $users = @() }

                    $newSeller = [PSCustomObject]@{
                        id = "usr_seller_" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                        role = "seller"
                        name = $bodyObj.name
                        shopName = $bodyObj.shopName
                        ninea = if ($bodyObj.ninea) { $bodyObj.ninea } else { "00" + (Get-Random -Minimum 1000000 -Maximum 9999999) + "-2K" }
                        boxNumber = if ($bodyObj.boxNumber) { $bodyObj.boxNumber } else { "Box #" + (Get-Random -Minimum 10 -Maximum 299) }
                        phone = $bodyObj.phone
                        hub = if ($bodyObj.hub) { $bodyObj.hub } else { "Pikine" }
                        availableBalance = 0
                        escrowBalance = 0
                        totalSales = 0
                        rating = 5.0
                        isOpen = $true
                        registeredAt = [DateTime]::UtcNow.ToString("o")
                    }

                    $allUsers = @($newSeller) + @($users)
                    Helper-WriteJsonFile "users.json" $allUsers

                    Helper-LogActivity "seller" $newSeller.shopName "SELLER_REGISTERED" ("Nouvelle échoppe créée : " + $newSeller.shopName + " au hub " + $newSeller.hub) 0 "store"
                    $respObj = @{ success = $true; seller = $newSeller }
                }
            }
            # 17. POST /api/auth/login
            elseif ($rawPath -eq "/api/auth/login" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $users = (Helper-ReadJsonFile "users.json") | ConvertFrom-Json
                    $matched = $users | Where-Object { $_.role -eq $bodyObj.role } | Select-Object -First 1

                    if ($null -ne $matched) {
                        Helper-LogActivity $matched.role $matched.name "LOGIN" ("Connexion réussie à l'espace " + $matched.role) 0 "login"
                        $respObj = @{ success = $true; user = $matched }
                    } else {
                        $respObj = @{ success = $false; message = "Utilisateur non trouvé" }
                    }
                }
            } else {
                $response.StatusCode = 404
                $respObj = @{ error = "Route API introuvable: $rawPath" }
            }

            # Return JSON response
            $jsonOut = $respObj | ConvertTo-Json -Depth 8
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonOut)
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.Close()
            continue
        }

        # ----------------- STATIC FILE SERVER -----------------
        $relPath = $rawPath.TrimStart('/')
        if ([string]::IsNullOrWhiteSpace($relPath)) {
            $relPath = "index.html"
        }
        $relPath = $relPath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $filePath = Join-Path $baseDir $relPath

        if (Test-Path -LiteralPath $filePath -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $mime = switch ($ext) {
                ".html" { "text/html; charset=utf-8" }
                ".css"  { "text/css; charset=utf-8" }
                ".js"   { "application/javascript; charset=utf-8" }
                ".png"  { "image/png" }
                ".jpg"  { "image/jpeg" }
                ".jpeg" { "image/jpeg" }
                ".svg"  { "image/svg+xml" }
                ".json" { "application/json; charset=utf-8" }
                ".pdf"  { "application/pdf" }
                default { "application/octet-stream" }
            }
            $response.ContentType = $mime
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $response.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes("Fichier non trouve: $relPath")
            $response.ContentLength64 = $msg.Length
            $response.OutputStream.Write($msg, 0, $msg.Length)
        }
        $response.Close()
    } catch {
        # continue loop
    }
}
