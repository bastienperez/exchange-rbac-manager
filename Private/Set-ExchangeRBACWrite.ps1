function Format-RBACCmdletPreview {
    <#
    .SYNOPSIS
    Format a cmdlet name + parameters into a copy-pastable PowerShell string.
    Used by the GUI's dry-run mode to preview what a write action would run.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Cmdlet,
        [Parameter()]                   [hashtable]$Parameters = @{}
    )

    $parts = @($Cmdlet)
    foreach ($key in ($Parameters.Keys | Sort-Object)) {
        $value = $Parameters[$key]
        if ($null -eq $value) { $parts += "-$key `$null"; continue }
        if ($value -is [bool] -or $value -is [System.Management.Automation.SwitchParameter]) {
            $parts += '-{0}:${1}' -f $key, ([bool]$value).ToString().ToLowerInvariant()
            continue
        }
        if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
            $items = @($value | ForEach-Object {
                $s = "$_".Replace("'", "''")
                "'$s'"
            })
            $parts += "-$key @($($items -join ','))"
            continue
        }
        $s = "$value".Replace("'", "''")
        $parts += "-$key '$s'"
    }
    return ($parts -join ' ')
}

function Invoke-RBACWrite {
    <#
    .SYNOPSIS
    Internal wrapper that either previews a write action (-DryRun) or executes it.
    Returns @{ Preview = '<cmdlet>'; Result = <object> ; Executed = $bool ; Error = <obj?> }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Cmdlet,
        [Parameter()]                   [hashtable]$Parameters = @{},
        [Parameter()]                   [switch]$DryRun
    )
    $preview = Format-RBACCmdletPreview -Cmdlet $Cmdlet -Parameters $Parameters
    if ($DryRun) {
        return [pscustomobject]@{
            Preview  = $preview
            Result   = $null
            Executed = $false
            Error    = $null
        }
    }
    try {
        $result = & $Cmdlet @Parameters -ErrorAction Stop
        return [pscustomobject]@{
            Preview  = $preview
            Result   = $result
            Executed = $true
            Error    = $null
        }
    }
    catch {
        return [pscustomobject]@{
            Preview  = $preview
            Result   = $null
            Executed = $false
            Error    = $_
        }
    }
}

function New-RBACRoleGroup {
    <#
    .SYNOPSIS
    Create a new Exchange Online role group.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter()]                   [string]$Description,
        [Parameter()]                   [string[]]$Roles,
        [Parameter()]                   [string[]]$Members,
        [Parameter()]                   [switch]$DryRun
    )
    $params = @{ Name = $Name }
    if ($PSBoundParameters.ContainsKey('Description') -and $Description) { $params.Description = $Description }
    if ($Roles   -and $Roles.Count   -gt 0) { $params.Roles   = $Roles }
    if ($Members -and $Members.Count -gt 0) { $params.Members = $Members }
    return (Invoke-RBACWrite -Cmdlet 'New-RoleGroup' -Parameters $params -DryRun:$DryRun)
}

function Set-RBACRoleGroup {
    <#
    .SYNOPSIS
    Update description and (optionally) members of an existing role group.
    The group's Name acts as the identity in Exchange Online and cannot be renamed
    via Set-RoleGroup, only its DisplayName/Description/membership can change.
    Pass -Members to overwrite the membership list (empty array clears it).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Identity,
        [Parameter()]                   [string]$Description,
        [Parameter()]                   [string]$DisplayName,
        [Parameter()]                   [string[]]$Members,
        [Parameter()]                   [switch]$DryRun
    )
    $results = New-Object System.Collections.Generic.List[object]

    $setParams = @{ Identity = $Identity }
    if ($PSBoundParameters.ContainsKey('Description'))  { $setParams.Description = $Description }
    if ($PSBoundParameters.ContainsKey('DisplayName') -and $DisplayName) { $setParams.DisplayName = $DisplayName }
    if ($setParams.Count -gt 1) {
        $results.Add((Invoke-RBACWrite -Cmdlet 'Set-RoleGroup' -Parameters $setParams -DryRun:$DryRun))
    }

    if ($PSBoundParameters.ContainsKey('Members')) {
        $memberParams = @{ Identity = $Identity; Members = $Members; Confirm = $false }
        $results.Add((Invoke-RBACWrite -Cmdlet 'Update-RoleGroupMember' -Parameters $memberParams -DryRun:$DryRun))
    }

    return ,@($results.ToArray())
}

