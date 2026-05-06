# RBAC Exchange Manager

A PowerShell module providing a Windows GUI to **inspect** Role-Based Access Control (RBAC) in **Exchange Online**.

> **🔒 Read-only - current version.** This release only queries Exchange Online (`Get-*` cmdlets and `Search-AdminAuditLog`) and exports results to CSV / PNG. It does **not** create, modify or delete role groups, roles, assignments or scopes yet. For now, use the Exchange admin centre or `New-/Set-/Remove-*` cmdlets directly for any change.
>
> ✏️ **Coming in the next version:** create / edit / delete actions (role groups, role assignments, scopes, role-group membership).

![Overview](docs/screenshots/role-assignments.png)

---

## What it does

The module wraps Exchange Online **read** RBAC cmdlets in a native WPF interface. Instead of running and parsing `Get-RoleGroup`, `Get-ManagementRoleAssignment`, `Search-AdminAuditLog` etc. by hand, you browse them through a single window organised by RBAC concept.

A **READ-ONLY** badge is visible in every section header to make the current scope explicit.

### Not yet supported (planned for the next version)

- 🟡 `New-*` - create role groups / assignments / scopes / roles
- 🟡 `Set-*` - rename, edit description, change scope
- 🟡 `Remove-*` - delete role groups / assignments / scopes / custom roles
- 🟡 Membership - add / remove members of a role group
- 🟡 `Update-RoleGroupMember`

**Eight sections** in the left navigation:

| # | Section | Underlying cmdlet(s) | What you see |
|---|---|---|---|
| 1 | Role Groups | `Get-RoleGroup` | Names, member counts, role counts, descriptions |
| 2 | Roles | `Get-ManagementRole` | Name, type, Built-in / Custom origin, parent, description |
| 3 | Role Assignments | `Get-ManagementRoleAssignment` | Assignment name, role, assignee, type, read/write scopes |
| 4 | Scopes | `Get-ManagementScope` | Scope name, restriction type, recipient root, filter |
| 5 | User Rights | computed from assignments + `Get-RoleGroup` membership | Effective roles for a given user (UPN or alias) |
| 6 | Command Lookup | `Get-ManagementRole -Cmdlet` | Roles that grant a given cmdlet |
| 7 | RBAC Visualizer | derived from selected assignment | Hub-and-spoke graph: assignment in centre, three spokes (Role / Assignee / Scope) |
| 8 | Audit Log | `Search-AdminAuditLog` | Recent admin changes (last 7 / 30 / 90 days) |

![Role Groups](docs/screenshots/role-groups.png)

![Roles](docs/screenshots/roles.png)

![Scopes](docs/screenshots/scopes.png)

---

## Installation

```powershell
git clone https://github.com/bastienperez/Pv-Exchange-RBAC-Manager.git
Import-Module .\Pv-Exchange-RBAC-Manager\RBACExchangeManager.psd1

# or, install permanently for the current user:
Copy-Item -Path .\Pv-Exchange-RBAC-Manager `
          -Destination "$($env:PSModulePath.Split(';')[0])\RBACExchangeManager" `
          -Recurse -Force
```

### Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- [`ExchangeOnlineManagement`](https://www.powershellgallery.com/packages/ExchangeOnlineManagement) (auto-installed on first launch if missing)
- An Exchange Online tenant and an account that has at least the **View-Only Organization Management** role (the module never needs more than read permissions)

---

## Usage

```powershell
Invoke-ExchangeRBACManager
```

A single window opens. Click **Connect to Exchange Online** in the sidebar to authenticate; the tenant block then turns green and the active section loads its data.

### Workflow primer

1. **Connect** - sidebar → *Connect to Exchange Online*. The module piggy-backs on the standard `Connect-ExchangeOnline` flow (modern auth, MFA-aware).
2. **Pick a section** - one click in the sidebar; the title, breadcrumbs, columns and action bar adapt.
3. **Filter** - type in the toolbar search box and press *Enter*. The local cache is filtered across all visible columns.
4. **Inspect a row** - selecting a single row opens the **details panel** on the right, showing every field of the underlying object (with text wrapping for long scopes / parameter lists).
5. **Refresh** - toolbar *Refresh* re-queries Exchange Online for the current section.
6. **Export** - every section has *Export CSV* in the action bar.

The action bar is intentionally minimal in this version: only **read** actions (Lookup, Visualize, View Cmdlets) and **Export CSV**. Create / edit / delete buttons will land in the next version.

---

## The RBAC Visualizer

Click any role assignment, then **Visualize** in the action bar (or pick the *RBAC Visualizer* section directly).

You get a hub-and-spoke diagram:

- **Centre (purple)** - the assignment itself
- **Top-left (green)** - the *Role* it grants (the *what*)
- **Top-right (yellow)** - the *Assignee* it applies to (the *who*)
- **Bottom (pink)** - the *Scope* it is restricted to (the *where*)

![RBAC Visualizer](docs/screenshots/rbac-visualizer.png)

Buttons:

- **Pick assignment…** - opens an `Out-GridView` to choose any assignment
- **Refit** - re-renders if you resized the window
- **Export PNG** - saves the canvas to a PNG

---

## User Rights lookup

In the *User Rights* section, type a UPN or alias and press *Enter*. The module:

1. Walks every cached `Get-ManagementRoleAssignment`
2. For each `RoleGroup` assignee, expands `Get-RoleGroup -Identity … | Members`
3. Returns every effective role + how it was granted (direct / via group) + read & write scopes

Useful before/after onboarding, offboarding, or to answer “*why does this user have access to X?*”.

![User Rights](docs/screenshots/user-rights.png)

---

## Command Lookup

Type a cmdlet name (`Set-Mailbox`, `New-MailboxExportRequest`, …) and press *Enter*. The module calls `Get-ManagementRole -Cmdlet <cmdlet>` and returns every role that grants it, with type, origin (Built-in / Custom) and description.

![Command Lookup](docs/screenshots/command-lookup.png)

---

## Audit Log

The *Audit Log* section calls `Search-AdminAuditLog` for the last 7 / 30 / 90 days (selectable in the action bar). Each row shows timestamp, caller, cmdlet, target object and parameters. Note: `Search-AdminAuditLog` only returns up to 90 days and is throttled by Exchange Online.

---

## Public commands

- `Invoke-ExchangeRBACManager` - launches the GUI
- `Invoke-ExchangeRBACRelationship` - generates a standalone HTML diagram of role-group → role → assignment relationships (separate from the embedded Visualizer)

---

## Author

Bastien Perez
