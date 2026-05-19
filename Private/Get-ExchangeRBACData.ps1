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

    # Built-in Exchange Online role groups - exact names.
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
        Retrieves management roles from Exchange and tags each with an Origin
        (Built-in vs Custom) using algorithmic signals only - no curated name
        list to maintain.

        A role is classified Built-in if any of these hold:
          - IsRootRole = $true (top-level shipped role)
          - IsEndUserRole = $true (the My* self-service roles)
          - The role's Name appears as the Parent of at least one other role
            (= intermediate node of the built-in role tree)

        Anything else is Custom (admin-created via New-ManagementRole).
    .EXAMPLE
        Get-RBACRoles
    #>
    [CmdletBinding()]
    param()

    try {
        $roles = Get-ManagementRole -ErrorAction Stop
        if (-not $roles -or $roles.Count -eq 0) { return @() }

        # Build the set of names that act as a Parent for at least one role.
        $parentNames = @{}
        foreach ($r in $roles) {
            $p = "$($r.Parent)"
            if ($p) { $parentNames[$p] = $true }
        }

        foreach ($r in $roles) {
            $isBuiltIn = $r.IsRootRole -or $r.IsEndUserRole -or $parentNames.ContainsKey([string]$r.Name)
            $origin = if ($isBuiltIn) { 'Built-in' } else { 'Custom' }
            $r | Add-Member -NotePropertyName 'Origin' -NotePropertyValue $origin -Force
        }
        return $roles
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
        $scopes = @(Get-ManagementScope -ErrorAction Stop)
    }
    catch {
        throw "Error loading management scopes: $_"
    }
    if ($scopes.Count -eq 0) { return @() }
    Write-Verbose "Get-RBACManagementScopes: Get-ManagementScope returned $($scopes.Count) scope(s)"

    # Per-scope try/catch so one bad scope doesn't silently drop all the
    # others. Symptom we just hit: 3 scopes in the tenant, only 1 reaching
    # the UI - the property-projection for a single scope was throwing and
    # an outer try/catch was swallowing the iteration mid-flight.
    $displayData = [System.Collections.Generic.List[object]]::new()
    foreach ($s in $scopes) {
        try {
            # EXO can return RecipientFilter as a multi-valued property
            # (one entry per OR'd clause). Naively interpolating it joins
            # with a single space and the resulting OPATH is invalid.
            $rawFilter = $s.RecipientFilter
            $filterStr = ''
            if ($null -ne $rawFilter) {
                if ($rawFilter -is [string]) {
                    $filterStr = $rawFilter
                }
                elseif ($rawFilter -is [System.Collections.IEnumerable]) {
                    $parts = [System.Collections.Generic.List[string]]::new()
                    foreach ($p in $rawFilter) {
                        $t = "$p".Trim()
                        if ($t) { $null = $parts.Add("($t)") }
                    }
                    if ($parts.Count -gt 0) { $filterStr = ($parts -join ' -or ') }
                }
                else {
                    $filterStr = [string]$rawFilter
                }
            }
            $origin = if ($s.Default) { 'Built-in' } else { 'Custom' }
            $obj = [PSCustomObject]@{
                Name                      = "$($s.Name)"
                ScopeRestrictionType      = "$($s.ScopeRestrictionType)"
                RecipientRoot             = "$($s.RecipientRoot)"
                RecipientFilter           = $filterStr
                DatabaseRestrictionFilter = "$($s.DatabaseRestrictionFilter)"
                ServerRestrictionFilter   = "$($s.ServerRestrictionFilter)"
                Exclusive                 = [bool]$s.Exclusive
                Default                   = [bool]$s.Default
                FilterSummary             = $filterStr
                Origin                    = $origin
                _raw                      = $s
            }
            $null = $displayData.Add($obj)
        }
        catch {
            Write-Warning "Get-RBACManagementScopes: skipping scope '$($s.Name)' - $($_.Exception.Message)"
        }
    }
    # Comma operator forces PowerShell to return the array as-is instead of
    # unwrapping a single-element collection into a scalar.
    return ,@($displayData)
}