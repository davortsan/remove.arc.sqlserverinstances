# Detect and remove orphaned SQL Server instances discovered by Arc agent
<h2>Prerequisites</h2>
<ul>
  <li><b>Azure PowerShell installed:</b>Make sure you have the latest version of the https://learn.microsoft.com/en-us/powershell/azure/install-az-ps installed.</li>
  <li><b>Az module:</b>This script uses Get-AzConnectedMachine to check the status of Azure Arc machines. If it's not already installed, run:</li>
</ul>

```powershell
    Install-Module Az -Scope CurrentUser
```

<ul>
  <li><b>Azure permissions:</b>You must have sufficient permissions (e.g., Contributor or Owner) on the subscription or resource groups you want to scan and clean.</li>
</ul>

<h2>Script parameters</h2>
<table>
  <tr><td><b>Parameter</b></td><td><b>Description</b></td></tr>
  <tr><td>-SubscriptionId</td><td>(Optional) Azure subscription ID to target. Defaults to the current context.</td></tr>
  <tr><td>-ResourceGroupNames</td><td>(Optional) Array of specific resource group names to scan.</td></tr>
  <tr><td>-RemoveArcMachines</td><td>(Optional) If set, the script will also attempt to remove inactive Arc machines.</td></tr>
</table>

<h2>Examples</h2>
<ul><li>Scan the current subscription and remove orphaned SQL Arc instances:</li></ul>

```powershell
    .\Cleanup-OrphanArcSql.ps1
```

<ul><li>Scan a specific subscription:</li></ul>

```powershell
  .\Cleanup-OrphanArcSql.ps1 -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

<ul><li>Scan specific resource groups only:</li></ul>

```powershell
  .\Cleanup-OrphanArcSql.ps1 -ResourceGroupNames @("RG1", "RG2")
```

<ul><li>Include cleanup of disconnected Azure Arc machines:</li></ul>

```powershell
  .\Cleanup-OrphanArcSql.ps1 -RemoveArcMachines
```

<h2>What the script does</h2>
<ul>
  <li><b>Scans for all Microsoft.AzureArcData/sqlServerInstances and Microsoft.HybridCompute/machines resources</b> in the specified scope.</li>
  <li><b>Identifies orphaned SQL Arc instances</b> by checking if their containerResourceId no longer matches any active Arc machine.</li>
  <li><b>Prompts you to confirm deletion</b> of the orphaned SQL instances (which also deletes their associated databases).</li>
  <li><b>(Optional)</b> If -RemoveArcMachines is used, it checks the connection status of Arc machines using Get-AzConnectedMachine. Machines that are not in a Connected state or no longer exist are considered inactive and can be removed.</li>
</ul>

<h2>Post-Cleanup Recommendations</h2>
<ul>
  <li>After running the script, verify in the Azure Portal or via CLI that the orphaned resources have been removed.</li>
  <li>If any resources remain, check for resource locks using:</li>
</ul>

```powershell
  Get-AzResourceLock -ResourceGroupName "<YourRG>"
```
Remove them with:

```powershell
  Remove-AzResourceLock -LockId "<LockId>"
```
