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
    
    try {
        $roleGroups = Get-RoleGroup
        
        if ($roleGroups) {
            # Prepare data for display
            $displayData = $roleGroups | ForEach-Object {
                [PSCustomObject]@{
                    Name        = $_.Name
                    Description = $_.Description
                    MemberCount = if ($_.Members) { @($_.Members).Count } else { 0 }
                    RoleCount   = if ($_.Roles) { @($_.Roles).Count } else { 0 }
                    Members     = $_.Members
                    Roles       = $_.Roles
                }
            }
            return $displayData
        }
        else {
            return @()
        }
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
            # Prepare data for display with a summary field for the filter
            $displayData = $scopes | ForEach-Object {
                $filterSummary = if ($_.RecipientFilter) { 
                    if ($_.RecipientFilter.Length -gt 50) {
                        "$($_.RecipientFilter.Substring(0, 47))..."
                    }
                    else {
                        $_.RecipientFilter
                    }
                }
                else { '' }
                
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