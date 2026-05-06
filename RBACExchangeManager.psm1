# RBAC Exchange Manager Module
# Author: Bastien Perez

$Public  = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1  -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($Import in @($Public + $Private)) {
    try {
        . $Import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($Import.FullName): $_"
    }
}

if ($Public.Count -gt 0) {
    $Public | ForEach-Object {
        Export-ModuleMember -Function $_.BaseName
    }
}
