<# Script to generate Exchange role delegation diagram with interactive selection
Allows selection of role assignments via Out-GridView #>
function Invoke-ExchangeRBACRelationship {
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeSystemRoles = $false
    )

    # Generate output file name in the format yyyy-MM-dd-HHmmss-xxx.html
    $timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
    $randomSuffix = -join ((65..90) + (97..122) | Get-Random -Count 3 | ForEach-Object { [char]$_ })
    if (-not $OutputPath) {
        $OutputPath = "$env:TEMP\$timestamp-$randomSuffix.html"
    }

    # Create the output directory if needed
    $OutputDir = Split-Path $OutputPath -Parent
    if (!(Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    # Function to connect to Exchange Online
    function Connect-ExchangeOnlineIfNeeded {
        try {
            # Check if already connected using Get-ConnectionInformation
            $connectionInfo = Get-ConnectionInformation -ErrorAction SilentlyContinue
            if ($null -eq $connectionInfo) {
                Write-Host 'Connecting to Exchange Online...' -ForegroundColor Yellow
                $result = Connect-RBACExchangeOnline
                if ($result) {
                    Write-Host 'Successfully connected to Exchange Online!' -ForegroundColor Green
                }
            }
            else {
                Write-Host 'Already connected to Exchange Online' -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Error connecting to Exchange Online: $_" -ForegroundColor Red
            Write-Host 'Make sure you have installed the module: Install-Module -Name ExchangeOnlineManagement' -ForegroundColor Yellow
            return $false
        }
        return $true
    }

    # Connect to Exchange Online
    if (!(Connect-ExchangeOnlineIfNeeded)) {
        exit 1
    }

    Write-Host "`nRetrieving all Role Assignments..." -ForegroundColor Cyan

    # Retrieve all role assignments
    try {
        $allRoleAssignments = Get-ManagementRoleAssignment
        if (!$IncludeSystemRoles) {
            # Filter out system roles
            $allRoleAssignments = $allRoleAssignments | Where-Object {
                $_.RoleAssigneeName -notlike 'SystemMailbox*' -and
                $_.RoleAssigneeName -notlike 'DiscoveryMailbox*' -and
                $_.RoleAssigneeName -notlike 'Migration.*' -and
                $_.Role -notlike 'ApplicationImpersonation-*'
            }
        }
        # Prepare data for Out-GridView
        $assignmentData = $allRoleAssignments | Select-Object @{
            Name = 'Assignment Name'; Expression = { $_.Name }
        }, @{
            Name = 'Role'; Expression = { $_.Role }
        }, @{
            Name = 'Role Assignee'; Expression = { $_.RoleAssigneeName }
        }, @{
            Name = 'Assignee Type'; Expression = { $_.RoleAssigneeType }
        }, @{
            Name = 'Delegation Type'; Expression = { $_.RoleAssignmentDelegationType }
        }, @{
            Name = 'Scope'; Expression = {
                if ($_.CustomRecipientWriteScope) { $_.CustomRecipientWriteScope }
                elseif ($_.RecipientWriteScope) { $_.RecipientWriteScope }
                else { 'Organization' }
            }
        }, @{
            Name = 'Enabled'; Expression = { $_.Enabled }
        }, @{
            Name = 'Identity'; Expression = { $_.Identity }
        }
    }
    catch {
        Write-Host "Error retrieving roles: $_" -ForegroundColor Red
        exit 1
    }

    Write-Host "Total assignments found: $($assignmentData.Count)" -ForegroundColor Green

    # Show Out-GridView for selection
    Write-Host "`nOpening selection window..." -ForegroundColor Yellow
    Write-Host 'Select the Role Assignments to include in the diagram (Ctrl+Click for multiple)' -ForegroundColor Cyan

    $selectedAssignments = $assignmentData | Out-GridView -Title 'Select Role Assignments to visualize' -PassThru

    if (!$selectedAssignments) {
        Write-Host "`nNo selection made. Exiting script." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "`nYou selected $($selectedAssignments.Count) assignment(s)" -ForegroundColor Green

    # Get full details of selected assignments
    $selectedFullAssignments = @()
    foreach ($selected in $selectedAssignments) {
        $fullAssignment = $allRoleAssignments | Where-Object { $_.Identity -eq $selected.Identity }
        if ($fullAssignment) {
            $selectedFullAssignments += $fullAssignment
        }
    }

    # Group by Role Assignee for diagram organization
    $groupedAssignments = $selectedFullAssignments | Group-Object -Property RoleAssigneeName

    # Retrieve members of role groups if needed
    Write-Host "`nRetrieving members of role groups..." -ForegroundColor Cyan
    $roleGroupMembers = @{}
    foreach ($group in $groupedAssignments) {
        if ($group.Group[0].RoleAssigneeType -eq 'RoleGroup') {
            try {
                $members = Get-RoleGroupMember -Identity $group.Name -ErrorAction SilentlyContinue
                if ($members) {
                    $roleGroupMembers[$group.Name] = $members
                    Write-Host "  - $($group.Name): $($members.Count) member(s)" -ForegroundColor Gray
                }
            }
            catch {
                Write-Host "  - Unable to retrieve members of: $($group.Name)" -ForegroundColor DarkGray
            }
        }
    }

    # Generate the HTML report with interactive diagram
    Write-Host "`nGenerating HTML diagram..." -ForegroundColor Cyan

    New-HTML -Title 'Exchange Role Delegation - Selected Assignments' -FilePath $OutputPath -ShowHTML {
    
        New-HTMLSection -HeaderText "Exchange Role Assignments - Interactive Diagram ($($selectedAssignments.Count) selected)" {
        
            New-HTMLDiagram -Height '800px' {
            
                $nodeId = 0
                $roleColors = @{
                    'Mail'         = @{bg = '#4CAF50'; border = '#2E7D32' }
                    'Mailbox'      = @{bg = '#2196F3'; border = '#1565C0' }
                    'Organization' = @{bg = '#9C27B0'; border = '#6A1B9A' }
                    'Compliance'   = @{bg = '#FF9800'; border = '#F57C00' }
                    'Security'     = @{bg = '#F44336'; border = '#C62828' }
                    'Default'      = @{bg = '#607D8B'; border = '#455A64' }
                }
            
                # Create a central node if there are multiple assignees
                if ($groupedAssignments.Count -gt 1) {
                    New-DiagramNode -Id 'CentralHub' `
                        -Label "Exchange Online`nRole Assignments`n($($selectedAssignments.Count) selected)" `
                        -Level 0 `
                        -ColorBackground '#1a237e' `
                        -ColorBorder '#0d47a1' `
                        -Shape database `
                        -FontColor white `
                        -Size 70
                }
            
                # Process each assignment group
                foreach ($assigneeGroup in $groupedAssignments) {
                    $assignments = $assigneeGroup.Group
                
                    # For each individual assignment, create a complete diagram
                    foreach ($assignment in $assignments) {
                        $assignmentNodeId = "assignment_$nodeId"
                        $nodeId++
                    
                        # Create the central node for this Role Assignment (center)
                        New-DiagramNode -Id $assignmentNodeId `
                            -Label "$($assignment.Name)`n[Role Assignment]" `
                            -Level 0 `
                            -ColorBackground '#e0e0e0' `
                            -ColorBorder '#757575' `
                            -ColorHighlightBackground '#bdbdbd' `
                            -Shape box `
                            -FontColor '#424242' `
                            -Size 60
                    
                        $yOffset = ($assignments.IndexOf($assignment)) * -400
                        # The specific role
                        $roleNodeId = "role_$nodeId"
                        $nodeId++
                        # Determine color based on role type
                        $roleCategory = 'Default'
                        foreach ($key in $roleColors.Keys) {
                            if ($assignment.Role -like "*$key*") {
                                $roleCategory = $key
                                break
                            }
                        }
                        New-DiagramNode -Id $roleNodeId `
                            -Label "$($assignment.Role)`n[ManagementRole]" `
                            -Level 2 `
                            -ColorBackground '#4CAF50' `
                            -ColorBorder '#2E7D32' `
                            -Shape box `
                            -FontColor white `
                            -Size 40
                        # Arrow with label 'What'
                        New-DiagramEdge -From $assignmentNodeId -To $roleNodeId -ArrowsToEnabled -Color '#4CAF50' -Label 'What'
                    
                        # Add delegation type under the role
                        if ($assignment.RoleAssignmentDelegationType) {
                            # Retrieve ManagementRoleEntry for the role
                            try {
                                $roleEntries = Get-ManagementRoleEntry "$($assignment.Role)\*" -ErrorAction SilentlyContinue
                            } catch { $roleEntries = @() }
                            # Add each ManagementRoleEntry as a subnode directly linked to the arrow between ManagementRole and ManagementRoleEntry
                            if ($roleEntries) {
                                foreach ($entry in $roleEntries | Select-Object -First 5) {
                                    $entryNodeId = "roleentry_$nodeId"
                                    $nodeId++
                                    $entryLabel = "$($entry.Name) [$($entry.Type)]"
                                    New-DiagramNode -Id $entryNodeId `
                                        -Label $entryLabel `
                                        -Level 3 `
                                        -ColorBackground '#C5E1A5' `
                                        -ColorBorder '#558B2F' `
                                        -Shape box `
                                        -FontColor '#33691E' `
                                        -Size 20
                                    New-DiagramEdge -From $roleNodeId -To $entryNodeId -ArrowsToEnabled -Color '#81C784' -Label "$($assignment.RoleAssignmentDelegationType)"
                                }
                                if ($roleEntries.Count -gt 5) {
                                    $moreEntryNodeId = "moreentry_$nodeId"
                                    $nodeId++
                                    New-DiagramNode -Id $moreEntryNodeId `
                                        -Label "+$($roleEntries.Count - 5) more..." `
                                        -Level 3 `
                                        -ColorBackground '#F0F4C3' `
                                        -ColorBorder '#827717' `
                                        -Shape box `
                                        -FontColor '#827717' `
                                        -Size 15
                                    New-DiagramEdge -From $roleNodeId -To $moreEntryNodeId -ArrowsToEnabled -Color '#81C784' -Dashes -Label "$($assignment.RoleAssignmentDelegationType)"
                                }
                            }
                        }
                    
                        # The specific assignee
                        $assigneeNodeId = "assignee_$nodeId"
                        $nodeId++
                        # Determine color based on assignee type
                        $assigneeColor = switch ($assignment.RoleAssigneeType) {
                            'RoleGroup' { @{bg = '#9C27B0'; border = '#6A1B9A' } }
                            'User' { @{bg = '#2196F3'; border = '#1565C0' } }
                            'SecurityGroup' { @{bg = '#4CAF50'; border = '#2E7D32' } }
                            'RoleAssignmentPolicy' { @{bg = '#FF9800'; border = '#F57C00' } }
                            default { @{bg = '#607D8B'; border = '#455A64' } }
                        }
                        New-DiagramNode -Id $assigneeNodeId `
                            -Label "$($assignment.RoleAssigneeName)`n[$($assignment.RoleAssigneeType)]" `
                            -Level 2 `
                            -ColorBackground $assigneeColor.bg `
                            -ColorBorder $assigneeColor.border `
                            -Shape box `
                            -FontColor white `
                            -Size 40
                        # Arrow with label 'Who'
                        New-DiagramEdge -From $assignmentNodeId -To $assigneeNodeId -ArrowsToEnabled -Color '#9C27B0' -Label 'Who'
                    
                        # If it's a group, add members
                        if ($assignment.RoleAssigneeType -eq 'RoleGroup' -and $roleGroupMembers.ContainsKey($assignment.RoleAssigneeName)) {
                            $members = $roleGroupMembers[$assignment.RoleAssigneeName] | Select-Object -First 3
                            $memberXPos = -50
                            foreach ($member in $members) {
                                $memberNodeId = "member_$nodeId"
                                $nodeId++
                                # Try to get member type (RecipientTypeDetails or similar)
                                $memberType = $member.RecipientTypeDetails
                                if (-not $memberType) { $memberType = $member.ObjectClass }
                                if (-not $memberType) { $memberType = 'Unknown' }
                                New-DiagramNode -Id $memberNodeId `
                                    -Label "$($member.Name) [$memberType]" `
                                    -Level 3 `
                                    -ColorBackground '#E1BEE7' `
                                    -ColorBorder '#9C27B0' `
                                    -Shape box `
                                    -FontColor '#4A148C' `
                                    -Size 25
                                New-DiagramEdge -From $assigneeNodeId -To $memberNodeId -ArrowsToEnabled -Color '#CE93D8'
                                $memberXPos += 50
                            }
                        
                            if ($roleGroupMembers[$assignment.RoleAssigneeName].Count -gt 3) {
                                $moreNodeId = "moremember_$nodeId"
                                $nodeId++
                                New-DiagramNode -Id $moreNodeId `
                                    -Label "+$($roleGroupMembers[$assignment.RoleAssigneeName].Count - 3) more..." `
                                    -Level 3 `
                                    -ColorBackground '#F3E5F5' `
                                    -ColorBorder '#9C27B0' `
                                    -Shape box `
                                    -FontColor '#6A1B9A' `
                                    -Size 20
                                New-DiagramEdge -From $assigneeNodeId -To $moreNodeId -ArrowsToEnabled -Color '#CE93D8' -Dashes
                            }
                        }
                    
                        # The specific scope
                        $scopeNodeId = "scope_$nodeId"
                        $nodeId++
                        $scopeText = if ($assignment.CustomRecipientWriteScope) { 
                            $assignment.CustomRecipientWriteScope 
                        }
                        elseif ($assignment.RecipientWriteScope) { 
                            $assignment.RecipientWriteScope 
                        }
                        else { 
                            'Organization' 
                        }
                        New-DiagramNode -Id $scopeNodeId `
                            -Label "$scopeText`n[Scope Management]" `
                            -Level 2 `
                            -ColorBackground '#F44336' `
                            -ColorBorder '#C62828' `
                            -Shape box `
                            -FontColor white `
                            -Size 40
                        # Arrow with label 'Where'
                        New-DiagramEdge -From $assignmentNodeId -To $scopeNodeId -ArrowsToEnabled -Color '#F44336' -Label 'Where'
                        # Add ScopeFilter as a subnode
                        if ($assignment.ScopeFilter) {
                            $scopeFilterNodeId = "scopefilter_$nodeId"
                            $nodeId++
                            New-DiagramNode -Id $scopeFilterNodeId `
                                -Label "ScopeFilter: $($assignment.ScopeFilter)" `
                                -Level 3 `
                                -ColorBackground '#FFCDD2' `
                                -ColorBorder '#C62828' `
                                -Shape box `
                                -FontColor '#C62828' `
                                -Size 25
                            New-DiagramEdge -From $scopeNodeId -To $scopeFilterNodeId -ArrowsToEnabled -Color '#FFCDD2'
                        }
                    }
                }
            
            } -DisableLoader
        }
    
        # Section with summary table
        New-HTMLSection -HeaderText 'Selected Assignments Details' {
            New-HTMLTable -DataTable $selectedAssignments {
                New-TableHeader -Title 'Role Assignments Details' -BackGroundColor '#1a237e' -Color white
                New-HTMLTableCondition -Name 'Delegation Type' -ComparisonType string -Operator eq -Value 'Delegating' -BackgroundColor '#FFF9C4'
                New-HTMLTableCondition -Name 'Enabled' -ComparisonType string -Operator eq -Value 'False' -BackgroundColor '#FFCDD2'
            }
        }
    }

    # Option to restart selection
    <#
    $restart = Read-Host "`nDo you want to select other assignments? (Y/N)"
    if ($restart -eq 'Y') {
        & $MyInvocation.MyCommand.Path
    }
#>
}
