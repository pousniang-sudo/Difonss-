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
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($p, $json, $utf8NoBom)
}

function Helper-SetProp($obj, [string]$name, $val) {
    if ($null -eq $obj) { return }
    if ($null -eq $obj.PSObject.Properties[$name]) {
        $obj | Add-Member -MemberType NoteProperty -Name $name -Value $val
    } else {
        $obj.$name = $val
    }
}

function Helper-SupabasePost($table, $obj) {
    try {
        $u = "https://qqhgxnizhxfqanswjpmg.supabase.co/rest/v1/$table"
        $anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFxaGd4bml6aHhmcWFuc3dqcG1nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUyOTAzMTAsImV4cCI6MjExMDg2NjMxMH0.PQ9qZ1HrSzq4u7EbOwa3PqTdY5Me9ECzx2MPIeylq-M"
        $hdrs = @{
            "apikey" = $anonKey
            "Authorization" = "Bearer $anonKey"
            "Prefer" = "resolution=merge-duplicates"
        }
        $json = @($obj) | ConvertTo-Json -Depth 6
        $b = [System.Text.Encoding]::UTF8.GetBytes($json)

        $req = [System.Net.HttpWebRequest]::Create($u)
        $req.Method = "POST"
        $req.ContentType = "application/json; charset=utf-8"
        $req.Timeout = 2000
        foreach ($k in $hdrs.Keys) {
            $req.Headers.Add($k, $hdrs[$k])
        }
        $req.ContentLength = $b.Length
        $st = $req.GetRequestStream()
        $st.Write($b, 0, $b.Length)
        $st.Close()
        $res = $req.GetResponse()
        $res.Close()
    } catch {}
}