function Remove-RBACRoleGroup {
    <#
    .SYNOPSIS
    Delete an Exchange Online role group. Built-in groups cannot be removed; the
    GUI is responsible for guarding against that before calling.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Identity,
        [Parameter()]                   [switch]$DryRun
    )
    $params = @{ Identity = $Identity; Confirm = $false }
    return (Invoke-RBACWrite -Cmdlet 'Remove-RoleGroup' -Parameters $params -DryRun:$DryRun)
}

function New-RBACRole {
    <#
    .SYNOPSIS
    Create a custom Management Role as a child of an existing role.
    Exchange roles are normally created by copying a parent (built-in or custom)
    and then trimming role entries from the child.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] [string]$Parent,
        [Parameter()]                   [string]$Description,
        [Parameter()]                   [switch]$DryRun
    )
    $params = @{ Name = $Name; Parent = $Parent }
    if ($Description) { $params.Description = $Description }
    return (Invoke-RBACWrite -Cmdlet 'New-ManagementRole' -Parameters $params -DryRun:$DryRun)
}

function Set-RBACRole {
    <#
    .SYNOPSIS
    Update the description of a custom management role. Built-in roles cannot
    be modified; the GUI guards against that before calling.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Identity,
        [Parameter()]                   [string]$Description,
        [Parameter()]                   [switch]$DryRun
    )
    $params = @{ Identity = $Identity }
    if ($PSBoundParameters.ContainsKey('Description')) { $params.Description = $Description }
    return (Invoke-RBACWrite -Cmdlet 'Set-ManagementRole' -Parameters $params -DryRun:$DryRun)
}

function Remove-RBACRole {
    <#
    .SYNOPSIS
    Delete a custom management role. Built-in roles cannot be removed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Identity,
        [Parameter()]                   [switch]$DryRun
    )
    $params = @{ Identity = $Identity; Confirm = $false }
    return (Invoke-RBACWrite -Cmdlet 'Remove-ManagementRole' -Parameters $params -DryRun:$DryRun)
}

function Add-RBACRoleEntry {
    <#
    .SYNOPSIS
    Add a cmdlet (Management Role Entry) to a custom management role.
    Identity must be in the form 'RoleName\CmdletName'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Identity,
        [Parameter()]                   [switch]$DryRun
    )
    $params = @{ Identity = $Identity }
    return (Invoke-RBACWrite -Cmdlet 'Add-ManagementRoleEntry' -Parameters $params -DryRun:$DryRun)
}

function Remove-RBACRoleEntry {
    <#
    .SYNOPSIS
    Remove a cmdlet (Management Role Entry) from a custom management role.
    Identity must be in the form 'RoleName\CmdletName'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Identity,
        [Parameter()]                   [switch]$DryRun
    )
    $params = @{ Identity = $Identity; Confirm = $false }
    return (Invoke-RBACWrite -Cmdlet 'Remove-ManagementRoleEntry' -Parameters $params -DryRun:$DryRun)
}

function New-RBACAssignment {
    <#
    .SYNOPSIS
    Create a new management role assignment binding a role to an assignee.
    Exactly one of -SecurityGroup, -User, -Computer, -Policy, -App must be set.
    Optional recipient scoping is exposed via -RecipientOrganizationalUnitScope or
    -CustomRecipientWriteScope (mutually exclusive on Exchange's side).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] [string]$Role,
        [Parameter()]                   [ValidateSet('SecurityGroup','User','Computer','Policy','App')]
                                        [string]$AssigneeKind,
        [Parameter()]                   [string]$Assignee,
        [Parameter()]                   [string]$RecipientOrganizationalUnitScope,
        [Parameter()]                   [string]$CustomRecipientWriteScope,
        [Parameter()]                   [switch]$DryRun
    )
    if (-not $AssigneeKind -or -not $Assignee) {
        return [pscustomobject]@{
            Preview  = ''
            Result   = $null
            Executed = $false
            Error    = [System.Management.Automation.ErrorRecord]::new(
                          [System.ArgumentException]::new('Assignee kind and value are required.'),
                          'AssigneeMissing',
                          [System.Management.Automation.ErrorCategory]::InvalidArgument,
                          $null)
        }
    }
    $params = @{ Name = $Name; Role = $Role; $AssigneeKind = $Assignee }
    if ($RecipientOrganizationalUnitScope) { $params.RecipientOrganizationalUnitScope = $RecipientOrganizationalUnitScope }
    if ($CustomRecipientWriteScope)        { $params.CustomRecipientWriteScope        = $CustomRecipientWriteScope }
    return (Invoke-RBACWrite -Cmdlet 'New-ManagementRoleAssignment' -Parameters $params -DryRun:$DryRun)
}

