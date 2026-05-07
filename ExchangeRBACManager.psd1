@{
    RootModule = 'ExchangeRBACManager.psm1'
    ModuleVersion = '0.4.0'
    GUID = 'cca45433-245f-4efa-93d2-a161e5d6c7be'
    Author = 'Bastien Perez'
    CompanyName = 'N/A'
    Copyright = '(c) 2025 Bastien Perez. All rights reserved.'
    Description = 'PowerShell module with GUI to manage RBAC in Exchange Online'
    PowerShellVersion = '5.1'
    RequiredModules = @('ExchangeOnlineManagement')
    FunctionsToExport = '*'
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Exchange', 'RBAC', 'Management')
            ProjectUri = 'https://github.com/bastienperez/exchange-rbac-manager'
        }
    }
}