function Helper-SyncUserProfileToSupabase($u) {
    if ($null -eq $u) { return }
    $ph = if ($u.phone) { $u.phone } else { "" }
    if ([string]::IsNullOrWhiteSpace($ph)) { return }

    try {
        $fn = if ($u.firstName) { $u.firstName } elseif ($u.name) { ($u.name -split ' ')[0] } else { "Utilisateur" }
        $ln = if ($u.lastName) { $u.lastName } elseif ($u.name) { (($u.name -split ' ') | Select-Object -Skip 1) -join ' ' } else { "Difonsé" }
        $org = if ($u.shopName) { $u.shopName } elseif ($u.garageName) { $u.garageName } elseif ($u.organization) { $u.organization } else { "" }
        $hub = if ($u.location) { $u.location } elseif ($u.hub) { $u.hub } else { "Dakar" }
        $addr = if ($u.address) { $u.address } elseif ($u.deliveryAddress) { $u.deliveryAddress } else { $null }
        $gpsVal = if ($u.gps) { $u.gps } elseif ($u.deliveryGps) { ($u.deliveryGps | ConvertTo-Json -Compress) } else { $null }
        $role = if ($u.role) { $u.role } else { "buyer" }
        $score = if ($u.solvencyScore) { [int]$u.solvencyScore } else { 98 }
        $status = if ($u.solvencyStatus) { $u.solvencyStatus } elseif ($role -eq "seller") { "Vendeur Certifié" } else { "Solvable Vérifié" }

        $vCode = if ($u.vendorCode) { $u.vendorCode } elseif ($u.vendor_code) { $u.vendor_code } else { $null }
        $availBal = if ($null -ne $u.availableBalance) { [int]$u.availableBalance } else { 0 }
        $totSales = if ($null -ne $u.totalSales) { [int]$u.totalSales } else { 0 }

        Helper-SupabasePost "profiles?on_conflict=phone" @{
            phone = $ph
            first_name = $fn
            last_name = $ln
            role = $role
            organization = $org
            hub = $hub
            address = $addr
            gps = $gpsVal
            solvency_score = $score
            solvency_status = $status
            vendor_code = $vCode
            available_balance = $availBal
            total_sales = $totSales
            last_login = [DateTime]::UtcNow.ToString("o")
        }

        Helper-SupabasePost "user_connections" @{
            first_name = $fn
            last_name = $ln
            phone = $ph
            role = $role
            organization = $org
            hub = $hub
            solvency_score = $score
            user_agent = "PowerShell Server"
            connected_at = [DateTime]::UtcNow.ToString("o")
        }
    } catch {}
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

        # Miroir temps réel vers Supabase
        Helper-SupabasePost "activities" @{
            id = $newAct.id
            section = $newAct.section
            actor = $newAct.actor
            action = $newAct.action
            details = $newAct.details
            amount = $newAct.amount
            icon = $newAct.icon
        }
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
                    $oemCode = if ($bodyObj.oem) { $bodyObj.oem } else { "OEM-" + (Get-Random -Minimum 1000 -Maximum 9999) }
                    $veh = if ($bodyObj.vehicle) { $bodyObj.vehicle } else { "Toyota Hilux Vigo 2.5 D-4D" }
                    $condLabel = if ($bodyObj.conditionLabel) { $bodyObj.conditionLabel } elseif ($bodyObj.condition -eq "neuf") { "Neuf d'Origine OEM" } elseif ($bodyObj.condition -eq "occasion") { "Occasion Testée" } else { "Adaptable Certifié" }
                    $mainImg = if ($bodyObj.image) { $bodyObj.image } else { "https://images.unsplash.com/photo-1619642751034-765dfdf7c58e?auto=format&fit=crop&w=800&q=80" }

                    $gallery = if ($null -ne $bodyObj.gallery -and $bodyObj.gallery.Count -gt 0) {
                        @($bodyObj.gallery)
                    } else {
                        @($mainImg, "https://images.unsplash.com/photo-1517524008697-84bbe3c3fd98?auto=format&fit=crop&w=800&q=80", "https://images.unsplash.com/photo-1558981403-c5f9899a28bc?auto=format&fit=crop&w=800&q=80", "https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=800&q=80")
                    }

                    $desc = if ($bodyObj.description) { $bodyObj.description } else { "Pièce " + $bodyObj.name + " (" + $condLabel + ") certifiée compatible pour " + $veh + ". Contrôlée et testée sur banc d'essai à Dakar avant mise en stock avec garantie conformité Difonsé de 2 jours." }

                    $specs = if ($null -ne $bodyObj.specs) {
                        $bodyObj.specs
                    } else {
                        [PSCustomObject]@{
                            oem = $oemCode
                            brand = if ($bodyObj.brand) { $bodyObj.brand } else { "OEM Constructeur" }
                            vehicle = $veh
                            engine = if ($bodyObj.engine) { $bodyObj.engine } else { "2.5 D-4D / 3.0 D-4D Diesel" }
                            years = if ($bodyObj.years) { $bodyObj.years } else { "2005 - 2016" }
                            position = if ($bodyObj.position) { $bodyObj.position } else { "Compartiment Moteur / Châssis" }
                            power = "Standard OEM certifié"
                            testing = "Testé et certifié opérationnel 100% sur banc d'essai"
                            warranty = "Garantie Difonsé 2 jours (48h pour montage mécanicien)"
                        }
                    }

                    $vCode = if ($bodyObj.vendorCode) { $bodyObj.vendorCode } elseif ($bodyObj.vendor_code) { $bodyObj.vendor_code } else { "VND-" + (Get-Random -Minimum 100000 -Maximum 999999) }
                    $vPhone = if ($bodyObj.vendorPhone) { $bodyObj.vendorPhone } elseif ($bodyObj.vendor_phone) { $bodyObj.vendor_phone } else { "" }

                    $newP = [PSCustomObject]@{
                        id = "p_" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                        name = if ($bodyObj.name) { $bodyObj.name } elseif ($bodyObj.title) { $bodyObj.title } else { "Pièce Auto" }
                        oem = $oemCode
                        vehicle = $veh
                        category = $bodyObj.category
                        condition = $bodyObj.condition
                        conditionLabel = $condLabel
                        bankPrice = $bPrice
                        commission = $comm
                        publicPrice = $pubPrice
                        vendorId = if ($bodyObj.vendorId) { $bodyObj.vendorId } else { "usr_seller_1" }
                        vendor = if ($bodyObj.vendor) { $bodyObj.vendor } else { "Boutique Modou Pikine" }
                        vendorCode = $vCode
                        vendorPhone = $vPhone
                        hub = if ($bodyObj.hub) { $bodyObj.hub } else { "Pikine" }
                        image = $mainImg
                        gallery = $gallery
                        description = $desc
                        specs = $specs
                        stock = if ($bodyObj.stock) { [int]$bodyObj.stock } else { 1 }
                        compatibleCar = if ($bodyObj.compatibleCar) { $bodyObj.compatibleCar } else { $veh }
                    }

                    $allProds = @($newP) + @($prods)
                    Helper-WriteJsonFile "products.json" $allProds

                    Helper-LogActivity "seller" $newP.vendor "ADD_PRODUCT" ("Mise en vente: " + $newP.name + " (Prix banque: " + $newP.bankPrice + " FCFA | Prix client: " + $newP.publicPrice + " FCFA)") $newP.bankPrice "add_circle"

                    # Synchronisation instantanée Supabase
                    Helper-SupabasePost "products" @{
                        id = $newP.id
                        name = $newP.name
                        oem = $newP.oem
                        vehicle = $newP.vehicle
                        category = $newP.category
                        condition = $newP.condition
                        condition_label = $newP.conditionLabel
                        bank_price = $newP.bankPrice
                        commission = $newP.commission
                        public_price = $newP.publicPrice
                        vendor = $newP.vendor
                        vendor_id = $newP.vendorId
                        vendor_code = $newP.vendorCode
                        vendor_phone = $newP.vendorPhone
                        hub = $newP.hub
                        stock = $newP.stock
                        image = $newP.image
                        compatible_car = $newP.compatibleCar
                    }

                    $respObj = @{ success = $true; product = $newP }
                }
            }
            # 5-B. POST /api/products/update
            elseif ($rawPath -eq "/api/products/update" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $prods = @((Helper-ReadJsonFile "products.json") | ConvertFrom-Json)
                    $found = $prods | Where-Object { $_.id -eq $bodyObj.id } | Select-Object -First 1
                    if ($found) {
                        if ($bodyObj.name) { $found.name = $bodyObj.name }
                        if ($bodyObj.oem) {
                            $found.oem = $bodyObj.oem
                            if ($found.specs) { $found.specs.oem = $bodyObj.oem }
                        }
                        if ($bodyObj.vehicle) {
                            $found.vehicle = $bodyObj.vehicle
                            $found.compatibleCar = $bodyObj.vehicle
                            if ($found.specs) { $found.specs.vehicle = $bodyObj.vehicle }
                        }
                        if ($bodyObj.category) { $found.category = $bodyObj.category }
                        if ($bodyObj.condition) {
                            $found.condition = $bodyObj.condition
                            $found.conditionLabel = if ($bodyObj.condition -eq "neuf") { "Neuf d'Origine OEM" } elseif ($bodyObj.condition -eq "occasion") { "Occasion Testée" } else { "Adaptable Certifié" }
                        }
                        if ($null -ne $bodyObj.bankPrice) {
                            $bPrice = [int]$bodyObj.bankPrice
                            $comm = [Math]::Round($bPrice * 0.10)
                            $found.bankPrice = $bPrice
                            $found.commission = $comm
                            $found.publicPrice = $bPrice + $comm
                        }
                        if ($null -ne $bodyObj.stock) { $found.stock = [int]$bodyObj.stock }
                        if ($bodyObj.image) {
                            $found.image = $bodyObj.image
                            if ($null -eq $found.gallery -or $found.gallery.Count -eq 0) {
                                $found.gallery = @($bodyObj.image)
                            } else {
                                $found.gallery[0] = $bodyObj.image
                            }
                        }
                        if ($null -ne $bodyObj.gallery -and $bodyObj.gallery.Count -gt 0) {
                            $found.gallery = @($bodyObj.gallery)
                        }
                        if ($bodyObj.description) {
                            $found.description = $bodyObj.description
                        }
                        if ($null -ne $bodyObj.specs) {
                            $found.specs = $bodyObj.specs
                        }

                        Helper-WriteJsonFile "products.json" $prods
                        Helper-LogActivity "seller" $found.vendor "UPDATE_PRODUCT" ("Modification pièce: " + $found.name + " (Prix net: " + $found.bankPrice + " FCFA, Stock: " + $found.stock + ")") $found.bankPrice "edit"
                        $respObj = @{ success = $true; product = $found }
                    } else {
                        $response.StatusCode = 404
                        $respObj = @{ error = "Pièce introuvable" }
                    }
                }
            }
            # 5-C. POST /api/products/delete
            elseif ($rawPath -eq "/api/products/delete" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $prods = @((Helper-ReadJsonFile "products.json") | ConvertFrom-Json)
                    $found = $prods | Where-Object { $_.id -eq $bodyObj.id } | Select-Object -First 1
                    if ($found) {
                        $newProds = @($prods | Where-Object { $_.id -ne $bodyObj.id })
                        Helper-WriteJsonFile "products.json" $newProds
                        Helper-LogActivity "seller" $found.vendor "DELETE_PRODUCT" ("Pièce retirée du catalogue: " + $found.name) 0 "delete"
                        $respObj = @{ success = $true; id = $bodyObj.id }
                    } else {
                        $response.StatusCode = 404
                        $respObj = @{ error = "Pièce introuvable" }
                    }
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
                    if ($null -ne $bodyObj.items) {
                        $itemsToProcess = @($bodyObj.items)
                    } else {
                        $itemsToProcess = @($bodyObj)
                    }

                    $createdOrders = @()

                    foreach ($item in $itemsToProcess) {
                        $cmdId = "CMD-" + (Get-Random -Minimum 1000 -Maximum 9999)
                        $pkCode = "PK-" + (Get-Random -Minimum 100 -Maximum 999)

                        $cFirst = if ($item.clientFirstName) { $item.clientFirstName } elseif ($bodyObj.clientFirstName) { $bodyObj.clientFirstName } else { "Acheteur" }
                        $cLast = if ($item.clientLastName) { $item.clientLastName } elseif ($bodyObj.clientLastName) { $bodyObj.clientLastName } else { "Difonsé" }
                        $cFull = if ($item.clientName) { $item.clientName } elseif ($bodyObj.clientName) { $bodyObj.clientName } else { "$cFirst $cLast".Trim() }
                        $cPhone = if ($item.clientPhone) { $item.clientPhone } elseif ($bodyObj.clientPhone) { $bodyObj.clientPhone } else { "" }
                        $cScore = if ($item.solvencyScore) { [int]$item.solvencyScore } elseif ($bodyObj.solvencyScore) { [int]$bodyObj.solvencyScore } else { 98 }
                        $cStatus = if ($item.solvencyStatus) { $item.solvencyStatus } elseif ($bodyObj.solvencyStatus) { $bodyObj.solvencyStatus } else { "Solvable Vérifié" }

                        $vBank = if ($null -ne $item.vendorNetPrice) { [int]$item.vendorNetPrice } elseif ($null -ne $item.vendorBankPrice) { [int]$item.vendorBankPrice } elseif ($null -ne $item.bankPrice) { [int]$item.bankPrice } else { 0 }
                        $retainer = if ($null -ne $item.platformRetainer) { [int]$item.platformRetainer } elseif ($null -ne $item.commission) { [int]$item.commission } else { [int][Math]::Round($vBank * 0.10) }
                        $total = if ($null -ne $item.totalPaid) { [int]$item.totalPaid } else { ($vBank + $retainer) }
                        $prov = if ($item.provider) { $item.provider } elseif ($bodyObj.provider) { $bodyObj.provider } else { "Wave" }

                        $vId = if ($item.vendorId) { $item.vendorId } else { "usr_seller_1" }
                        $vName = if ($item.vendorName) { $item.vendorName } elseif ($item.vendor) { $item.vendor } else { "Boutique Vendeur" }
                        $vCode = if ($item.vendorCode) { $item.vendorCode } elseif ($bodyObj.vendorCode) { $bodyObj.vendorCode } else { "" }
                        $vPhone = if ($item.vendorPhone) { $item.vendorPhone } elseif ($bodyObj.vendorPhone) { $bodyObj.vendorPhone } else { "" }
                        $vHub = if ($item.vendorShopLocation) { $item.vendorShopLocation } elseif ($item.hub) { $item.hub } else { "Dakar" }
                        $pName = if ($item.partName) { $item.partName } elseif ($item.name) { $item.name } else { "Pièce" }
                        $prodId = if ($item.productId) { $item.productId } elseif ($item.id) { $item.id } else { "p1" }

                        $dAddress = if ($item.deliveryAddress) { $item.deliveryAddress } elseif ($bodyObj.deliveryAddress) { $bodyObj.deliveryAddress } else { $cFull }
                        $dNotes = if ($item.deliveryNotes) { $item.deliveryNotes } elseif ($bodyObj.deliveryNotes) { $bodyObj.deliveryNotes } else { "" }
                        $dGps = if ($item.deliveryGps) { $item.deliveryGps } elseif ($bodyObj.deliveryGps) { $bodyObj.deliveryGps } else { $null }
                        $dOrg = if ($bodyObj.garageName) { $bodyObj.garageName } else { "Garage Client Difonsé" }

                        $newO = [PSCustomObject]@{
                            id = $cmdId
                            productId = $prodId
                            partName = $pName
                            clientFirstName = $cFirst
                            clientLastName = $cLast
                            clientName = $cFull
                            clientPhone = $cPhone
                            deliveryAddress = $dAddress
                            deliveryNotes = $dNotes
                            deliveryGps = $dGps
                            solvencyScore = $cScore
                            solvencyStatus = $cStatus
                            vendorId = $vId
                            vendorName = $vName
                            vendorCode = $vCode
                            vendorPhone = $vPhone
                            vendorShopLocation = $vHub
                            vendorBankPrice = $vBank
                            vendorNetPrice = $vBank
                            commission = $retainer
                            platformRetainer = $retainer
                            totalPaid = $total
                            provider = $prov
                            pickupCode = $pkCode
                            step = 2
                            stepLabel = "Payé par Difonsé · Tiak-Tiak en route vers le vendeur"
                            vendorPaymentStatus = "PAID_DIRECT"
                            actionRequired = "Vendeur : Remettre la pièce payée au coursier contre le code $pkCode"
                            timeline = "Acheteur débité via $prov. Retainer Difonsé prélevé ($retainer FCFA). Vendeur payé directement ($vBank FCFA). Livraison : $dAddress"
                            createdAt = [DateTime]::UtcNow.ToString("o")
                        }

                        $orders = @($newO) + @($orders)
                        $createdOrders += @($newO)

                        # Update seller available balance directly
                        foreach ($u in $users) {
                            if ($u.id -eq $vId -or $u.shopName -eq $vName -or ($vPhone -and $u.phone -and ($u.phone -replace '[^0-9]').EndsWith(($vPhone -replace '[^0-9]')))) {
                                if ($null -eq $u.PSObject.Properties['availableBalance']) { $u | Add-Member -MemberType NoteProperty -Name 'availableBalance' -Value 0 }
                                if ($null -eq $u.PSObject.Properties['totalSales']) { $u | Add-Member -MemberType NoteProperty -Name 'totalSales' -Value 0 }
                                if ($null -eq $u.PSObject.Properties['totalRetainerPaid']) { $u | Add-Member -MemberType NoteProperty -Name 'totalRetainerPaid' -Value 0 }
                                $u.availableBalance = [int]$u.availableBalance + $vBank
                                $u.totalSales = [int]$u.totalSales + $vBank
                                $u.totalRetainerPaid = [int]$u.totalRetainerPaid + $retainer
                            }
                        }

                        Helper-LogActivity "buyer" $cFull "ORDER_PLACED" ("Commande payée via " + $prov + " : " + $pName + " (" + $total + " FCFA)") $total "shopping_bag"
                        Helper-LogActivity "platform" "Plateforme Difonsé" "RETAINER_COLLECTED" ("Retainer plateforme prélevé : " + $retainer + " FCFA sur commande " + $cmdId) $retainer "savings"
                        Helper-LogActivity "seller" $vName "DIRECT_PAYMENT_RECEIVED" ("Paiement direct reçu : " + $vBank + " FCFA pour " + $pName) $vBank "payments"

                        Helper-SupabasePost "orders" @{
                            id = $newO.id
                            product_id = $newO.productId
                            part_name = $newO.partName
                            client_first_name = $newO.clientFirstName
                            client_last_name = $newO.clientLastName
                            client_name = $newO.clientName
                            client_phone = $newO.clientPhone
                            delivery_address = $newO.deliveryAddress
                            delivery_notes = $newO.deliveryNotes
                            delivery_gps = $newO.deliveryGps
                            solvency_score = $newO.solvencyScore
                            solvency_status = $newO.solvencyStatus
                            vendor_id = $newO.vendorId
                            vendor_code = $newO.vendorCode
                            vendor_name = $newO.vendorName
                            vendor_shop_location = $newO.vendorShopLocation
                            vendor_phone = $newO.vendorPhone
                            payment_provider = $newO.provider
                            vendor_bank_price = $newO.vendorBankPrice
                            vendor_net_price = $newO.vendorNetPrice
                            commission = $newO.commission
                            platform_retainer = $newO.platformRetainer
                            total_paid = $newO.totalPaid
                            pickup_code = $newO.pickupCode
                            step = $newO.step
                            step_label = $newO.stepLabel
                            vendor_payment_status = $newO.vendorPaymentStatus
                            action_required = $newO.actionRequired
                            timeline = $newO.timeline
                        }

                        # Enregistrement et synchronisation automatique du profil acheteur dans Supabase
                        Helper-SyncUserProfileToSupabase @{
                            phone = $newO.clientPhone
                            firstName = $newO.clientFirstName
                            lastName = $newO.clientLastName
                            name = $newO.clientName
                            role = "buyer"
                            organization = $dOrg
                            hub = "Dakar"
                            address = $newO.deliveryAddress
                            deliveryGps = $newO.deliveryGps
                            solvencyScore = $newO.solvencyScore
                            solvencyStatus = $newO.solvencyStatus
                        }
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
                            Helper-SetProp $o "step" 5
                            Helper-SetProp $o "status" "RETURNED_REFUNDED"
                            Helper-SetProp $o "stepLabel" "Pièce Non Conforme Retournée · Remboursement Effectué (Garantie 2 Jours)"
                            Helper-SetProp $o "actionRequired" "Coursier Tiak-Tiak : Restituer la pièce au vendeur · Acheteur remboursé via Wave/OM"
                            $reasonText = if ($bodyObj.reason) { $bodyObj.reason } else { "Pièce non conforme retournée" }
                            Helper-SetProp $o "timeline" ("Garantie conformité 2 jours invoquée : " + $reasonText + ". Remboursement intégral de " + $o.totalPaid + " FCFA exécuté vers l'acheteur via " + $o.provider + ".")
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
                        Helper-LogActivity "seller" $found.vendorName "RETURN_DISPATCHED" ("Coursier Tiak-Tiak mandaté pour restitution de " + $found.partName + " au vendeur") 0 "local_shipping"
                    }

                    $respObj = @{ success = $true; order = $found }
                }
            }
            # 9c. POST /api/orders/cancel (Super Admin cancels order and refunds buyer)
            elseif ($rawPath -eq "/api/orders/cancel" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $orders = (Helper-ReadJsonFile "orders.json") | ConvertFrom-Json
                    $orderId = if ($bodyObj.id) { $bodyObj.id } else { $bodyObj.orderId }
                    $found = $null
                    foreach ($o in $orders) {
                        if ($o.id -eq $orderId) {
                            Helper-SetProp $o "step" 5
                            Helper-SetProp $o "status" "CANCELLED"
                            Helper-SetProp $o "vendorPaymentStatus" "CANCELLED_REFUNDED"
                            Helper-SetProp $o "stepLabel" "Commande Annulée par le Super Admin · Acheteur Remboursé"
                            Helper-SetProp $o "actionRequired" ("Superviseur : Commande annulée. Remboursement intégral acheteur via " + $o.provider)
                            $reasonText = if ($bodyObj.reason) { $bodyObj.reason } else { "Annulation par le Superviseur Difonsé" }
                            Helper-SetProp $o "timeline" ("Commande annulée par le Super Admin : " + $reasonText + ". Remboursement de " + $o.totalPaid + " FCFA exécuté vers l'acheteur via " + $o.provider + ".")
                            $found = $o
                        }
                    }
                    Helper-WriteJsonFile "orders.json" $orders

                    if ($null -ne $found) {
                        $users = (Helper-ReadJsonFile "users.json") | ConvertFrom-Json
                        foreach ($u in $users) {
                            if ($u.shopName -eq $found.vendorName -or $u.id -eq $found.vendorId -or ($found.vendorCode -and $u.vendorCode -eq $found.vendorCode)) {
                                $vNet = if ($null -ne $found.vendorNetPrice) { [int]$found.vendorNetPrice } else { [int]$found.vendorBankPrice }
                                $ret = if ($null -ne $found.platformRetainer) { [int]$found.platformRetainer } else { [int]$found.commission }
                                Helper-SetProp $u "availableBalance" ([Math]::Max(0, [int]$u.availableBalance - $vNet))
                                Helper-SetProp $u "totalSales" ([Math]::Max(0, [int]$u.totalSales - $vNet))
                                Helper-SetProp $u "totalRetainerPaid" ([Math]::Max(0, [int]$u.totalRetainerPaid - $ret))
                            }
                        }
                        Helper-WriteJsonFile "users.json" $users

                        $payouts = (Helper-ReadJsonFile "payouts.json") | ConvertFrom-Json
                        if ($null -eq $payouts) { $payouts = @() }

                        $newRefund = [PSCustomObject]@{
                            id = "PAY-CAN-" + (Get-Random -Minimum 1000 -Maximum 9999)
                            vendor = $found.clientName
                            phone = if ($found.clientPhone) { $found.clientPhone } else { "+221 77 450 12 34" }
                            amount = [int]$found.totalPaid
                            provider = if ($found.provider) { $found.provider } else { "Wave" }
                            status = "COMPLETED"
                            statusLabel = "Commande Annulée · Remboursement Effectué"
                            type = "ORDER_CANCELLED_REFUND"
                            orderId = $found.id
                            createdAt = [DateTime]::UtcNow.ToString("o")
                        }
                        $allPayouts = @($newRefund) + @($payouts)
                        Helper-WriteJsonFile "payouts.json" $allPayouts

                        Helper-LogActivity "platform" "Super Admin" "ORDER_CANCELLED" ("Commande " + $found.id + " annulée par le superviseur. Remboursement intégral de " + $found.totalPaid + " FCFA déclenché.") $found.totalPaid "cancel"

                        Helper-SupabasePost "orders" @{
                            id = $found.id
                            step = 5
                            step_label = $found.stepLabel
                            action_required = $found.actionRequired
                            timeline = $found.timeline
                            vendor_payment_status = "CANCELLED_REFUNDED"
                        }
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
                        vendorName = if ($vUser) { $vUser.shopName } else { "Boutique Modou" }
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
                        name = if ($bodyObj.name) { $bodyObj.name } elseif ($bodyObj.title) { $bodyObj.title } else { "Pièce Auto" }
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

                    Helper-LogActivity "seller" $newSeller.shopName "SELLER_REGISTERED" ("Nouvelle boutique créée : " + $newSeller.shopName + " au hub " + $newSeller.hub) 0 "store"
                    $respObj = @{ success = $true; seller = $newSeller }
                }
            }
            # 17. POST /api/auth/login
            elseif ($rawPath -eq "/api/auth/login" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $users = (Helper-ReadJsonFile "users.json") | ConvertFrom-Json
                    if ($null -eq $users) { $users = @() }

                    $cleanPh = if ($bodyObj.phone) { ($bodyObj.phone -replace '[^0-9]', '') } else { '' }
                    $matched = $null
                    if ($bodyObj.id) {
                        $matched = $users | Where-Object { $_.id -eq $bodyObj.id } | Select-Object -First 1
                    }
                    if (-not $matched -and $cleanPh) {
                        $phSuffix = $cleanPh.Substring([Math]::Max(0, $cleanPh.Length - 9))
                        $matched = $users | Where-Object { 
                            $uClean = ($_.phone -replace '[^0-9]', '')
                            $uClean.EndsWith($phSuffix) -and $_.role -eq $bodyObj.role
                        } | Select-Object -First 1
                    }

                    $isDemoModou = ($bodyObj.role -eq 'seller' -and $cleanPh.EndsWith('778904512') -and $bodyObj.firstName -and $bodyObj.firstName.ToLower().Trim() -eq 'modou' -and $bodyObj.lastName -and $bodyObj.lastName.ToLower().Trim() -eq 'ndiaye')
                    $isDemoAmadou = ($bodyObj.role -eq 'buyer' -and $cleanPh.EndsWith('774501234') -and $bodyObj.firstName -and $bodyObj.firstName.ToLower().Trim() -eq 'amadou' -and $bodyObj.lastName -and $bodyObj.lastName.ToLower().Trim() -eq 'diallo')

                    $fn = if ($bodyObj.firstName) { $bodyObj.firstName } elseif ($matched -and $matched.firstName) { $matched.firstName } elseif ($isDemoAmadou) { "Amadou" } elseif ($isDemoModou) { "Modou" } else { "" }
                    $ln = if ($bodyObj.lastName) { $bodyObj.lastName } elseif ($matched -and $matched.lastName) { $matched.lastName } elseif ($isDemoAmadou) { "Diallo" } elseif ($isDemoModou) { "Ndiaye" } else { "" }
                    $ph = if ($bodyObj.phone) { $bodyObj.phone } elseif ($matched -and $matched.phone) { $matched.phone } elseif ($isDemoAmadou) { "+221 77 450 12 34" } elseif ($isDemoModou) { "+221 77 890 45 12" } else { "" }
                    $fullN = if ($fn -or $ln) { "$fn $ln".Trim() } else { if ($isDemoAmadou) { "Amadou Diallo" } elseif ($isDemoModou) { "Modou Ndiaye" } else { "Utilisateur Difonsé" } }

                    $uniqueSuffix = if ($cleanPh) { $cleanPh } else { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
                    $userId = if ($matched) { $matched.id } elseif ($isDemoModou) { "usr_seller_1" } elseif ($isDemoAmadou) { "usr_buyer_1" } elseif ($bodyObj.id) { $bodyObj.id } else { "usr_" + $bodyObj.role + "_" + $uniqueSuffix }
                    $vCode = if ($matched -and $matched.vendorCode) { $matched.vendorCode } elseif ($bodyObj.vendorCode) { $bodyObj.vendorCode } elseif ($cleanPh) { "VND-" + $cleanPh.Substring([Math]::Max(0, $cleanPh.Length - 6)) } else { "VND-" + (Get-Random -Minimum 100000 -Maximum 999999) }

                    $sessUser = [PSCustomObject]@{
                        id = $userId
                        vendorCode = if ($bodyObj.role -eq 'seller') { $vCode } else { $null }
                        role = $bodyObj.role
                        firstName = $fn
                        lastName = $ln
                        name = $fullN
                        phone = $ph
                        garageName = if ($bodyObj.garageName) { $bodyObj.garageName } elseif ($matched -and $matched.garageName) { $matched.garageName } elseif ($isDemoAmadou) { "Garage Castors Dakar" } else { "" }
                        shopName = if ($bodyObj.shopName) { $bodyObj.shopName } elseif ($matched -and $matched.shopName) { $matched.shopName } elseif ($isDemoModou) { "Boutique Modou Pièces Auto" } else { "" }
                        location = if ($bodyObj.location) { $bodyObj.location } elseif ($bodyObj.hub) { $bodyObj.hub } elseif ($matched -and $matched.location) { $matched.location } else { "Dakar" }
                        hub = if ($bodyObj.location) { $bodyObj.location } elseif ($bodyObj.hub) { $bodyObj.hub } elseif ($matched -and $matched.hub) { $matched.hub } else { "Dakar" }
                        activeCar = if ($matched -and $matched.activeCar) { $matched.activeCar } elseif ($isDemoAmadou) { "Toyota Hilux Vigo 2.5 D-4D" } else { "" }
                        solvencyScore = if ($matched -and $matched.solvencyScore) { $matched.solvencyScore } elseif ($bodyObj.role -eq 'buyer') { 98 } else { 95 }
                        solvencyStatus = if ($matched -and $matched.solvencyStatus) { $matched.solvencyStatus } elseif ($bodyObj.role -eq 'buyer') { "Solvable Vérifié" } else { "Vendeur Certifié" }
                        solvencyDetails = "Client vérifié par Wave / Orange Money sans défaut de paiement."
                        availableBalance = if ($matched -and $null -ne $matched.availableBalance) { $matched.availableBalance } elseif ($isDemoModou) { 570000 } else { 0 }
                        totalSales = if ($matched -and $null -ne $matched.totalSales) { $matched.totalSales } elseif ($isDemoModou) { 2390000 } else { 0 }
                        totalRetainerPaid = if ($matched -and $null -ne $matched.totalRetainerPaid) { $matched.totalRetainerPaid } elseif ($isDemoModou) { 239000 } else { 0 }
                        rating = if ($matched -and $matched.rating) { $matched.rating } else { 5.0 }
                        isOpen = $true
                    }

                    # Persistance locale dans users.json
                    $userList = @($users)
                    $existIdx = -1
                    for ($i = 0; $i -lt $userList.Count; $i++) {
                        if ($userList[$i].phone -eq $sessUser.phone -and $userList[$i].role -eq $sessUser.role) {
                            $existIdx = $i; break
                        }
                    }
                    if ($existIdx -ge 0) {
                        $userList[$existIdx] = $sessUser
                    } else {
                        $userList += $sessUser
                    }
                    Helper-WriteJsonFile "users.json" $userList

                    # Synchronisation Supabase en arrière-plan
                    Helper-SyncUserProfileToSupabase $sessUser

                    Helper-LogActivity $sessUser.role $sessUser.name "LOGIN" ("Connexion réussie : " + $sessUser.name + " (" + $sessUser.role + " - Solvabilité: " + $sessUser.solvencyScore + "/100)") 0 "login"
                    $respObj = @{ success = $true; user = $sessUser }
                }
            }
            # 18. GET /api/profiles
            elseif ($rawPath -eq "/api/profiles" -and $request.HttpMethod -eq "GET") {
                $users = (Helper-ReadJsonFile "users.json") | ConvertFrom-Json
                $respObj = $users
            }
            # 19. POST /api/profiles
            elseif ($rawPath -eq "/api/profiles" -and $request.HttpMethod -eq "POST") {
                if ($null -ne $bodyObj) {
                    $users = (Helper-ReadJsonFile "users.json") | ConvertFrom-Json
                    if ($null -eq $users) { $users = @() }
                    $userList = @($users)
                    $ph = if ($bodyObj.phone) { $bodyObj.phone } else { "" }
                    $profItem = [PSCustomObject]@{
                        phone = $ph
                        firstName = if ($bodyObj.firstName) { $bodyObj.firstName } else { "Utilisateur" }
                        lastName = if ($bodyObj.lastName) { $bodyObj.lastName } else { "Difonsé" }
                        name = if ($bodyObj.firstName -or $bodyObj.lastName) { ($bodyObj.firstName + " " + $bodyObj.lastName).Trim() } else { "Utilisateur Difonsé" }
                        role = if ($bodyObj.role) { $bodyObj.role } else { "buyer" }
                        shopName = if ($bodyObj.shopName) { $bodyObj.shopName } else { "" }
                        garageName = if ($bodyObj.garageName) { $bodyObj.garageName } else { "" }
                        organization = if ($bodyObj.organization) { $bodyObj.organization } elseif ($bodyObj.shopName) { $bodyObj.shopName } elseif ($bodyObj.garageName) { $bodyObj.garageName } else { "" }
                        hub = if ($bodyObj.hub) { $bodyObj.hub } elseif ($bodyObj.location) { $bodyObj.location } else { "Dakar" }
                        address = if ($bodyObj.address) { $bodyObj.address } else { "" }
                        gps = if ($bodyObj.gps) { $bodyObj.gps } else { $null }
                        solvencyScore = if ($bodyObj.solvencyScore) { [int]$bodyObj.solvencyScore } else { 98 }
                        solvencyStatus = if ($bodyObj.solvencyStatus) { $bodyObj.solvencyStatus } else { "Solvable Vérifié" }
                    }
                    $existIdx = -1
                    for ($i = 0; $i -lt $userList.Count; $i++) {
                        if ($userList[$i].phone -eq $ph -and $userList[$i].role -eq $profItem.role) {
                            $existIdx = $i; break
                        }
                    }
                    if ($existIdx -ge 0) {
                        $userList[$existIdx] = $profItem
                    } else {
                        $userList += $profItem
                    }
                    Helper-WriteJsonFile "users.json" $userList
                    Helper-SyncUserProfileToSupabase $profItem
                    $respObj = @{ success = $true; profile = $profItem }
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
        Write-Output "SERVER_ERROR: $($_.Exception.Message)"
        if ($null -ne $context -and $null -ne $context.Response) {
            try {
                $context.Response.StatusCode = 500
                $context.Response.Close()
            } catch {}
        }
    }
}