function Set-RBACAssignment {
    <#
    .SYNOPSIS
    Update an existing management role assignment. Only the write scope and the
    enabled flag are mutable - the Read scope is implicit (inherited from the
    parent Role) and cannot be set at assignment level in Exchange Online.

    The three *WriteScope parameters are mutually exclusive on Exchange's side;
    pass at most one. Pass an empty string to clear a value (e.g. ''CustomRecipientWriteScope').
    .PARAMETER Identity
    Existing assignment name (or DN).
    .PARAMETER CustomRecipientWriteScope
    Name of a custom management scope to use as the write scope.
    .PARAMETER RecipientOrganizationalUnitScope
    OU DN. The assignment will only write to recipients under that OU.
    .PARAMETER RecipientRelativeWriteScope
    Predefined scope. Valid: Organization, Self, MyGAL, MyDirectReports,
    MyDistributionGroups, NotApplicable.
    .PARAMETER Enabled
    Toggle the assignment on/off.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Identity,
        [Parameter()]                   [string]$CustomRecipientWriteScope,
        [Parameter()]                   [string]$RecipientOrganizationalUnitScope,
        [Parameter()]
            [ValidateSet('Organization','Self','MyGAL','MyDirectReports','MyDistributionGroups','NotApplicable')]
                                        [string]$RecipientRelativeWriteScope,
        [Parameter()]                   [Nullable[bool]]$Enabled,
        [Parameter()]                   [switch]$DryRun
    )

    $params = @{ Identity = $Identity }
    if ($PSBoundParameters.ContainsKey('CustomRecipientWriteScope')) {
        $params.CustomRecipientWriteScope = $CustomRecipientWriteScope
    }
    if ($PSBoundParameters.ContainsKey('RecipientOrganizationalUnitScope')) {
        $params.RecipientOrganizationalUnitScope = $RecipientOrganizationalUnitScope
    }
    if ($PSBoundParameters.ContainsKey('RecipientRelativeWriteScope')) {
        $params.RecipientRelativeWriteScope = $RecipientRelativeWriteScope
    }
    if ($PSBoundParameters.ContainsKey('Enabled') -and $null -ne $Enabled) {
        $params.Enabled = [bool]$Enabled
    }

    if ($params.Count -le 1) {
        return [pscustomobject]@{
            Preview  = ''
            Result   = $null
            Executed = $false
            Error    = [System.Management.Automation.ErrorRecord]::new(
                          [System.ArgumentException]::new('Nothing to update - pass at least one of CustomRecipientWriteScope / RecipientOrganizationalUnitScope / RecipientRelativeWriteScope / Enabled.'),
                          'NothingToUpdate',
                          [System.Management.Automation.ErrorCategory]::InvalidArgument,
                          $null)
        }
    }

    return (Invoke-RBACWrite -Cmdlet 'Set-ManagementRoleAssignment' -Parameters $params -DryRun:$DryRun)
}

function Remove-RBACAssignment {
    <#
    .SYNOPSIS
    Delete a management role assignment. Built-in delegating assignments
    (Identity ends with '-Delegating' and similar) often refuse removal; the
    GUI surfaces the underlying error if the cmdlet refuses.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Identity,
        [Parameter()]                   [switch]$DryRun
    )
    $params = @{ Identity = $Identity; Confirm = $false }
    return (Invoke-RBACWrite -Cmdlet 'Remove-ManagementRoleAssignment' -Parameters $params -DryRun:$DryRun)
}

