function Connect-RBACExchangeOnline {
    <#
    .SYNOPSIS
        Connect to Exchange Online for RBAC management
    .DESCRIPTION
        Establishes a connection to Exchange Online with proper error handling
    .EXAMPLE
        Connect-RBACExchangeOnline
    .EXAMPLE
        Connect-RBACExchangeOnline -DisableWAM
    #>
    [CmdletBinding()]
    param(
        [switch]$DisableWAM
    )

    try {
        # Beginning in Exchange Online PowerShell module version 3.7.0, Microsoft enabled Web
        # Account Manager (WAM) as the default authentication broker. We pass -DisableWAM
        # straight through; on EOM < 3.7.0 the parameter doesn't exist and the user sees an
        # actionable error (WAM only matters on 3.7.0+ anyway).
        if ($DisableWAM) {
            Write-Verbose 'Connecting to Exchange Online with WAM disabled.'
            Connect-ExchangeOnline -ShowBanner:$false -DisableWAM -ErrorAction Stop
        }
        else {
            Write-Verbose 'Connecting to Exchange Online (WAM default behaviour).'
            Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        }
        $Global:RBACExchangeConnectionType = 'Exchange Online'
        return $true
    }
    catch {
        throw "Error connecting to Exchange Online: $_"
    }
}

function Connect-RBACExchangeOnPremise {
    <#
    .SYNOPSIS
        Connect to Exchange On-Premise for RBAC management
    .DESCRIPTION
        Placeholder for Exchange On-Premise connection (not supported in this version)
    .EXAMPLE
        Connect-RBACExchangeOnPremise
    #>
    [CmdletBinding()]
    param()
    
    throw 'Exchange On-Premise connection is not supported in this version.'
}

function Disconnect-RBACExchange {
    <#
    .SYNOPSIS
        Disconnect from Exchange
    .DESCRIPTION
        Disconnects from Exchange and clears connection state
    .EXAMPLE
        Disconnect-RBACExchange
    #>
    [CmdletBinding()]
    param()
    
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Stop
        $Global:RBACExchangeConnectionType = $null
        
        # Clear global data
        $global:RoleGroups = @()
        $global:Roles = @()
        $global:RoleAssignments = @()
        $global:Scopes = @()
        $global:ScopeRecipients = @()
        $global:AssignmentVisualizerData = @()
        
        return $true
    }
    catch {
        throw "Error disconnecting from Exchange: $_"
    }
}

function Test-RBACExchangeConnection {
    <#
    .SYNOPSIS
        Test if connected to Exchange
    .DESCRIPTION
        Checks if there is an active Exchange connection
    .EXAMPLE
        Test-RBACExchangeConnection
    #>
    [CmdletBinding()]
    param()
    
    return ($null -ne $Global:RBACExchangeConnectionType)
}