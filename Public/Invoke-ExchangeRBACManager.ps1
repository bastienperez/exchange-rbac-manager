function Invoke-ExchangeRBACManager {
    <#
    .SYNOPSIS
        Launches the Exchange RBAC Manager graphical interface (read-only).
    .DESCRIPTION
        Opens the WPF interface to browse Exchange Online RBAC objects:
        Role Groups, Roles, Role Assignments, Scopes, User Rights, Command Lookup,
        an embedded RBAC Visualizer (hub-and-spoke) and the Audit Log.

        This version is read-only: it only queries Exchange Online (Get-* /
        Search-AdminAuditLog) and exports results. It does NOT create, modify
        or delete role groups, roles, assignments or scopes.
        Create / edit / delete actions are planned for the next version.
    .EXAMPLE
        Invoke-ExchangeRBACManager
    #>
    [CmdletBinding()]
    param()

    $modVer = Get-RBACModuleVersion
    $verStr = if ($modVer) { "v$($modVer.ToString())" } else { '' }

    $splash = Show-RBACSplash -InitialMessage 'Initializing…' -Version $verStr
    try {
        # ExchangeOnlineManagement is declared in RequiredModules (ExchangeRBACManager.psd1)
        # so PowerShell auto-imports it when this module loads. We only need a lazy fallback
        # if the command surface is missing - Get-Module -ListAvailable is slow (scans every
        # PSModulePath) and Import-Module -Force triggers a needless reload, so skip them.
        if (-not (Get-Command -Name Connect-ExchangeOnline -ErrorAction SilentlyContinue)) {
            $splash.Update('Loading ExchangeOnlineManagement…')
            try {
                Import-Module -Name 'ExchangeOnlineManagement' -ErrorAction Stop
            }
            catch {
                $splash.Close()
                Write-Error "ExchangeOnlineManagement module is not available. Install it with: Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser"
                return
            }
        }

        $splash.Update('Building interface…')
        Invoke-ExchangeGUI -Splash $splash
    }
    finally {
        if ($splash) { $splash.Close() }
    }
}
