[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/ExchangeRBACManager.svg?label=powershell%20gallery&color=0078D4)](https://www.powershellgallery.com/packages/ExchangeRBACManager)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/ExchangeRBACManager.svg?label=downloads&color=2EA043)](https://www.powershellgallery.com/packages/ExchangeRBACManager)

Exchange RBAC Manager
=====================

**PowerShell module with a Windows GUI to explore and manage Role-Based Access Control (RBAC) in Exchange Online**

Instead of stitching together `Get-RoleGroup`, `Get-ManagementRoleAssignment`, `Get-ManagementScope`, `Search-AdminAuditLog` and friends by hand, you browse and act on them through a single Fluent-style window organised by RBAC concept.

Features
--------

*   **RBAC Visualizer** - hub-and-spoke diagram (Role / Assignee / Scope) for any role assignment, exportable to PNG
*   **Eight integrated views** - Role Groups, Roles, Role Assignments, Scopes, Scope membership preview, User Rights, Command Lookup, Audit Log
*   **Scope membership preview** - validate a `RecipientRestrictionFilter` *before* attaching it to an assignment
*   **User Rights lookup** - effective roles for a UPN/alias, including how each role was granted (direct vs via group)
*   **Command Lookup** - reverse mapping cmdlet -> roles that grant it
*   **Live filter, contextual actions, CSV/PNG export** - on every view
*   **Modern auth (MFA-aware) with optional WAM toggle** - via the standard `Connect-ExchangeOnline` flow

Quick Start
-----------

### Installation

Install directly from the PowerShell Gallery:

```powershell
Install-Module -Name ExchangeRBACManager -Scope CurrentUser
```

To update later:

```powershell
Update-Module -Name ExchangeRBACManager
```

### Basic Usage

```powershell
# Import the module
Import-Module ExchangeRBACManager

# Launch the GUI
Invoke-ExchangeRBACManager
```

A single window opens. Click **Connect to Exchange Online** in the sidebar to authenticate; the tenant block then turns green and the active section loads its data.

### Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- [`ExchangeOnlineManagement`](https://www.powershellgallery.com/packages/ExchangeOnlineManagement) (auto-installed on first launch if missing)
- An Exchange Online tenant and an account with the appropriate Exchange RBAC role (at minimum **View-Only Organization Management** for read scenarios, **Organization Management** for write actions)

RBAC Visualizer - the headline feature
--------------------------------------

![RBAC Visualizer](docs/screenshots/rbac-visualizer.png)

RBAC in Exchange Online is a triangle: **what** (a role), **who** (an assignee) and **where** (a scope). The Visualizer turns any role assignment into a hub-and-spoke diagram so you can answer those three questions in one glance instead of cross-referencing four cmdlets.

Pick any role assignment and you get:

- **Centre (purple)** - the assignment itself
- **Top-left (green)** - the *Role* it grants (the **what**)
- **Top-right (yellow)** - the *Assignee* it applies to (the **who**)
- **Bottom (pink)** - the *Scope* it is restricted to (the **where**)

Buttons:

- **Pick assignment...** - choose any assignment from a searchable picker
- **Refit / Center** - re-renders if you resized the window
- **Export PNG** - saves the canvas to a PNG for tickets, reviews or documentation

Typically the section you open first when investigating an unexpected permission, preparing a change request, or documenting a delegation for an audit.

The eight sections
------------------

Each section wraps a specific Exchange RBAC cmdlet (or composition of cmdlets) and exposes the same toolbar pattern: live search, chip filters, *Refresh*, *Export CSV*, plus contextual actions on selected rows.

### 1. Role Groups

![Role Groups](docs/screenshots/role-groups.png)

Backed by `Get-RoleGroup`. Lists every Universal Security Group that bundles management roles with members and scopes. The grid shows the group name, an **Origin** badge (Built-in vs Custom), the number of members and roles bound to it, and the description.

Use it to inventory who-can-do-what at the group level, find empty or oversized groups, or copy a built-in group as a starting template for a tighter custom one.

### 2. Roles

![Roles](docs/screenshots/roles.png)

Backed by `Get-ManagementRole`. A management role is the smallest container of cmdlets and parameters that grant a capability. The grid shows the role name, its **Type** (regular vs unscoped), an **Origin** badge (Built-in vs Custom), the **Parent role** it derives from, and the description.

Use it to understand the role hierarchy (every custom role inherits from a parent built-in role) and to find candidate roles when you are designing a least-privilege delegation.

### 3. Role Assignments

![Role Assignments](docs/screenshots/role-assignments.png)

Backed by `Get-ManagementRoleAssignment`. The actual binding that ties a *Role* to an *Assignee* (user, role group, USG or policy) within a *Scope*. The grid shows the assignment name, the role, the assignee, the assignee type, and both the read and write scopes.

This is the workhorse view: most "why does this user have access?" questions are answered here. Selecting an assignment lights up **Visualize** in the floating action bar so you can jump directly to the diagram.

### 4. Scopes

![Scopes](docs/screenshots/scopes.png)

Backed by `Get-ManagementScope`. Scopes restrict a role assignment to a subset of recipients, servers or databases. The grid shows the scope name, the restriction type, the recipient root (when set) and the recipient filter expression.

A custom scope's filter is a piece of OPATH that is famously easy to write incorrectly. The next section is the antidote.

### 5. Scope membership preview

![Scope members preview](docs/screenshots/scope-preview-members.png)

In the *Scopes* section, select a scope and click **Preview members** in the floating action bar. The module calls `Get-Recipient -RecipientPreviewFilter <scope filter>` and shows you exactly which recipients fall inside that scope's filter.

The point is to validate a `RecipientRestrictionFilter` *before* you attach it to a role assignment - so you never end up granting "Mailbox Import Export" against a scope that turns out to match the entire tenant. Results are capped to a safe number of rows and labelled as *truncated* if the scope matches more than the cap.

### 6. User Rights

![User Rights](docs/screenshots/user-rights.png)

Type a UPN or alias and press *Enter*. The module:

1. Walks every cached `Get-ManagementRoleAssignment`.
2. For each `RoleGroup` assignee, expands `Get-RoleGroup -Identity ... | Members`.
3. Returns every effective role plus how it was granted (direct vs via group) plus read and write scopes.

Useful before/after onboarding, offboarding, or to answer "why does this user have access to X?". Also the right view to confirm a privileged user has no leftover assignments after a role rotation.

### 7. Command Lookup

![Command Lookup](docs/screenshots/command-lookup.png)

Type a cmdlet name (`Set-Mailbox`, `New-MailboxExportRequest`, ...) and press *Enter*. The module calls `Get-ManagementRole -Cmdlet <cmdlet>` and returns every role that grants it, with type, origin (Built-in / Custom) and description.

The reverse of every other section: instead of starting from a role and finding its cmdlets, you start from a cmdlet and find which role(s) would let a user run it. Indispensable when an admin reports "I get an access denied on `Set-MailboxRegionalConfiguration`" and you have to figure out which role is missing.

### 8. Audit Log

Planned for a future release. Clicking the *Audit Log* section currently shows a "coming soon" notice. The implementation will call `Search-AdminAuditLog` over the last 7 / 30 / 90 days (limit imposed by Exchange Online) and surface recent admin changes (caller, cmdlet, target object, parameters).

Public commands
---------------

- `Invoke-ExchangeRBACManager` - launches the GUI
- `Invoke-ExchangeRBACRelationship` - generates a standalone HTML diagram of role-group -> role -> assignment relationships (separate from the embedded Visualizer)

Links
-----

*   **PowerShell Gallery**: [ExchangeRBACManager Module](https://www.powershellgallery.com/packages/ExchangeRBACManager)
*   **Issues & Support**: [GitHub Issues](https://github.com/bastienperez/exchange-rbac-manager/issues)
*   **Source**: [github.com/bastienperez/exchange-rbac-manager](https://github.com/bastienperez/exchange-rbac-manager)

---

**Created and maintained by [Bastien Perez](https://www.linkedin.com/in/perez-bastien/) | Powered by [Clidsys](https://clidsys.com)**
