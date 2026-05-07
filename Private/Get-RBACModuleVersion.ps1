function Get-RBACModuleVersion {
    <#
    .SYNOPSIS
        Returns the RBACExchangeManager module version from the .psd1 manifest.
    .DESCRIPTION
        Single source of truth for the module version. Reads RBACExchangeManager.psd1
        directly so the version stays correct even when the module is dot-sourced,
        renamed, or loaded twice (cases where Get-Module returns 0.0 or nothing).
    .OUTPUTS
        [version]
    #>
    [CmdletBinding()]
    [OutputType([version])]
    param()

    # $PSScriptRoot is captured at function-definition time = the Private folder.
    $manifestPath = Join-Path $PSScriptRoot '..\RBACExchangeManager.psd1'
    try {
        $manifest = Import-PowerShellDataFile -Path $manifestPath -ErrorAction Stop
        if ($manifest.ModuleVersion) {
            return [version]$manifest.ModuleVersion
        }
    }
    catch {
        Write-Verbose "Could not read manifest at $manifestPath : $_"
    }
    return $null
}
