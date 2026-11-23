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

                $totRetainer = 0
                $totVendorPayouts = 0
                $totGmv = 0
                $activeCount = 0
                $totPendingRefunds = 0

                foreach ($o in $orders) {
                    $totGmv += $o.totalPaid
                    $ret = if ($null -ne $o.platformRetainer) { [int]$o.platformRetainer } elseif ($null -ne $o.commission) { [int]$o.commission } else { [int][Math]::Round($o.vendorBankPrice * 0.10) }
                    $totRetainer += $ret
                    $vNet = if ($null -ne $o.vendorNetPrice) { [int]$o.vendorNetPrice } elseif ($null -ne $o.vendorBankPrice) { [int]$o.vendorBankPrice } else { ($o.totalPaid - $ret) }
                    $totVendorPayouts += $vNet
                    if ($o.step -lt 4) {
                        $activeCount++
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
                $platformActs = ($acts | Where-Object { $_.section -eq "platform" -or $_.section -eq "orders" }).Count

                $openDisputesCount = if ($disputes) { ($disputes | Where-Object { $_.status -eq "OPEN" }).Count } else { 0 }

                $respObj = @{
                    totalCommissions = $totRetainer
                    totalRetainers = $totRetainer
                    totalVendorPayouts = $totVendorPayouts
                    totalGMV = $totGmv
                    activeOrders = $activeCount
                    activeEscrowOrders = $activeCount
                    pendingRefundsAmount = $totPendingRefunds
                    openDisputesCount = $openDisputesCount
                    totalProducts = if ($prods) { $prods.Count } else { 0 }
                    totalActivities = if ($acts) { $acts.Count } else { 0 }
                    totalPayouts = if ($payouts) { $payouts.Count } else { 0 }
                    activityCounts = @{
                        buyer = $buyerActs
                        seller = $sellerActs
                        platform = $platformActs
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
            # 7. POST /api/orders (Paiement Direct Vendeur & Retainer Plateforme - Unitaire ou Panier Multi-pièces)
            elseif ($rawPath -eq "/api/orders" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $orders = (Helper-ReadJsonFile "orders.json") | ConvertFrom-Json
                    if ($null -eq $orders) { $orders = @() }
                    $users = (Helper-ReadJsonFile "users.json") | ConvertFrom-Json
                    if ($null -eq $users) { $users = @() }

                    $itemsToProcess = @()
                    if ($null -ne $bodyObj.items -and $bodyObj.items.Count -gt 0) {
                        $itemsToProcess = @($bodyObj.items)
                    } else {
                        $itemsToProcess = @($bodyObj)
                    }

                    $createdOrders = @()

                    foreach ($item in $itemsToProcess) {
                        $cmdId = "CMD-" + (Get-Random -Minimum 1000 -Maximum 9999)
                        $pkCode = "PK-" + (Get-Random -Minimum 100 -Maximum 999)

                        $cFirst = if ($item.clientFirstName) { $item.clientFirstName } elseif ($bodyObj.clientFirstName) { $bodyObj.clientFirstName } else { "Amadou" }
                        $cLast = if ($item.clientLastName) { $item.clientLastName } elseif ($bodyObj.clientLastName) { $bodyObj.clientLastName } else { "Diallo" }
                        $cFull = if ($item.clientName) { $item.clientName } elseif ($bodyObj.clientName) { $bodyObj.clientName } else { "$cFirst $cLast" }
                        $cPhone = if ($item.clientPhone) { $item.clientPhone } elseif ($bodyObj.clientPhone) { $bodyObj.clientPhone } else { "+221 77 450 12 34" }
                        $cScore = if ($item.solvencyScore) { [int]$item.solvencyScore } elseif ($bodyObj.solvencyScore) { [int]$bodyObj.solvencyScore } else { 98 }
                        $cStatus = if ($item.solvencyStatus) { $item.solvencyStatus } elseif ($bodyObj.solvencyStatus) { $bodyObj.solvencyStatus } else { "Solvable Vérifié" }

                        $vBank = if ($null -ne $item.vendorNetPrice) { [int]$item.vendorNetPrice } elseif ($null -ne $item.vendorBankPrice) { [int]$item.vendorBankPrice } elseif ($null -ne $item.bankPrice) { [int]$item.bankPrice } else { 0 }
                        $retainer = if ($null -ne $item.platformRetainer) { [int]$item.platformRetainer } elseif ($null -ne $item.commission) { [int]$item.commission } else { [int][Math]::Round($vBank * 0.10) }
                        $total = if ($null -ne $item.totalPaid) { [int]$item.totalPaid } else { ($vBank + $retainer) }
                        $prov = if ($item.provider) { $item.provider } elseif ($bodyObj.provider) { $bodyObj.provider } else { "Wave" }

                        $vId = if ($item.vendorId) { $item.vendorId } else { "usr_seller_1" }
                        $vName = if ($item.vendorName) { $item.vendorName } elseif ($item.vendor) { $item.vendor } else { "Échoppe Modou" }
                        $pName = if ($item.partName) { $item.partName } elseif ($item.name) { $item.name } else { "Pièce" }
                        $pId = if ($item.productId) { $item.productId } elseif ($item.id) { $item.id } else { "p1" }

                        $newO = [PSCustomObject]@{
                            id = $cmdId
                            productId = $pId
                            partName = $pName
                            clientFirstName = $cFirst
                            clientLastName = $cLast
                            clientName = $cFull
                            clientPhone = $cPhone
                            solvencyScore = $cScore
                            solvencyStatus = $cStatus
                            vendorId = $vId
                            vendorName = $vName
                            vendorBankPrice = $vBank
                            vendorNetPrice = $vBank
                            commission = $retainer
                            platformRetainer = $retainer
                            totalPaid = $total
                            provider = $prov
                            pickupCode = $pkCode
                            step = 2
                            stepLabel = "Payé par Difonsé · Tiak-Tiak en route vers l'échoppe"
                            vendorPaymentStatus = "PAID_DIRECT"
                            actionRequired = "Vendeur : Remettre la pièce payée au coursier contre le code $pkCode"
                            timeline = "Acheteur débité via " + $prov + ". Retainer Difonsé prélevé (" + $retainer + " FCFA). Vendeur payé directement (" + $vBank + " FCFA)."
                            createdAt = [DateTime]::UtcNow.ToString("o")
                        }

                        $orders = @($newO) + @($orders)
                        $createdOrders += @($newO)

                        # Update seller available balance directly
                        foreach ($u in $users) {
                            if ($u.shopName -eq $vName -or $u.id -eq $vId) {
                                $u.availableBalance += $vBank
                                $u.totalSales += $vBank
                                $u.totalRetainerPaid += $retainer
                            }
                        }

                        Helper-LogActivity "buyer" $cFull "ORDER_PLACED" ("Commande payée via " + $prov + " : " + $pName + " (" + $total + " FCFA)") $total "shopping_bag"
                        Helper-LogActivity "platform" "Plateforme Difonsé" "RETAINER_COLLECTED" ("Retainer plateforme prélevé : " + $retainer + " FCFA sur commande " + $cmdId) $retainer "savings"
                        Helper-LogActivity "seller" $vName "DIRECT_PAYMENT_RECEIVED" ("Paiement direct reçu : " + $vBank + " FCFA pour " + $pName) $vBank "payments"
                    }

                    Helper-WriteJsonFile "orders.json" $orders
                    Helper-WriteJsonFile "users.json" $users

                    $respObj = @{
                        success = $true
                        count = $createdOrders.Count
                        order = $createdOrders[0]
                        orders = $createdOrders
                    }
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
                        Helper-LogActivity "platform" "Plateforme Difonsé" "TEST_PERIOD_STARTED" ("Délai d'essai 48h démarré pour " + $found.id) 0 "timer"
                    }

                    $respObj = @{ success = $true; order = $found }
                }
            }
            # 9. POST /api/orders/confirm (Mechanic confirms conformity & transaction closes)
            elseif ($rawPath -eq "/api/orders/confirm" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $orders = (Helper-ReadJsonFile "orders.json") | ConvertFrom-Json
                    $found = $null
                    foreach ($o in $orders) {
                        if ($o.id -eq $bodyObj.id) {
                            $o.step = 4
                            $o.stepLabel = "Pièce Conforme Validée · Transaction Clôturée"
                            $o.actionRequired = "Aucune action requise (Terminé)"
                            $o.timeline = "Validé conforme par le mécanicien au garage. Transaction finalisée avec succès (Vendeur payé directement à la commande)."
                            $found = $o
                        }
                    }
                    Helper-WriteJsonFile "orders.json" $orders

                    $users = (Helper-ReadJsonFile "users.json") | ConvertFrom-Json
                    foreach ($u in $users) {
                        if ($u.shopName -eq $found.vendorName -or $u.id -eq $found.vendorId) {
                            if ($found.vendorPaymentStatus -ne "PAID_DIRECT") {
                                $vNet = if ($null -ne $found.vendorNetPrice) { [int]$found.vendorNetPrice } else { [int]$found.vendorBankPrice }
                                $u.availableBalance += $vNet
                                $u.totalSales += $vNet
                            }
                        }
                    }
                    Helper-WriteJsonFile "users.json" $users

                    Helper-LogActivity "buyer" $found.clientName "CONFORMITY_CONFIRMED" ("Montage validé conforme pour " + $found.id) 0 "verified"
                    Helper-LogActivity "platform" "Plateforme Difonsé" "TRANSACTION_FINALIZED" ("Transaction " + $found.id + " clôturée : Vendeur " + $found.vendorName + " rémunéré directement, retainer encaissé") 0 "task_alt"

                    $respObj = @{ success = $true; order = $found }
                }
            }
            # 9b. POST /api/orders/return (Garantie de conformité 2 jours max : Retour pièce non conforme & Remboursement)
            elseif ($rawPath -eq "/api/orders/return" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $orders = (Helper-ReadJsonFile "orders.json") | ConvertFrom-Json
                    $orderId = if ($bodyObj.id) { $bodyObj.id } else { $bodyObj.orderId }
                    $found = $null
                    foreach ($o in $orders) {
                        if ($o.id -eq $orderId) {
                            $o.step = 5
                            $o.status = "RETURNED_REFUNDED"
                            $o.stepLabel = "Pièce Non Conforme Retournée · Remboursement Effectué (Garantie 2 Jours)"
                            $o.actionRequired = "Coursier Tiak-Tiak : Restituer la pièce à l'échoppe · Acheteur remboursé via Wave/OM"
                            $reasonText = if ($bodyObj.reason) { $bodyObj.reason } else { "Pièce non conforme retournée" }
                            $o.timeline = "Garantie conformité 2 jours invoquée : " + $reasonText + ". Remboursement intégral de " + $o.totalPaid + " FCFA exécuté vers l'acheteur via " + $o.provider + "."
                            $found = $o
                        }
                    }
                    Helper-WriteJsonFile "orders.json" $orders

                    if ($null -ne $found) {
                        $payouts = (Helper-ReadJsonFile "payouts.json") | ConvertFrom-Json
                        if ($null -eq $payouts) { $payouts = @() }

                        $newRefund = [PSCustomObject]@{
                            id = "PAY-REF-" + (Get-Random -Minimum 1000 -Maximum 9999)
                            vendor = $found.clientName
                            phone = if ($found.clientPhone) { $found.clientPhone } else { "+221 77 450 12 34" }
                            amount = [int]$found.totalPaid
                            provider = if ($found.provider) { $found.provider } else { "Wave" }
                            status = "COMPLETED"
                            statusLabel = "Remboursement Exécuté (Garantie 2 Jours)"
                            type = "REFUND_NON_COMPLIANT_PART"
                            orderId = $found.id
                            createdAt = [DateTime]::UtcNow.ToString("o")
                        }

                        $allPayouts = @($newRefund) + @($payouts)
                        Helper-WriteJsonFile "payouts.json" $allPayouts

                        Helper-LogActivity "buyer" $found.clientName "PART_RETURN_REQUESTED" ("Retour pièce non conforme sous garantie 2 jours pour " + $found.id + " (" + $found.partName + ")") $found.totalPaid "replay"
                        Helper-LogActivity "platform" "Plateforme Difonsé" "BUYER_REFUNDED" ("Remboursement intégral effectué : " + $found.totalPaid + " FCFA à " + $found.clientName + " via " + $found.provider + " (Garantie 48h conformité)") $found.totalPaid "payments"
                        Helper-LogActivity "seller" $found.vendorName "RETURN_DISPATCHED" ("Coursier Tiak-Tiak mandaté pour restitution de " + $found.partName + " à l'échoppe") 0 "local_shipping"
                    }

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
                            $o.stepLabel = "Litige Ouvert · Arbitrage en Cours"
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
                    Helper-LogActivity "arbitration" "Plateforme Difonsé" "DISPUTE_OPENED" ("Dossier litige ouvert " + $newDisp.id + " (" + $newDisp.amount + " FCFA)") $newDisp.amount "gavel"

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
                    $rawSign = "${dId}_${amt}_${recip}_${nowStr}_DIFONSE_ARBITRATION_FINAL"
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

                    Helper-LogActivity "arbitration" "Comité d'Arbitrage Difonsé" "ARBITRATION_RESOLVED" ("Litige " + $dId + " scellé SHA-256 (" + $sha256Seal.Substring(0, 16) + "...). Remboursement intégral de " + $amt + " FCFA via Wave.") $amt "verified_user"

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

                    $fn = if ($bodyObj.firstName) { $bodyObj.firstName } elseif ($matched -and $matched.firstName) { $matched.firstName } else { "Amadou" }
                    $ln = if ($bodyObj.lastName) { $bodyObj.lastName } elseif ($matched -and $matched.lastName) { $matched.lastName } else { "Diallo" }
                    $ph = if ($bodyObj.phone) { $bodyObj.phone } elseif ($matched -and $matched.phone) { $matched.phone } else { "+221 77 450 12 34" }
                    $fullN = "$fn $ln"

                    $sessUser = [PSCustomObject]@{
                        id = if ($matched) { $matched.id } else { "usr_" + $bodyObj.role + "_" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
                        role = $bodyObj.role
                        firstName = $fn
                        lastName = $ln
                        name = $fullN
                        phone = $ph
                        garageName = if ($bodyObj.garageName) { $bodyObj.garageName } elseif ($matched -and $matched.garageName) { $matched.garageName } else { "Garage Castors Dakar" }
                        shopName = if ($bodyObj.shopName) { $bodyObj.shopName } elseif ($matched -and $matched.shopName) { $matched.shopName } else { "Échoppe Modou Pikine" }
                        hub = if ($bodyObj.hub) { $bodyObj.hub } elseif ($matched -and $matched.hub) { $matched.hub } else { "Pikine" }
                        activeCar = if ($matched -and $matched.activeCar) { $matched.activeCar } else { "Toyota Hilux Vigo 2.5 D-4D" }
                        solvencyScore = if ($matched -and $matched.solvencyScore) { $matched.solvencyScore } else { 98 }
                        solvencyStatus = if ($matched -and $matched.solvencyStatus) { $matched.solvencyStatus } else { "Solvable Vérifié" }
                        solvencyDetails = "Client vérifié par Wave / Orange Money sans défaut de paiement."
                        availableBalance = if ($matched -and $matched.availableBalance) { $matched.availableBalance } else { 340000 }
                        totalSales = if ($matched -and $matched.totalSales) { $matched.totalSales } else { 1820000 }
                        rating = 4.9
                        isOpen = $true
                    }

                    Helper-LogActivity $sessUser.role $sessUser.name "LOGIN" ("Connexion réussie : " + $sessUser.name + " (" + $sessUser.role + " - Solvabilité: " + $sessUser.solvencyScore + "/100)") 0 "login"
                    $respObj = @{ success = $true; user = $sessUser }
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
