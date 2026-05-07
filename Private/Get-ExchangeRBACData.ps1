function Get-RBACRoleGroups {
    <#
    .SYNOPSIS
        Get Exchange RBAC role groups
    .DESCRIPTION
        Retrieves role groups from Exchange with formatted data for display
    .EXAMPLE
        Get-RBACRoleGroups
    #>
    [CmdletBinding()]
    param()

    # Built-in Exchange Online role groups — exact names.
    $builtInRoleGroupNames = @(
        'Compliance Administrator', 'Compliance Management',
        'Communication Compliance', 'Communication Compliance Administrators',
        'Communication Compliance Investigators',
        'Delegated Setup', 'Discovery Management',
        'Help Desk', 'Hygiene Management',
        'Information Protection', 'Information Protection Admins',
        'Information Protection Analysts', 'Information Protection Investigators',
        'Information Protection Readers',
        'Insider Risk Management', 'Insider Risk Management Admins',
        'Insider Risk Management Investigators',
        'MailboxSearch', 'Organization Management',
        'Places Administrators',
        'Privacy Management', 'Privacy Management Administrators',
        'Privacy Management Investigators',
        'Public Folder Management', 'Recipient Management', 'Records Management',
        'Security Administrator', 'Security Operator', 'Security Reader',
        'Server Management', 'UM Management',
        'View-Only Organization Management', 'View-Only Recipient Management'
    )
    # Built-in role groups whose tenant-scoped suffix varies (e.g. "MailboxAdmins_1e071").
    $builtInRoleGroupPrefixes = @(
        'ISVMailboxUsers_', 'MailboxAdmins_', 'HelpdeskAdmins_',
        'TenantAdmins_', 'ExchangeServiceAdmins_',
        'GlobalReaders_', 'SecurityAdmins_', 'SecurityReaders_'
    )

    function Test-IsBuiltInRoleGroup {
        param($Group, [string[]]$Names, [string[]]$Prefixes)
        # Do NOT trust Get-RoleGroup's RoleGroupType for this check: in Exchange
        # Online both built-in and custom role groups commonly report
        # RoleGroupType='Standard', so matching on it classified every role group
        # as built-in and made the 'custom' chip return nothing.
        # The reliable signal is the curated name list + tenant-suffixed prefixes.
        $name = "$($Group.Name)".Trim()
        if ([string]::IsNullOrEmpty($name)) { return $false }
        foreach ($n in $Names) {
            if ([string]::Equals($n, $name, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
        foreach ($p in $Prefixes) {
            if ($name.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
        return $false
    }

    try {
        $roleGroups = Get-RoleGroup -ErrorAction Stop
        if (-not $roleGroups) { return @() }

        $displayData = foreach ($g in $roleGroups) {
            $isBuiltIn = Test-IsBuiltInRoleGroup -Group $g `
                          -Names $builtInRoleGroupNames -Prefixes $builtInRoleGroupPrefixes
            $origin = if ($isBuiltIn) { 'Built-in' } else { 'Custom' }

            [PSCustomObject]@{
                Name        = $g.Name
                Description = $g.Description
                Origin      = $origin
                MemberCount = if ($g.Members) { @($g.Members).Count } else { 0 }
                RoleCount   = if ($g.Roles)   { @($g.Roles).Count   } else { 0 }
                Members     = $g.Members
                Roles       = $g.Roles
            }
        }
        return $displayData
    }
    catch {
        throw "Error loading role groups: $_"
    }
}

function Get-RBACRoles {
    <#
    .SYNOPSIS
        Get Exchange RBAC roles
    .DESCRIPTION
        Retrieves management roles from Exchange with formatted data for display
    .EXAMPLE
        Get-RBACRoles
    #>
    [CmdletBinding()]
    param()
    
    try {
        $roles = Get-ManagementRole -ErrorAction Stop
        
        if ($roles -and $roles.Count -gt 0) {
            return $roles
        }
        else {
            return @()
        }
    }
    catch {
        throw "Failed to retrieve roles: $($_.Exception.Message)"
    }
}

function Get-RBACRoleAssignments {
    <#
    .SYNOPSIS
        Get Exchange RBAC role assignments
    .DESCRIPTION
        Retrieves role assignments from Exchange with formatted data for display
    .EXAMPLE
        Get-RBACRoleAssignments
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Get all role assignments
        $rawRoleAssignments = Get-ManagementRoleAssignment

        # Remove duplicates by grouping on Name
        $roleAssignments = $rawRoleAssignments | Group-Object -Property Name | ForEach-Object { $_.Group[0] }

        if ($roleAssignments) {
            # Prepare data for display
            $displayData = $roleAssignments | ForEach-Object {
                # Format read scope with details if available
                $readScope = $_.RecipientReadScope
                if ($_.CustomRecipientReadScope) {
                    $readScope = "Custom: $($_.CustomRecipientReadScope)"
                    if ($_.ReadScopeDetails -and $_.ReadScopeDetails.RecipientFilter) {
                        $readScope += " (Filter: $($_.ReadScopeDetails.RecipientFilter))"
                    }
                }
                
                # Format write scope with details if available
                $writeScope = $_.RecipientWriteScope
                if ($_.CustomRecipientWriteScope) {
                    $writeScope = "Custom: $($_.CustomRecipientWriteScope)"
                    if ($_.WriteScopeDetails -and $_.WriteScopeDetails.RecipientFilter) {
                        $writeScope += " (Filter: $($_.WriteScopeDetails.RecipientFilter))"
                    }
                }
                
                [PSCustomObject]@{
                    Name                      = $_.Name
                    Role                      = $_.Role
                    RoleAssignee              = $_.RoleAssigneeName
                    RoleAssigneeType          = $_.RoleAssigneeType
                    Enabled                   = $_.Enabled
                    RecipientReadScope        = $readScope
                    RecipientWriteScope       = $writeScope
                    CustomRecipientReadScope  = $_.CustomRecipientReadScope
                    CustomRecipientWriteScope = $_.CustomRecipientWriteScope
                    ReadScopeDetails          = $_.ReadScopeDetails
                    WriteScopeDetails         = $_.WriteScopeDetails
                }
            }
            return $displayData
        }
        else {
            return @()
        }
    }
    catch {
        throw "Error loading role assignments: $_"
    }
}

function Get-RBACManagementScopes {
    <#
    .SYNOPSIS
        Get Exchange RBAC management scopes
    .DESCRIPTION
        Retrieves management scopes from Exchange with formatted data for display
    .EXAMPLE
        Get-RBACManagementScopes
    #>
    [CmdletBinding()]
    param()
    
    try {
        $scopes = Get-ManagementScope
        
        if ($scopes) {
            # Expose the full RecipientFilter as FilterSummary for the GUI; truncation
            # is the UI's job (wrap toggle, ellipsis with full-value tooltip).
            $displayData = $scopes | ForEach-Object {
                $filterSummary = if ($_.RecipientFilter) { [string]$_.RecipientFilter } else { '' }
                $_ | Add-Member -NotePropertyName 'FilterSummary' -NotePropertyValue $filterSummary -PassThru
            }
            return $displayData
        }
        else {
            return @()
        }
    }
    catch {
        throw "Error loading management scopes: $_"
    }
}