function New-RBACScope {
    <#
    .SYNOPSIS
    Create a recipient management scope. Pass -RecipientRoot for an OU-scoped
    scope and/or -RecipientRestrictionFilter for an OPATH filter.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter()]                   [string]$RecipientRoot,
        [Parameter()]                   [string]$RecipientRestrictionFilter,
        [Parameter()]                   [switch]$DryRun
    )
    if (-not $RecipientRoot -and -not $RecipientRestrictionFilter) {
        return [pscustomobject]@{
            Preview  = ''
            Result   = $null
            Executed = $false
            Error    = [System.Management.Automation.ErrorRecord]::new(
                          [System.ArgumentException]::new('Provide RecipientRoot, RecipientRestrictionFilter, or both.'),
                          'ScopeFilterMissing',
                          [System.Management.Automation.ErrorCategory]::InvalidArgument,
                          $null)
        }
    }
    $params = @{ Name = $Name }
    if ($RecipientRoot)              { $params.RecipientRoot              = $RecipientRoot }
    if ($RecipientRestrictionFilter) { $params.RecipientRestrictionFilter = $RecipientRestrictionFilter }
    return (Invoke-RBACWrite -Cmdlet 'New-ManagementScope' -Parameters $params -DryRun:$DryRun)
}

function Set-RBACScope {
    <#
    .SYNOPSIS
    Update an existing recipient management scope (filter, root, name).
    Pass -NewName to rename. Built-in implicit scopes cannot be modified.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Identity,
        [Parameter()]                   [string]$NewName,
        [Parameter()]                   [string]$RecipientRoot,
        [Parameter()]                   [string]$RecipientRestrictionFilter,
        [Parameter()]                   [switch]$DryRun
    )
    $params = @{ Identity = $Identity }
    if ($PSBoundParameters.ContainsKey('NewName') -and $NewName) { $params.Name = $NewName }
    if ($PSBoundParameters.ContainsKey('RecipientRoot'))         { $params.RecipientRoot = $RecipientRoot }
    if ($PSBoundParameters.ContainsKey('RecipientRestrictionFilter')) {
        $params.RecipientRestrictionFilter = $RecipientRestrictionFilter
    }
    return (Invoke-RBACWrite -Cmdlet 'Set-ManagementScope' -Parameters $params -DryRun:$DryRun)
}

function Remove-RBACScope {
    <#
    .SYNOPSIS
    Delete a custom management scope. Implicit scopes cannot be removed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Identity,
        [Parameter()]                   [switch]$DryRun
    )
    $params = @{ Identity = $Identity; Confirm = $false }
    return (Invoke-RBACWrite -Cmdlet 'Remove-ManagementScope' -Parameters $params -DryRun:$DryRun)
}

