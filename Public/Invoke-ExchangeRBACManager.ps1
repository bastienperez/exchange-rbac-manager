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

    if (-not (Get-Module -ListAvailable -Name 'ExchangeOnlineManagement')) {
        Write-Warning "The 'ExchangeOnlineManagement' module is not installed. Installing..."
        try {
            Install-Module -Name 'ExchangeOnlineManagement' -Force -Scope CurrentUser
        }
        catch {
            Write-Error "Unable to install ExchangeOnlineManagement module: $_"
            return
        }
    }

    Import-Module -Name 'ExchangeOnlineManagement' -Force

    Invoke-ExchangeGUI
}
