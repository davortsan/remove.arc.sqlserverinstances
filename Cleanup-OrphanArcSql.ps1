
# Requires: Az.Accounts, Az.Resources, Az.ConnectedMachine (para Get-AzConnectedMachine)
param(
    [string] $SubscriptionId = $(Get-AzContext).Subscription.Id,   # Suscripción a analizar (por defecto la actual)
    [string[]] $ResourceGroupNames = @(),                         # Lista de RGs específicos a inspeccionar (opcional)
    [switch] $RemoveArcMachines                                   # Indicador para remover también máquinas Azure Arc inactivas
)

# 1. Establecer la suscripción de trabajo
if ($SubscriptionId) {
    Set-AzContext -Subscription $SubscriptionId -ErrorAction Stop | Out-Null
}

# 2. Obtener todas las instancias SQL Arc y máquinas Arc en el alcance indicado
$arcSqlInstances = @()
$arcMachines = @()

if ($ResourceGroupNames -and $ResourceGroupNames.Count -gt 0) {
    foreach ($rg in $ResourceGroupNames) {
        $arcSqlInstances += Get-AzResource -ResourceGroupName $rg -ResourceType "Microsoft.AzureArcData/sqlServerInstances" -ErrorAction SilentlyContinue
        $arcMachines += Get-AzResource -ResourceGroupName $rg -ResourceType "Microsoft.HybridCompute/machines" -ErrorAction SilentlyContinue
    }
} else {
    # Sin grupos específicos: consultar toda la suscripción
    $arcSqlInstances = Get-AzResource -ResourceType "Microsoft.AzureArcData/sqlServerInstances" -ErrorAction SilentlyContinue
    $arcMachines = Get-AzResource -ResourceType "Microsoft.HybridCompute/machines" -ErrorAction SilentlyContinue
}

# 3. Identificar instancias SQL huérfanas (sin máquina Arc asociada activa)
$orphanSqlInstances = @()

# Crear un conjunto (hashset) de IDs de máquinas Arc existentes para comparación rápida
$machineIdSet = New-Object System.Collections.Generic.HashSet[string]

foreach ($m in $arcMachines) {
    if ($m.ResourceId) { [void]$machineIdSet.Add($m.ResourceId.ToLower()) }
}

# Revisar cada instancia SQL Arc
foreach ($inst in $arcSqlInstances) {
    # Extraer el ID del recurso de máquina Arc asociado (containerResourceId)
    $containerId = $inst.Properties.containerResourceId
    if ($containerId) { $containerId = $containerId.ToLower() }
    # Marcar como huérfana si: no tiene containerId, o dicho ID no está en la lista de máquinas actuales
    if (-not $containerId -or -not $machineIdSet.Contains($containerId)) {
        $orphanSqlInstances += $inst
    }
}

# 4. Eliminar instancias huérfanas (previa confirmación)
if ($orphanSqlInstances.Count -eq 0) {
    Write-Host "No se encontraron instancias SQL de Azure Arc huérfanas." -ForegroundColor Green
} else {
    Write-Host "Se encontraron $($orphanSqlInstances.Count) instancia(s) SQL de Azure Arc huérfana(s):" -ForegroundColor Yellow
    $orphanSqlInstances | Format-Table Name, ResourceGroupName, Location
    $confirm = Read-Host "¿Deseas eliminar estas instancias (y sus DBs asociadas)? (Y/N)"
    if ($confirm -match '^(Y|y)') {
        foreach ($inst in $orphanSqlInstances) {
            Write-Host "Eliminando instancia huérfana: $($inst.Name) ..." -ForegroundColor DarkYellow
            Remove-AzResource -ResourceId $inst.ResourceId -Force -Confirm:$false
        }
        Write-Host "Instancias huérfanas eliminadas exitosamente." -ForegroundColor Green
    } else {
        Write-Host "Operación cancelada. No se eliminaron las instancias huérfanas." -ForegroundColor Cyan
    }
}

# 5. (Opcional) Eliminar también los recursos de máquina Azure Arc inactivos
if ($RemoveArcMachines) {
    $machinesToRemove = @()
    foreach ($m in $arcMachines) {
        # Obtener detalles de la máquina Arc para verificar su estado de conexión
        try {
            $cm = Get-AzConnectedMachine -ResourceGroupName $m.ResourceGroupName -Name $m.Name -ErrorAction Stop
        } catch {
            $cm = $null
        }
        # Si Get-AzConnectedMachine no devuelve nada (null) o el estado no es "Connected", la consideramos candidata a eliminar
        if (-not $cm -or $cm.Status -ne "Connected") {
            $machinesToRemove += $m
        }
    }
    if ($machinesToRemove.Count -gt 0) {
        Write-Host "Recursos de máquina Azure Arc posiblemente inactivos a eliminar:" -ForegroundColor Yellow
        $machinesToRemove | Format-Table Name, ResourceGroupName, Location
        $confirm2 = Read-Host "¿Deseas eliminar estos $($machinesToRemove.Count) recurso(s) de máquina Arc? (Y/N)"
        if ($confirm2 -match '^(Y|y)') {
            foreach ($m in $machinesToRemove) {
                Write-Host "Eliminando recurso de máquina Arc: $($m.Name) ..." -ForegroundColor DarkYellow
                Remove-AzResource -ResourceId $m.ResourceId -Force -Confirm:$false
            }
            Write-Host "Máquinas Azure Arc eliminadas exitosamente." -ForegroundColor Green
        } else {
            Write-Host "Operación cancelada. No se eliminaron las máquinas Arc." -ForegroundColor Cyan
        }
    } else {
        Write-Host "No hay recursos de máquina Arc inactivos para eliminar."
    }
}