function Copy-RBACRoleGroup {
    <#
    .SYNOPSIS
    Duplicate a role group with its recipient restrictions and optional members.
    Every assignment is read before creating anything. New-RoleGroup can apply
    only one common scope, so mixed or unsupported restrictions fail closed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$SourceName,
        [Parameter(Mandatory = $true)] [string]$NewName,
        [Parameter()]                   [string]$NewDescription,
        [Parameter()]                   [switch]$IncludeMembers,
        [Parameter()]                   [switch]$DryRun
    )
    try {
        $source = Get-RoleGroup -Identity $SourceName -ErrorAction Stop
        if (-not $source) { throw "Role group '$SourceName' was not returned." }

        # Read the group's own assignment references individually. An empty or
        # filtered tenant-wide listing must never be mistaken for unrestricted roles.
        if (-not $source.PSObject.Properties['RoleAssignments'] -or -not $source.PSObject.Properties['Roles']) {
            throw 'Cannot copy: role or assignment information is missing from the source group.'
        }
        $references = @($source.RoleAssignments | ForEach-Object { $_ })
        $sourceRoles = @($source.Roles | ForEach-Object { $_ })
        if ($references.Count -ne $sourceRoles.Count -or
            @($references | Where-Object { [string]::IsNullOrWhiteSpace("$_") }).Count -gt 0) {
            throw 'Cannot copy: the complete list of role assignments is unavailable or contains multiple assignments per role.'
        }

        $rolesToCopy = @()
        $commonScope = $null
        foreach ($reference in $references) {
            $found = @(Get-ManagementRoleAssignment -Identity $reference -ErrorAction Stop)
            if ($found.Count -ne 1) { throw "Cannot read exactly one assignment '$reference'." }
            $assignment = $found[0]
            if ($assignment.Enabled -ne $true -or "$($assignment.DelegationType)" -ne 'Regular') {
                throw "Cannot copy assignment '$reference': disabled or delegating assignments are not supported."
            }
            if ([string]::IsNullOrWhiteSpace("$($assignment.Role)")) {
                throw "Cannot copy assignment '$reference': its role is missing."
            }
            $roleResult = @(Get-ManagementRole -Identity $assignment.Role -ErrorAction Stop)
            if ($roleResult.Count -ne 1) { throw "Cannot read the role of assignment '$reference'." }
            $role = $roleResult[0]
            if ([string]::IsNullOrWhiteSpace("$($role.Name)") -or $role.Name -in $rolesToCopy) {
                throw 'Cannot copy: missing role name or multiple assignments for the same role.'
            }
            $rolesToCopy += "$($role.Name)"

            # Read/configuration scopes must match what New-RoleGroup inherits
            # from this role. Never silently drop a configuration restriction.
            foreach ($scopeProperty in @('RecipientReadScope', 'ConfigReadScope', 'ConfigWriteScope')) {
                $actual = "$($assignment.$scopeProperty)"
                $implicit = "$($role.("Implicit$scopeProperty"))"
                if ([string]::IsNullOrWhiteSpace($actual) -or
                    [string]::IsNullOrWhiteSpace($implicit) -or $actual -ne $implicit) {
                    throw "Cannot copy assignment '$reference': $scopeProperty cannot be preserved by New-RoleGroup."
                }
            }
            foreach ($unsupported in @('CustomConfigWriteScope', 'ExclusiveConfigWriteScope',
                    'ExclusiveRecipientWriteScope', 'RecipientOrganizationalUnitScope',
                    'RecipientAdministrativeUnitScope', 'RecipientGroupScope')) {
                if (-not [string]::IsNullOrWhiteSpace("$($assignment.$unsupported)")) {
                    throw "Cannot copy assignment '$reference': $unsupported is not supported."
                }
            }

            $scope = ''
            if ("$($assignment.RecipientWriteScope)" -eq 'CustomRecipientScope') {
                $scope = "$($assignment.CustomRecipientWriteScope)"
                if ([string]::IsNullOrWhiteSpace($scope)) {
                    throw "Cannot copy assignment '$reference': the custom recipient scope is unresolved."
                }
            }
            elseif ([string]::IsNullOrWhiteSpace("$($assignment.RecipientWriteScope)") -or
                [string]::IsNullOrWhiteSpace("$($role.ImplicitRecipientWriteScope)") -or
                "$($assignment.RecipientWriteScope)" -ne "$($role.ImplicitRecipientWriteScope)" -or
                -not [string]::IsNullOrWhiteSpace("$($assignment.CustomRecipientWriteScope)")) {
                throw "Cannot copy assignment '$reference': its recipient write restriction is unsupported."
            }
            if ($null -ne $commonScope -and $scope -ne $commonScope) {
                throw 'Cannot copy: assignments use different recipient scopes. Copy them individually to preserve their restrictions.'
            }
            $commonScope = $scope
        }

        $params = @{ Name = $NewName }
        if ($NewDescription) { $params.Description = $NewDescription }
        elseif ($source.Description) { $params.Description = "$($source.Description) (copy of $SourceName)" }
        if ($rolesToCopy.Count -gt 0) { $params.Roles = $rolesToCopy }
        if ($commonScope) { $params.CustomRecipientWriteScope = $commonScope }
        $sourceMembers = @($source.Members | ForEach-Object { "$_" } | Where-Object { $_ })
        if ($IncludeMembers -and $sourceMembers.Count -gt 0) { $params.Members = $sourceMembers }
    }
    catch {
        return [pscustomobject]@{
            Preview  = ''
            Result   = $null
            Executed = $false
            Error    = $_
        }
    }

    return (Invoke-RBACWrite -Cmdlet 'New-RoleGroup' -Parameters $params -DryRun:$DryRun)
}
