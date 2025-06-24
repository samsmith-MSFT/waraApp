<# 
DISCLAIMER

THIS CODE IS SAMPLE CODE. THESE SAMPLES ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND. 
MICROSOFT FURTHER DISCLAIMS ALL IMPLIED WARRANTIES INCLUDING WITHOUT LIMITATION ANY IMPLIED 
WARRANTIES OF MERCHANTABILITY OR OF FITNESS FOR A PARTICULAR PURPOSE. 

THE ENTIRE RISK ARISING OUT OF THE USE OR PERFORMANCE OF THE SAMPLES REMAINS WITH YOU. 
IN NO EVENT SHALL MICROSOFT OR ITS SUPPLIERS BE LIABLE FOR ANY DAMAGES WHATSOEVER 
(INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS PROFITS, BUSINESS INTERRUPTION, 
LOSS OF BUSINESS INFORMATION, OR OTHER PECUNIARY LOSS) ARISING OUT OF THE USE OF OR INABILITY 
TO USE THE SAMPLES, EVEN IF MICROSOFT HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

BECAUSE SOME STATES DO NOT ALLOW THE EXCLUSION OR LIMITATION OF LIABILITY FOR CONSEQUENTIAL 
OR INCIDENTAL DAMAGES, THE ABOVE LIMITATION MAY NOT APPLY TO YOU.
#>

# Requires -Modules Az, WARA (1.0.6)
# Run: pwsh -ExecutionPolicy Bypass -File .\WARAApp.ps1

Write-Host "Script started"

# Ensure modules are installed
if (-not (Get-Module -ListAvailable -Name Az)) {
    Write-Host "Installing Az module..."
    Install-Module -Name Az -Force -Scope CurrentUser
}
if (-not (Get-Module -ListAvailable -Name WARA)) {
    Write-Host "Installing WARA module..."
    Install-Module -Name WARA -Force -Scope CurrentUser
}
Write-Host "Importing modules..."
Import-Module WARA

function Prompt-TenantId {
    Write-Host "Enter Azure Tenant ID:"
    Read-Host
}

function Prompt-Subscription {
    param($subscriptions)
    Write-Host "`nAvailable Subscriptions:"
    for ($i=0; $i -lt $subscriptions.Count; $i++) {
        Write-Host "[$i] $($subscriptions[$i].Name) [$($subscriptions[$i].Id)]"
    }
    $idx = Read-Host "Select subscription by number"
    if ($idx -match '^\d+$' -and $idx -ge 0 -and $idx -lt $subscriptions.Count) {
        return $subscriptions[$idx]
    }
    else {
        Write-Host "Invalid selection."
        return $null
    }
}

function Prompt-ResourceGroups {
    param($resourceGroups)
    Write-Host "`nAvailable Resource Groups:"
    for ($i=0; $i -lt $resourceGroups.Count; $i++) {
        Write-Host "[$i] $($resourceGroups[$i].ResourceGroupName)"
    }
    Write-Host "Enter comma-separated numbers for resource groups to select (e.g. 0,2,3):"
    $input = Read-Host
    $indices = $input -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' }
    $selected = @()
    foreach ($idx in $indices) {
        if ($idx -ge 0 -and $idx -lt $resourceGroups.Count) {
            $selected += $resourceGroups[$idx].ResourceGroupName
        }
    }
    return $selected
}

function Prompt-Tags {
    $tags = @()
    do {
        $tagName = Read-Host "Enter tag name (or leave blank to finish)"
        if ($tagName) {
            $tagValue = Read-Host "Enter tag value for '$tagName'"
            $tags += "$tagName=~$tagValue"
            $addMore = Read-Host "Add another tag? (y/n)"
        } else {
            $addMore = "n"
        }
    } while ($addMore -eq "y")
    return $tags
}

function Main {
    Write-Host "Starting authentication step..."
    $tenantId = Prompt-TenantId
    try {
        Write-Host "Connecting to Azure..."
        Connect-AzAccount -Tenant $tenantId | Out-Null
        Set-AzContext -TenantId $tenantId | Out-Null
    } catch {
        Write-Host "Authentication failed: $_"
        return
    }
    Write-Host "Getting subscriptions for tenant $tenantId..."
    # Only get subscriptions for the specified tenant
    $subscriptions = Get-AzSubscription -TenantId $tenantId

    if ($subscriptions.Count -eq 0) {
        Write-Host "No subscriptions found for this tenant."
        return
    }

    Write-Host "A window will pop up for you to select one or more subscriptions. Hold Ctrl to select multiple."
    $selectedSubs = $subscriptions | Select-Object Name,Id | Out-GridView -Title "Select Subscriptions" -PassThru
    if (-not $selectedSubs -or $selectedSubs.Count -eq 0) {
        Write-Host "No subscriptions selected. Exiting."
        return
    }

    Write-Host "Choose collector mode:"
    Write-Host "[1] Entire Subscription(s)"
    Write-Host "[2] Resource Groups (select from list)"
    Write-Host "[3] Tags (specify tag name/value pairs)"
    $mode = Read-Host "Enter choice (1/2/3)"

    $rgPaths = @()
    $tags = @()
    $subscriptionIds = @()

    if ($mode -eq "1") {
        $subscriptionIds = $selectedSubs | ForEach-Object { "/subscriptions/$($_.Id)" }
    }
    elseif ($mode -eq "2") {
        # Gather resource groups from all selected subscriptions
        $allResourceGroups = @()
        foreach ($sub in $selectedSubs) {
            Write-Host "Setting context to subscription $($sub.Name) [$($sub.Id)]..."
            Set-AzContext -SubscriptionId $sub.Id -TenantId $tenantId | Out-Null
            $rgs = Get-AzResourceGroup | Select-Object @{n='SubscriptionId';e={$sub.Id}}, ResourceGroupName
            $allResourceGroups += $rgs
        }

        if ($allResourceGroups.Count -eq 0) {
            Write-Host "No resource groups found in the selected subscriptions."
            return
        }

        Write-Host "A window will pop up for you to select resource groups. Hold Ctrl to select multiple."
        $selectedRGObjs = $allResourceGroups | Select-Object SubscriptionId, ResourceGroupName | Out-GridView -Title "Select Resource Groups" -PassThru
        $selectedRGs = $selectedRGObjs

        if (-not $selectedRGs -or $selectedRGs.Count -eq 0) {
            Write-Host "No resource groups selected. Exiting."
            return
        }

        $rgPaths = $selectedRGs | ForEach-Object { "/subscriptions/$($_.SubscriptionId)/resourceGroups/$($_.ResourceGroupName)" }
    }
    elseif ($mode -eq "3") {
        $tags = Prompt-Tags
        if ($tags.Count -eq 0) {
            Write-Host "No tags specified. Exiting."
            return
        }
        # Prompt for optional resource group selection
        $allResourceGroups = @()
        foreach ($sub in $selectedSubs) {
            Write-Host "Setting context to subscription $($sub.Name) [$($sub.Id)]..."
            Set-AzContext -SubscriptionId $sub.Id -TenantId $tenantId | Out-Null
            $rgs = Get-AzResourceGroup | Select-Object @{n='SubscriptionId';e={$sub.Id}}, ResourceGroupName
            $allResourceGroups += $rgs
        }
        if ($allResourceGroups.Count -gt 0) {
            Write-Host "A window will pop up for you to optionally select resource groups for tag filtering. Leave empty and click OK to use entire subscription(s)."
            $selectedRGObjs = $allResourceGroups | Select-Object SubscriptionId, ResourceGroupName | Out-GridView -Title "Select Resource Groups (optional)" -PassThru
            $selectedRGs = $selectedRGObjs
        } else {
            $selectedRGs = @()
        }
        if ($selectedRGs -and $selectedRGs.Count -gt 0) {
            $rgPaths = $selectedRGs | ForEach-Object { "/subscriptions/$($_.SubscriptionId)/resourceGroups/$($_.ResourceGroupName)" }
        } else {
            $subscriptionIds = $selectedSubs | ForEach-Object { "/subscriptions/$($_.Id)" }
        }
    }
    else {
        Write-Host "Invalid selection. Exiting."
        return
    }

    # Run Collector
    Write-Host "Running WARA Collector (output will be in the current directory)..."
    try {
        if ($mode -eq "1") {
            Start-WARACollector -TenantID $tenantId -SubscriptionIds $subscriptionIds
        }
        elseif ($mode -eq "2") {
            Start-WARACollector -TenantID $tenantId -ResourceGroups $rgPaths
        }
        elseif ($mode -eq "3") {
            if ($rgPaths -and $rgPaths.Count -gt 0) {
                Start-WARACollector -TenantID $tenantId -ResourceGroups $rgPaths -Tags $tags
            } else {
                Start-WARACollector -TenantID $tenantId -SubscriptionIds $subscriptionIds -Tags $tags
            }
        }
        Write-Host "WARA Collector completed."
    } catch {
        Write-Host "Collector failed: $_"
    }

    # Analyzer
    # Automatically find the most recent WARA Collector JSON file in the current directory
    $currentDir = Get-Location
    $jsonFiles = Get-ChildItem -Path $currentDir -Filter *.json | Sort-Object LastWriteTime -Descending
    if ($jsonFiles.Count -eq 0) {
        Write-Host "No JSON files found in the current directory for Analyzer."
        return
    }
    $analyzerJson = $jsonFiles[0].FullName
    Write-Host "Running WARA Analyzer on file: $analyzerJson"
    try {
        Start-WARAAnalyzer -JSONFile $analyzerJson
        Write-Host "WARA Analyzer completed."
    } catch {
        Write-Host "Analyzer failed: $_"
    }
}

Main
