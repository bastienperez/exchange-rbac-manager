function Invoke-ExchangeGUI {
    <#
    .SYNOPSIS
        Modern WPF GUI for Exchange RBAC Manager - wireframe-derived layout.
    .DESCRIPTION
        Sidebar (8 sections) + content head + toolbar + data area + action bar + status bar.
        Section 7 is the embedded RBAC Visualizer (hub-and-spoke).
        Section 8 is the Audit Log fed by Search-AdminAuditLog.

        Write actions: New / Edit / Copy / Delete on Role Groups (Roles,
        Assignments and Scopes are wired in subsequent commits). Default
        mode is dry-run (cmdlet preview only); user toggles to live mode
        in the toolbar, which gates writes behind a confirm prompt.
    #>
    [CmdletBinding()]
    param()

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms

    # ---------------- XAML ----------------
    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Exchange RBAC Manager" Height="780" Width="1280"
        WindowStartupLocation="CenterScreen" FontFamily="Segoe UI">
  <Window.Resources>
    <SolidColorBrush x:Key="Accent"      Color="#0078D4"/>
    <SolidColorBrush x:Key="AccentDark"  Color="#106EBE"/>
    <SolidColorBrush x:Key="AccentSoft"  Color="#DEECF9"/>
    <SolidColorBrush x:Key="ContentBg"   Color="#FFFFFF"/>
    <SolidColorBrush x:Key="ToolbarBg"   Color="#FAF9F8"/>
    <SolidColorBrush x:Key="StatusBg"    Color="#F3F2F1"/>
    <SolidColorBrush x:Key="BorderC"     Color="#E1DFDD"/>
    <SolidColorBrush x:Key="Subdued"     Color="#605E5C"/>
    <SolidColorBrush x:Key="Ink"         Color="#201F1E"/>

    <Style x:Key="NavButton" TargetType="ToggleButton">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Height" Value="40"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ToggleButton">
            <Border x:Name="bd" Background="{TemplateBinding Background}" Padding="18,0">
              <Grid>
                <TextBlock x:Name="lbl" Text="{TemplateBinding Content}"
                           Foreground="White" VerticalAlignment="Center"/>
                <Border x:Name="active" HorizontalAlignment="Left" Width="3" Background="White" Opacity="0" Margin="-18,0,0,0"/>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#106EBE"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="bd" Property="Background" Value="White"/>
                <Setter TargetName="lbl" Property="Foreground" Value="#0078D4"/>
                <Setter TargetName="active" Property="Opacity" Value="1"/>
                <Setter TargetName="active" Property="Background" Value="#0078D4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="ActionBtn" TargetType="Button">
      <Setter Property="Padding" Value="14,0"/>
      <Setter Property="Margin"  Value="4,0"/>
      <Setter Property="Height"  Value="32"/>
      <Setter Property="Background" Value="White"/>
      <Setter Property="Foreground" Value="#201F1E"/>
      <Setter Property="BorderBrush" Value="#C8C6C4"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="2" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#F3F2F1"/></Trigger>
              <Trigger Property="IsPressed"   Value="True"><Setter TargetName="bd" Property="Background" Value="#EDEBE9"/></Trigger>
              <Trigger Property="IsEnabled"   Value="False">
                <Setter TargetName="bd" Property="Opacity" Value="0.55"/>
                <Setter Property="Cursor" Value="No"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="PrimaryBtn" TargetType="Button" BasedOn="{StaticResource ActionBtn}">
      <Setter Property="Background"  Value="#0078D4"/>
      <Setter Property="Foreground"  Value="White"/>
      <Setter Property="BorderBrush" Value="#0078D4"/>
    </Style>
    <Style x:Key="WarnBtn" TargetType="Button" BasedOn="{StaticResource ActionBtn}">
      <Setter Property="Foreground"  Value="#A4262C"/>
      <Setter Property="BorderBrush" Value="#F1B0B0"/>
    </Style>

    <Style TargetType="DataGrid">
      <Setter Property="Background" Value="White"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="GridLinesVisibility" Value="Horizontal"/>
      <Setter Property="HorizontalGridLinesBrush" Value="#F3F2F1"/>
      <Setter Property="HeadersVisibility" Value="Column"/>
      <Setter Property="RowHeight" Value="34"/>
      <Setter Property="AutoGenerateColumns" Value="False"/>
      <Setter Property="IsReadOnly" Value="True"/>
      <Setter Property="SelectionMode" Value="Extended"/>
      <Setter Property="CanUserAddRows" Value="False"/>
      <Setter Property="AlternatingRowBackground" Value="#FAF9F8"/>
    </Style>
    <Style TargetType="DataGridColumnHeader">
      <Setter Property="Background" Value="#FAF9F8"/>
      <Setter Property="Foreground" Value="#605E5C"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="Padding" Value="12,0"/>
      <Setter Property="BorderBrush" Value="#E1DFDD"/>
      <Setter Property="BorderThickness" Value="0,0,1,1"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
    </Style>
    <Style TargetType="DataGridRow">
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="#DEECF9"/>
          <Setter Property="Foreground" Value="#201F1E"/>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="240"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- Sidebar -->
    <Border Grid.Column="0" Background="{StaticResource Accent}">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="Exchange RBAC" Foreground="White"
                   FontSize="20" FontWeight="SemiBold" Margin="16,18,16,12"/>

        <Border Grid.Row="1" Margin="12,0,12,14" Padding="10" CornerRadius="3" BorderThickness="1">
          <Border.Background><SolidColorBrush Color="White" Opacity="0.12"/></Border.Background>
          <Border.BorderBrush><SolidColorBrush Color="White" Opacity="0.4"/></Border.BorderBrush>
          <StackPanel>
            <TextBlock Text="TENANT" Foreground="White" FontFamily="Consolas" FontSize="10" Opacity="0.85"/>
            <TextBlock x:Name="TenantName" Text="Not connected" Foreground="White" FontSize="13"
                       Margin="0,2,0,4" TextTrimming="CharacterEllipsis"/>
            <StackPanel Orientation="Horizontal">
              <Ellipse x:Name="ConnPulse" Width="8" Height="8" Fill="#E6C4C4" VerticalAlignment="Center"/>
              <TextBlock x:Name="ConnStatus" Text="disconnected" Foreground="White"
                         FontFamily="Consolas" FontSize="11" Margin="6,0,0,0"/>
            </StackPanel>
            <Button x:Name="BtnConnect" Content="Connect to Exchange Online" Margin="0,10,0,0" Height="30"
                    Background="White" Foreground="#0078D4" BorderThickness="0" FontWeight="SemiBold" Cursor="Hand"/>
            <Button x:Name="BtnDisconnect" Content="Disconnect" Margin="0,4,0,0" Height="28"
                    Background="Transparent" Foreground="White" BorderBrush="White" BorderThickness="1"
                    Cursor="Hand" Visibility="Collapsed"/>
          </StackPanel>
        </Border>

        <StackPanel Grid.Row="2" Margin="6,0,6,0">
          <ToggleButton x:Name="NavRoleGroups"  Style="{StaticResource NavButton}" Content="Role Groups"/>
          <ToggleButton x:Name="NavRoles"       Style="{StaticResource NavButton}" Content="Roles"/>
          <ToggleButton x:Name="NavAssignments" Style="{StaticResource NavButton}" Content="Role Assignments"/>
          <ToggleButton x:Name="NavScopes"      Style="{StaticResource NavButton}" Content="Scopes"/>
          <ToggleButton x:Name="NavUserRights"  Style="{StaticResource NavButton}" Content="User Rights"/>
          <ToggleButton x:Name="NavCommands"    Style="{StaticResource NavButton}" Content="Command Lookup"/>
          <ToggleButton x:Name="NavVisualizer"  Style="{StaticResource NavButton}" Content="RBAC Visualizer"/>
          <ToggleButton x:Name="NavAudit"       Style="{StaticResource NavButton}" Content="Audit Log"/>
        </StackPanel>

        <Border Grid.Row="3" Padding="14,10" BorderThickness="0,1,0,0">
          <Border.BorderBrush><SolidColorBrush Color="White" Opacity="0.25"/></Border.BorderBrush>
          <TextBlock x:Name="VersionLabel" Foreground="White" Opacity="0.7"
                     FontFamily="Consolas" FontSize="11" Text="v0.1.0"/>
        </Border>
      </Grid>
    </Border>

    <!-- Main content -->
    <Grid Grid.Column="1" Background="White">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- Content head -->
      <Border Grid.Row="0" Padding="24,16,24,12" BorderBrush="{StaticResource BorderC}" BorderThickness="0,0,0,1">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel Grid.Column="0">
            <TextBlock x:Name="Crumbs" FontFamily="Consolas" FontSize="11" Foreground="{StaticResource Subdued}"/>
            <TextBlock x:Name="ViewTitle" FontSize="22" FontWeight="SemiBold" Margin="0,2,0,0" Foreground="{StaticResource Ink}"/>
            <TextBlock x:Name="ViewDesc"  FontSize="13" Foreground="{StaticResource Subdued}" Margin="0,2,0,0" TextWrapping="Wrap"/>
          </StackPanel>
          <!-- Mode badge: reflects current write mode.
               Dry-run (default, safe): write actions only print the equivalent cmdlet.
               Write: actions go through to Exchange Online after a confirm prompt. -->
          <Border x:Name="ModeBadge" Grid.Column="1" VerticalAlignment="Top" Padding="8,3" CornerRadius="11"
                  Background="#FFF4CE" BorderBrush="#D29200" BorderThickness="1"
                  ToolTip="Dry-run: previews cmdlets without touching the tenant. Toggle in the toolbar.">
            <TextBlock x:Name="ModeBadgeText" Text="DRY-RUN · v2" FontFamily="Consolas" FontSize="10"
                       FontWeight="SemiBold" Foreground="#7A4F00"/>
          </Border>
        </Grid>
      </Border>

      <!-- Toolbar -->
      <Border Grid.Row="1" Background="{StaticResource ToolbarBg}" Padding="24,10"
              BorderBrush="{StaticResource BorderC}" BorderThickness="0,0,0,1">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <Border Grid.Column="0" BorderBrush="#C8C6C4" BorderThickness="1" CornerRadius="2"
                  Background="White" Width="280" Height="30">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <TextBlock Grid.Column="0" Text="⌕" Margin="8,0" VerticalAlignment="Center" Foreground="#605E5C"/>
              <TextBox x:Name="SearchBox" Grid.Column="1" BorderThickness="0"
                       VerticalContentAlignment="Center" Background="Transparent"/>
            </Grid>
          </Border>
          <ItemsControl x:Name="ChipsHost" Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center">
            <ItemsControl.ItemsPanel>
              <ItemsPanelTemplate><StackPanel Orientation="Horizontal"/></ItemsPanelTemplate>
            </ItemsControl.ItemsPanel>
          </ItemsControl>
          <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="0,0,8,0">
            <Button x:Name="BtnDryRun" Content="Dry-run: on" Style="{StaticResource ActionBtn}" Margin="0,0,6,0"
                    ToolTip="Toggle between dry-run preview and live execution"/>
            <Button x:Name="BtnRefresh" Content="Refresh" Style="{StaticResource ActionBtn}"/>
          </StackPanel>
          <TextBlock x:Name="ItemCount" Grid.Column="3" FontFamily="Consolas" FontSize="11"
                     Foreground="{StaticResource Subdued}" VerticalAlignment="Center" Text="0 items"/>
        </Grid>
      </Border>

      <!-- Content area: table OR visualizer + slide-out details panel -->
      <Grid Grid.Row="2">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition x:Name="DetailsCol" Width="0"/>
        </Grid.ColumnDefinitions>
        <Grid Grid.Column="0">
          <DataGrid x:Name="MainGrid"/>
        <Grid>
          <Grid x:Name="VizHost" Visibility="Collapsed" Background="#FAFAFA">
            <ScrollViewer x:Name="VizScroll" HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Hidden">
              <Canvas x:Name="VizCanvas" Background="#FAFAFA" ClipToBounds="True"/>
            </ScrollViewer>
            <TextBlock x:Name="VizPlaceholder" Text="Pick an assignment in the toolbar to visualize."
                       Foreground="#605E5C" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="14"/>
          </Grid>
        </Grid>
        </Grid>
        <Border x:Name="DetailsPanel" Grid.Column="1" Background="#FAF9F8"
                BorderBrush="{StaticResource BorderC}" BorderThickness="1,0,0,0" Visibility="Collapsed">
          <Grid>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <Grid Grid.Row="0" Margin="16,14,8,10">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <StackPanel Grid.Column="0">
                <TextBlock Text="DETAILS" FontFamily="Consolas" FontSize="10" Foreground="{StaticResource Subdued}"/>
                <TextBlock x:Name="DetailsTitle" FontSize="16" FontWeight="SemiBold"
                           Foreground="{StaticResource Ink}" TextTrimming="CharacterEllipsis" Margin="0,2,0,0"/>
              </StackPanel>
              <Button x:Name="BtnDetailsClose" Grid.Column="1" Content="✕" Width="28" Height="28"
                      Background="Transparent" BorderThickness="0" Foreground="#605E5C" Cursor="Hand" FontSize="14"/>
            </Grid>
            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="16,0,16,16">
              <ItemsControl x:Name="DetailsList">
                <ItemsControl.ItemTemplate>
                  <DataTemplate>
                    <StackPanel Margin="0,0,0,12">
                      <TextBlock Text="{Binding Key}" FontFamily="Consolas" FontSize="10"
                                 Foreground="#605E5C" TextTrimming="CharacterEllipsis"/>
                      <TextBlock Text="{Binding Value}" FontSize="12" Foreground="#201F1E"
                                 TextWrapping="Wrap" Margin="0,2,0,0"/>
                    </StackPanel>
                  </DataTemplate>
                </ItemsControl.ItemTemplate>
              </ItemsControl>
            </ScrollViewer>
          </Grid>
        </Border>
      </Grid>

      <!-- Action bar -->
      <Border Grid.Row="3" Background="{StaticResource ToolbarBg}" Padding="24,10"
              BorderBrush="{StaticResource BorderC}" BorderThickness="0,1,0,0">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <TextBlock x:Name="SelectionCount" Grid.Column="0" Text="0 selected"
                     FontFamily="Consolas" FontSize="11" Foreground="{StaticResource Subdued}"
                     VerticalAlignment="Center"/>
          <ItemsControl x:Name="ActionsHost" Grid.Column="1">
            <ItemsControl.ItemsPanel>
              <ItemsPanelTemplate><StackPanel Orientation="Horizontal"/></ItemsPanelTemplate>
            </ItemsControl.ItemsPanel>
          </ItemsControl>
        </Grid>
      </Border>

      <!-- Status bar -->
      <Border Grid.Row="4" Background="{StaticResource StatusBg}"
              BorderBrush="{StaticResource BorderC}" BorderThickness="0,1,0,0">
        <Grid Height="26">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel Grid.Column="0" Orientation="Horizontal" Margin="12,0">
            <TextBlock x:Name="StatusDot" Foreground="#107C10" Text="●" VerticalAlignment="Center"/>
            <TextBlock x:Name="StatusText" Margin="6,0,0,0" Text="Ready" VerticalAlignment="Center"
                       FontFamily="Consolas" FontSize="11" Foreground="#605E5C"/>
            <TextBlock x:Name="StatusSep" Margin="12,0" Text="|" Foreground="#A19F9D" VerticalAlignment="Center"/>
            <TextBlock x:Name="StatusItems" VerticalAlignment="Center" FontFamily="Consolas" FontSize="11" Foreground="#605E5C"/>
          </StackPanel>
          <TextBlock x:Name="StatusVersion" Grid.Column="1" Margin="0,0,12,0" VerticalAlignment="Center"
                     FontFamily="Consolas" FontSize="11" Foreground="#A19F9D"/>
        </Grid>
      </Border>
    </Grid>
  </Grid>
</Window>
'@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)

    # ---------------- App icon (generated at runtime: hub-and-spoke glyph) ----------------
    try {
        $size = 32
        $dv = [System.Windows.Media.DrawingVisual]::new()
        $ctx = $dv.RenderOpen()
        # Background rounded square (Microsoft blue)
        $bg = [System.Windows.Media.RectangleGeometry]::new(
            [System.Windows.Rect]::new(0, 0, $size, $size), 6, 6)
        $ctx.DrawGeometry([System.Windows.Media.Brushes]::Transparent, $null, $bg)
        $ctx.DrawRectangle(
            [System.Windows.Media.SolidColorBrush]::new(
                [System.Windows.Media.ColorConverter]::ConvertFromString('#0078D4')),
            $null,
            [System.Windows.Rect]::new(0, 0, $size, $size))
        $cx = 16; $cy = 16
        $hubR = 4; $spokeR = 3
        $pen = [System.Windows.Media.Pen]::new(
            [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Colors]::White), 1.4)
        $spokes = @(@(6, 7), @(26, 7), @(16, 26))
        foreach ($p in $spokes) {
            $ctx.DrawLine($pen, [System.Windows.Point]::new($cx, $cy),
                                 [System.Windows.Point]::new($p[0], $p[1]))
        }
        $ctx.DrawEllipse(
            [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Colors]::White),
            $null, [System.Windows.Point]::new($cx, $cy), $hubR, $hubR)
        foreach ($p in $spokes) {
            $ctx.DrawEllipse(
                [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Colors]::White),
                $null, [System.Windows.Point]::new($p[0], $p[1]), $spokeR, $spokeR)
        }
        $ctx.Close()
        $rtb = [System.Windows.Media.Imaging.RenderTargetBitmap]::new(
            $size, $size, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
        $rtb.Render($dv)
        $rtb.Freeze()
        $window.Icon = $rtb
    }
    catch { Write-Verbose "Icon generation skipped: $_" }

    # ---------------- UI lookup helpers ----------------
    $UI = @{}
    foreach ($n in @(
            'TenantName','ConnPulse','ConnStatus','BtnConnect','BtnDisconnect','VersionLabel',
            'NavRoleGroups','NavRoles','NavAssignments','NavScopes','NavUserRights','NavCommands','NavVisualizer','NavAudit',
            'Crumbs','ViewTitle','ViewDesc','SearchBox','ChipsHost','BtnRefresh','BtnDryRun',
            'ModeBadge','ModeBadgeText','ItemCount',
            'MainGrid','VizHost','VizCanvas','VizScroll','VizPlaceholder',
            'DetailsCol','DetailsPanel','DetailsTitle','DetailsList','BtnDetailsClose',
            'SelectionCount','ActionsHost',
            'StatusDot','StatusText','StatusSep','StatusItems','StatusVersion'
        )) { $UI[$n] = $window.FindName($n) }

    $script:CurrentView   = $null
    $script:Cache         = @{}        # cached collections per view
    $script:ActiveChip    = @{}        # active chip label per view
    $script:CurrentChips  = @()        # chip labels for the current view
    $script:VizAssignment = $null      # currently visualized assignment

    # Module versions (sidebar = this module, status bar = ExchangeOnlineManagement)
    $modVer = (Get-Module -Name 'RBACExchangeManager' -ListAvailable | Select-Object -First 1).Version
    $verStr = if ($modVer) { "v$($modVer.ToString())" } else { 'v0.1.0' }
    $UI.VersionLabel.Text = "RBACExchangeManager $verStr"

    $exoVer = (Get-Module -Name 'ExchangeOnlineManagement' -ListAvailable |
               Sort-Object Version -Descending | Select-Object -First 1).Version
    $UI.StatusVersion.Text = if ($exoVer) { "ExchangeOnlineManagement v$exoVer" } else { 'ExchangeOnlineManagement n/a' }

    # ---------------- Status helpers ----------------
    function Set-Status {
        param([string]$Message, [ValidateSet('info','warn','error','ok')]$Level = 'info')
        $UI.StatusText.Text = $Message
        switch ($Level) {
            'error' { $UI.StatusDot.Foreground = '#A4262C' }
            'warn'  { $UI.StatusDot.Foreground = '#D29200' }
            'ok'    { $UI.StatusDot.Foreground = '#107C10' }
            default { $UI.StatusDot.Foreground = '#107C10' }
        }
    }

    function Update-ConnectionUI {
        if (Test-RBACExchangeConnection) {
            $UI.ConnStatus.Text = 'connected'
            $UI.ConnPulse.Fill  = '#9BE39B'
            $UI.BtnConnect.Visibility    = 'Collapsed'
            $UI.BtnDisconnect.Visibility = 'Visible'
            try {
                $info = Get-ConnectionInformation -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($info) {
                    $UI.TenantName.Text = if ($info.TenantId) { "$($info.Organization)" } else { 'Exchange Online' }
                }
            } catch { }
        }
        else {
            $UI.ConnStatus.Text = 'disconnected'
            $UI.ConnPulse.Fill  = '#E6C4C4'
            $UI.TenantName.Text = 'Not connected'
            $UI.BtnConnect.Visibility    = 'Visible'
            $UI.BtnDisconnect.Visibility = 'Collapsed'
        }
    }

    # ---------------- Chip / Action factories ----------------
    function New-Chip {
        param([string]$Label, [switch]$On)
        $b = [System.Windows.Controls.Border]::new()
        $b.CornerRadius = '11'; $b.BorderThickness = '1'; $b.Margin = '0,0,6,0'; $b.Padding = '10,4'; $b.Height = 22
        $b.VerticalAlignment = 'Center'
        $b.Cursor = [System.Windows.Input.Cursors]::Hand
        if ($On) { $b.Background = '#0078D4'; $b.BorderBrush = '#0078D4' }
        else     { $b.Background = 'White';   $b.BorderBrush = '#C8C6C4' }
        $t = [System.Windows.Controls.TextBlock]::new()
        $t.Text = $Label; $t.FontFamily = 'Consolas'; $t.FontSize = 11
        $t.Foreground = $(if ($On) { 'White' } else { '#323130' })
        $t.VerticalAlignment = 'Center'
        $t.IsHitTestVisible = $false   # so the chip border owns the hit
        $b.Child = $t
        # Stash the chip label on Tag for the click handler.
        $b.Tag = $Label
        $b.Add_MouseLeftButtonDown({
            $label = $args[0].Tag
            if ($label) { Switch-Chip -Label $label }
        })
        return $b
    }

    function Set-Chips {
        param([string[]]$Labels, [string]$ActiveLabel)
        $UI.ChipsHost.Items.Clear()
        $script:CurrentChips = $Labels
        if (-not $ActiveLabel -and $Labels.Count -gt 0) { $ActiveLabel = $Labels[0] }
        $script:ActiveChip[$script:CurrentView] = $ActiveLabel
        foreach ($lbl in $Labels) {
            $null = $UI.ChipsHost.Items.Add( (New-Chip -Label $lbl -On:($lbl -eq $ActiveLabel)) )
        }
    }

    function Switch-Chip {
        param([string]$Label)
        if (-not $script:CurrentView) { return }
        if (-not $script:CurrentChips -or $script:CurrentChips -notcontains $Label) { return }
        $script:ActiveChip[$script:CurrentView] = $Label
        # Re-draw chips with the new active state
        $UI.ChipsHost.Items.Clear()
        foreach ($lbl in $script:CurrentChips) {
            $null = $UI.ChipsHost.Items.Add( (New-Chip -Label $lbl -On:($lbl -eq $Label)) )
        }
        Apply-Filters
    }

    function New-ActionButton {
        param([string]$Label, [string]$Style = 'ActionBtn', [scriptblock]$OnClick)
        $b = [System.Windows.Controls.Button]::new()
        $b.Content = $Label
        $b.Style = $window.FindResource($Style)
        if ($OnClick) {
            # Stash the scriptblock on the button; the click handler reads it from the sender.
            # Read sender via $args[0] (param-binding through delegate is unreliable in PS 5.1).
            $b.Tag = $OnClick
            $b.Add_Click({
                $sb = $args[0].Tag
                if ($sb -is [scriptblock]) { & $sb }
            })
        }
        return $b
    }

    function Set-Actions {
        param([array]$Buttons)
        $UI.ActionsHost.Items.Clear()
        foreach ($b in $Buttons) { $null = $UI.ActionsHost.Items.Add($b) }
    }

    # ---------------- Write-mode helpers ----------------
    $script:DryRun = $true   # default: safe; user toggles to live mode in the toolbar

    function Update-ModeBadge {
        if ($script:DryRun) {
            $UI.ModeBadgeText.Text = 'DRY-RUN | v2'
            $UI.ModeBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FFF4CE')
            $UI.ModeBadge.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#D29200')
            $UI.ModeBadgeText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#7A4F00')
            $UI.ModeBadge.ToolTip = 'Dry-run: previews the cmdlets without touching the tenant. Toggle in the toolbar.'
            $UI.BtnDryRun.Content = 'Dry-run: on'
        }
        else {
            $UI.ModeBadgeText.Text = 'WRITE | v2'
            $UI.ModeBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FDE7E9')
            $UI.ModeBadge.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#A4262C')
            $UI.ModeBadgeText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#A4262C')
            $UI.ModeBadge.ToolTip = 'Write mode: actions go through to Exchange Online after a confirm prompt.'
            $UI.BtnDryRun.Content = 'Dry-run: off'
        }
    }

    function Toggle-DryRun {
        if (-not $script:DryRun) {
            # Switching FROM live TO dry-run is always fine. Switching INTO live needs a heads-up.
            $script:DryRun = $true
            Update-ModeBadge
            Set-Status 'Dry-run mode is on. Write actions will preview only.' 'info'
            return
        }
        $msg = "Switch to live WRITE mode?`n`nWrite actions will execute against the connected tenant after a per-action confirm."
        $r = [System.Windows.MessageBox]::Show(
                $msg, 'Switch to write mode',
                [System.Windows.MessageBoxButton]::OKCancel,
                [System.Windows.MessageBoxImage]::Warning)
        if ($r -eq [System.Windows.MessageBoxResult]::OK) {
            $script:DryRun = $false
            Update-ModeBadge
            Set-Status 'Write mode is on. Actions will hit the tenant.' 'warn'
        }
    }

    function Confirm-WriteAction {
        param(
            [Parameter(Mandatory)] [string]$Title,
            [Parameter(Mandatory)] [string]$Message
        )
        $r = [System.Windows.MessageBox]::Show(
                $Message, $Title,
                [System.Windows.MessageBoxButton]::OKCancel,
                [System.Windows.MessageBoxImage]::Question)
        return ($r -eq [System.Windows.MessageBoxResult]::OK)
    }

    function Show-CmdletPreview {
        param(
            [Parameter(Mandatory)] [string]$Title,
            [Parameter(Mandatory)] [string]$Cmdlet
        )
        $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="" Width="640" Height="320" WindowStartupLocation="CenterOwner"
        ResizeMode="CanResize" SizeToContent="Manual">
  <Grid Margin="14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <TextBlock Grid.Row="0" Text="Equivalent PowerShell cmdlet (dry-run, not executed)"
               FontWeight="SemiBold" Margin="0,0,0,6"/>
    <TextBox x:Name="CmdletText" Grid.Row="1" AcceptsReturn="True" TextWrapping="Wrap"
             FontFamily="Consolas" FontSize="12" IsReadOnly="True"
             VerticalScrollBarVisibility="Auto"/>
    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,8,0,0">
      <Button x:Name="BtnCopy" Content="Copy" Width="90" Height="28" Margin="0,0,8,0"/>
      <Button x:Name="BtnClose" Content="Close" Width="90" Height="28" IsDefault="True" IsCancel="True"/>
    </StackPanel>
  </Grid>
</Window>
'@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $w = [System.Windows.Markup.XamlReader]::Load($reader)
        $w.Title = $Title
        $w.Owner = $window
        $tb   = $w.FindName('CmdletText')
        $cp   = $w.FindName('BtnCopy')
        $cl   = $w.FindName('BtnClose')
        $tb.Text = $Cmdlet
        $cp.Add_Click({ try { [System.Windows.Clipboard]::SetText($tb.Text); Set-Status 'Cmdlet copied to clipboard.' 'ok' } catch {} })
        $cl.Add_Click({ $w.Close() })
        $null = $w.ShowDialog()
    }

    function Show-RoleGroupForm {
        param(
            [string]$Title              = 'New Role Group',
            [string]$DefaultName        = '',
            [string]$DefaultDescription = '',
            [string[]]$DefaultRoles     = @(),
            [string[]]$DefaultMembers   = @(),
            [bool]$NameReadOnly         = $false,
            [bool]$ShowIncludeMembers   = $false,
            [bool]$DefaultIncludeMembers= $false,
            [string]$NameLabel          = 'Name'
        )
        $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="" Width="560" Height="620" WindowStartupLocation="CenterOwner"
        ResizeMode="CanResize">
  <Grid Margin="14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/><RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/><RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <TextBlock x:Name="LblName" Grid.Row="0" Text="Name" FontWeight="SemiBold"/>
    <TextBox  x:Name="TxtName" Grid.Row="1" Height="26" Margin="0,4,0,10"/>
    <TextBlock Grid.Row="2" Text="Description" FontWeight="SemiBold"/>
    <TextBox  x:Name="TxtDesc" Grid.Row="3" Height="48" Margin="0,4,0,10"
              AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
    <TextBlock Grid.Row="4" Text="Roles (one per line)" FontWeight="SemiBold" VerticalAlignment="Top"/>
    <TextBox  x:Name="TxtRoles" Grid.Row="4" Margin="0,18,0,10"
              AcceptsReturn="True" TextWrapping="NoWrap"
              VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
              FontFamily="Consolas"/>
    <TextBlock Grid.Row="5" Text="Members (one per line, UPN or alias)" FontWeight="SemiBold"/>
    <TextBox  x:Name="TxtMembers" Grid.Row="6" Margin="0,4,0,10"
              AcceptsReturn="True" TextWrapping="NoWrap"
              VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
              FontFamily="Consolas"/>
    <CheckBox x:Name="ChkIncludeMembers" Grid.Row="7" Content="Include members from source"
              Margin="0,0,0,10" Visibility="Collapsed"/>
    <StackPanel Grid.Row="8" Orientation="Horizontal" HorizontalAlignment="Right">
      <Button x:Name="BtnOk"     Content="OK"     Width="90" Height="28" Margin="0,0,8,0" IsDefault="True"/>
      <Button x:Name="BtnCancel" Content="Cancel" Width="90" Height="28" IsCancel="True"/>
    </StackPanel>
  </Grid>
</Window>
'@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $w = [System.Windows.Markup.XamlReader]::Load($reader)
        $w.Title = $Title
        $w.Owner = $window

        $UIDlg = @{}
        foreach ($n in @('LblName','TxtName','TxtDesc','TxtRoles','TxtMembers','ChkIncludeMembers','BtnOk','BtnCancel')) {
            $UIDlg[$n] = $w.FindName($n)
        }
        $UIDlg.LblName.Text  = $NameLabel
        $UIDlg.TxtName.Text  = $DefaultName
        $UIDlg.TxtName.IsReadOnly = $NameReadOnly
        $UIDlg.TxtDesc.Text  = $DefaultDescription
        $UIDlg.TxtRoles.Text   = ($DefaultRoles   -join "`r`n")
        $UIDlg.TxtMembers.Text = ($DefaultMembers -join "`r`n")
        if ($ShowIncludeMembers) {
            $UIDlg.ChkIncludeMembers.Visibility = 'Visible'
            $UIDlg.ChkIncludeMembers.IsChecked  = $DefaultIncludeMembers
        }

        $script:_FormResult = $null
        $UIDlg.BtnOk.Add_Click({
            $name = "$($UIDlg.TxtName.Text)".Trim()
            if (-not $name) {
                [System.Windows.MessageBox]::Show('Name is required.', 'Missing field',
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return
            }
            $rolesArr = @($UIDlg.TxtRoles.Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $memArr   = @($UIDlg.TxtMembers.Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $script:_FormResult = [pscustomobject]@{
                Name           = $name
                Description    = "$($UIDlg.TxtDesc.Text)".Trim()
                Roles          = $rolesArr
                Members        = $memArr
                IncludeMembers = [bool]$UIDlg.ChkIncludeMembers.IsChecked
            }
            $w.DialogResult = $true
            $w.Close()
        })
        $UIDlg.BtnCancel.Add_Click({ $w.DialogResult = $false; $w.Close() })

        $ok = $w.ShowDialog()
        if ($ok) { return $script:_FormResult }
        return $null
    }

    function Handle-WriteResult {
        param(
            [Parameter(Mandatory)] $Result,
            [Parameter(Mandatory)] [string]$SuccessMsg,
            [Parameter(Mandatory)] [string]$DryRunTitle
        )
        if ($null -eq $Result) { return }
        if ($Result -is [System.Array]) {
            # Set-RBACRoleGroup returns an array of step results
            $errs = @($Result | Where-Object { $_.Error })
            if ($errs.Count -gt 0) {
                Set-Status "Error: $($errs[0].Error.Exception.Message)" 'error'
                return
            }
            $previewLines = @($Result | ForEach-Object { $_.Preview } | Where-Object { $_ })
            if ($script:DryRun) {
                Show-CmdletPreview -Title $DryRunTitle -Cmdlet ($previewLines -join "`r`n")
                Set-Status 'Dry-run: cmdlet preview shown. Nothing executed.' 'info'
            }
            else {
                Set-Status $SuccessMsg 'ok'
            }
            return
        }
        if ($Result.Error) {
            Set-Status "Error: $($Result.Error.Exception.Message)" 'error'
            return
        }
        if ($script:DryRun) {
            Show-CmdletPreview -Title $DryRunTitle -Cmdlet $Result.Preview
            Set-Status 'Dry-run: cmdlet preview shown. Nothing executed.' 'info'
        }
        else {
            Set-Status $SuccessMsg 'ok'
        }
    }

    # ---------------- View descriptors ----------------
    $script:Views = @{
        RoleGroups = @{
            Crumbs = 'RBAC ▸ Role Groups'
            Title  = 'Role Groups'
            Desc   = 'Universal Security Groups that bundle roles, members and scopes.'
            Chips  = @('all','built-in','custom')
            Columns = @(
                @{ Header='Name';        Path='Name';        Width=240 }
                @{ Header='Description'; Path='Description'; Width='*' }
                @{ Header='Members';     Path='MemberCount'; Width=90 }
                @{ Header='Roles';       Path='RoleCount';   Width=80 }
            )
        }
        Roles = @{
            Crumbs = 'RBAC ▸ Management Roles'
            Title  = 'Roles'
            Desc   = 'Containers of cmdlets and parameters that grant capabilities.'
            Chips  = @('all','built-in','custom','unassigned')
            Columns = @(
                @{ Header='Role Name';   Path='Name';        Width=240 }
                @{ Header='Type';        Path='RoleType';    Width=140 }
                @{ Header='Origin';      Path='Origin';      Width=100 }
                @{ Header='Parent Role'; Path='Parent';      Width=180 }
                @{ Header='Description'; Path='Description'; Width='*' }
            )
        }
        Assignments = @{
            Crumbs = 'RBAC ▸ Role Assignments'
            Title  = 'Role Assignments'
            Desc   = 'Bindings of Role + Assignee + Scope.'
            Chips  = @('all','enabled','disabled')
            Columns = @(
                @{ Header='Assignment Name'; Path='Name';                Width=260 }
                @{ Header='Role';            Path='Role';                Width=200 }
                @{ Header='Assignee';        Path='RoleAssignee';        Width=180 }
                @{ Header='Type';            Path='RoleAssigneeType';    Width=100 }
                @{ Header='Read Scope';      Path='RecipientReadScope';  Width='*' }
                @{ Header='Write Scope';     Path='RecipientWriteScope'; Width='*' }
            )
        }
        Scopes = @{
            Crumbs = 'RBAC ▸ Management Scopes'
            Title  = 'Scopes'
            Desc   = 'Where a role applies - recipient or server filters.'
            Chips  = @('all','implicit','custom','recipient','server')
            Columns = @(
                @{ Header='Scope Name';       Path='Name';                  Width=220 }
                @{ Header='Type';             Path='ScopeRestrictionType';  Width=140 }
                @{ Header='OU';               Path='RecipientRoot';         Width=200 }
                @{ Header='Recipient Filter'; Path='FilterSummary';         Width='*' }
            )
        }
        UserRights = @{
            Crumbs = 'RBAC ▸ User Rights'
            Title  = 'User Rights'
            Desc   = 'Effective permissions for a user - what they can run, where.'
            Chips  = @('expand role groups','show scopes')
            Columns = @(
                @{ Header='User';        Path='User';        Width=240 }
                @{ Header='Role';        Path='Role';        Width=220 }
                @{ Header='Granted Via'; Path='Via';         Width=200 }
                @{ Header='Read Scope';  Path='ReadScope';   Width=180 }
                @{ Header='Write Scope'; Path='WriteScope';  Width='*' }
            )
        }
        Commands = @{
            Crumbs = 'RBAC ▸ Command Lookup'
            Title  = 'Command Lookup'
            Desc   = 'Reverse lookup: which roles grant a given cmdlet?'
            Chips  = @('all','built-in','custom')
            Columns = @(
                @{ Header='Role';        Path='RoleName';    Width=240 }
                @{ Header='Type';        Path='RoleType';    Width=140 }
                @{ Header='Origin';      Path='Origin';      Width=120 }
                @{ Header='Description'; Path='Description'; Width='*' }
            )
        }
        Visualizer = @{
            Crumbs = 'RBAC ▸ Visualizer'
            Title  = 'RBAC Visualizer · hub-and-spoke'
            Desc   = 'One assignment in the centre, three spokes out: Role · Assignee · Scope.'
            Chips  = @()
            Columns = @()
        }
        Audit = @{
            Crumbs = 'RBAC ▸ Audit Log'
            Title  = 'Audit Log'
            Desc   = 'Recent RBAC changes from Search-AdminAuditLog.'
            Chips  = @('last 7 days','last 30 days','last 90 days')
            Columns = @(
                @{ Header='Timestamp';   Path='Timestamp';  Width=160 }
                @{ Header='Caller';      Path='Caller';     Width=200 }
                @{ Header='Cmdlet';      Path='Cmdlet';     Width=220 }
                @{ Header='Object';      Path='Object';     Width=220 }
                @{ Header='Parameters';  Path='Parameters'; Width='*' }
            )
        }
    }

    # ---------------- Grid configuration ----------------
    function Set-GridColumns {
        param([array]$Columns)
        $UI.MainGrid.Columns.Clear()
        foreach ($c in $Columns) {
            $col = [System.Windows.Controls.DataGridTextColumn]::new()
            $col.Header  = $c.Header
            $col.Binding = [System.Windows.Data.Binding]::new($c.Path)
            if ($c.Width -eq '*') {
                $col.Width = [System.Windows.Controls.DataGridLength]::new(1, [System.Windows.Controls.DataGridLengthUnitType]::Star)
            }
            else {
                $col.Width = [System.Windows.Controls.DataGridLength]::new([double]$c.Width)
            }
            # Tooltip showing full cell value on hover (so truncated content stays readable)
            $eStyle = [System.Windows.Style]::new([System.Windows.Controls.TextBlock])
            $tt = [System.Windows.Data.Binding]::new($c.Path)
            $eStyle.Setters.Add([System.Windows.Setter]::new(
                [System.Windows.Controls.TextBlock]::TextTrimmingProperty,
                [System.Windows.TextTrimming]::CharacterEllipsis))
            $eStyle.Setters.Add([System.Windows.Setter]::new(
                [System.Windows.Controls.ToolTipService]::ToolTipProperty, $tt))
            $col.ElementStyle = $eStyle
            $null = $UI.MainGrid.Columns.Add($col)
        }
    }

    # ---------------- Details panel ----------------
    function Show-Details {
        param($Item)
        if (-not $Item) { Hide-Details; return }
        $title = $Item.Name
        if (-not $title) { $title = $Item.Cmdlet }
        if (-not $title) { $title = $Item.User }
        if (-not $title) { $title = $Item.RoleName }
        if (-not $title) { $title = '(item)' }
        $UI.DetailsTitle.Text = "$title"

        $rows = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
        foreach ($p in $Item.PSObject.Properties) {
            if ($p.Name -like '_*') { continue }
            $val = "$($p.Value)"
            if ([string]::IsNullOrEmpty($val)) { $val = '-' }
            $rows.Add([PSCustomObject]@{ Key = $p.Name; Value = $val })
        }
        $UI.DetailsList.ItemsSource = $rows
        $UI.DetailsCol.Width = New-Object System.Windows.GridLength 320
        $UI.DetailsPanel.Visibility = 'Visible'
    }
    function Hide-Details {
        $UI.DetailsPanel.Visibility = 'Collapsed'
        $UI.DetailsCol.Width = New-Object System.Windows.GridLength 0
        $UI.DetailsList.ItemsSource = $null
    }

    # ---------------- Visualizer ----------------
    function Reset-VizTransform {
        if ($script:VizTranslate) { $script:VizTranslate.X = 0; $script:VizTranslate.Y = 0 }
        if ($script:VizScale)     {
            $script:VizScale.CenterX = 0; $script:VizScale.CenterY = 0
            $script:VizScale.ScaleX = 1; $script:VizScale.ScaleY = 1
        }
    }

    function Zoom-Viz {
        param([double]$Factor)
        if (-not $script:VizScale) { return }
        $newScale = [Math]::Min([Math]::Max($script:VizScale.ScaleX * $Factor, 0.2), 5.0)
        # Zoom from the canvas viewport centre when triggered by buttons
        $cv = $UI.VizCanvas
        $script:VizScale.CenterX = $cv.ActualWidth  / 2
        $script:VizScale.CenterY = $cv.ActualHeight / 2
        $script:VizScale.ScaleX  = $newScale
        $script:VizScale.ScaleY  = $newScale
    }

    function Render-Visualizer {
        $cv = $UI.VizCanvas
        $cv.Children.Clear()

        # Build (or reuse) the canvas RenderTransform = Scale * Translate.
        # Scale first (so translate is in screen space) → put Scale before Translate in the group.
        if (-not $script:VizTranslate) {
            $tg = [System.Windows.Media.TransformGroup]::new()
            $script:VizScale     = [System.Windows.Media.ScaleTransform]::new(1, 1)
            $script:VizTranslate = [System.Windows.Media.TranslateTransform]::new(0, 0)
            $null = $tg.Children.Add($script:VizScale)
            $null = $tg.Children.Add($script:VizTranslate)
            $cv.RenderTransform = $tg
        }

        $a = $script:VizAssignment
        if (-not $a) { $UI.VizPlaceholder.Visibility = 'Visible'; return }
        $UI.VizPlaceholder.Visibility = 'Collapsed'

        # -- Initial layout dimensions -------------------------------------
        $baseW = 1000; $baseH = 600
        $cx = $baseW / 2; $cy = $baseH / 2
        $hubR = 70

        # -- Fetch ALL cmdlets ---------------------------------------------
        $allEntries = @()
        try {
            $allEntries = @(Get-ManagementRoleEntry "$($a.Role)\*" -ErrorAction Stop)
        } catch { $allEntries = @() }

        $spokes = @(
            @{ Label='What · Role';     Name=$a.Role;                Sub='';                       Bg='#DFF6DD'; X=$cx - 280; Y=$cy - 200 }
            @{ Label='Who · Assignee';  Name=$a.RoleAssignee;        Sub=$a.RoleAssigneeType;       Bg='#FFF4CE'; X=$cx + 100; Y=$cy - 200 }
            @{ Label='Where · Scope';   Name=$a.RecipientWriteScope; Sub=$a.RecipientReadScope;     Bg='#FCE4E4'; X=$cx - 100; Y=$cy + 130 }
        )

        # -- Role node centre for cmdlet fan ------------------------------
        $nodeW   = 200; $nodeH = 60
        $roleS   = $spokes[0]
        $roleNcX = $roleS.X + $nodeW / 2
        $roleNcY = $roleS.Y + $nodeH / 2

        # Base angle from hub to role node
        $vx = $roleNcX - $cx; $vy = $roleNcY - $cy
        $vlen = [Math]::Sqrt($vx * $vx + $vy * $vy)
        if ($vlen -gt 0) { $vx /= $vlen; $vy /= $vlen }
        $baseAngle = [Math]::Atan2($vy, $vx)

        # -- Cmdlet positioning: circular layout with multiple rings -------
        # Compact form to stay readable when a role grants many cmdlets.
        $cmdletNodeW    = 140
        $cmdletNodeH    = 22
        $baseRadius     = 130
        $ringSpacing    = 70
        $itemsPerRing   = 14
        $cmdletPositions = @()
        $bounds = @{ minX = $roleNcX; maxX = $roleNcX; minY = $roleNcY; maxY = $roleNcY }

        for ($i = 0; $i -lt $allEntries.Count; $i++) {
            $ring     = [int]($i / $itemsPerRing)
            $posInRing = $i % $itemsPerRing
            $radius   = $baseRadius + $ring * $ringSpacing
            $angle    = $baseAngle + 2 * [Math]::PI * $posInRing / $itemsPerRing

            $ncX = $roleNcX + $radius * [Math]::Cos($angle)
            $ncY = $roleNcY + $radius * [Math]::Sin($angle)
            $x   = $ncX - $cmdletNodeW / 2
            $y   = $ncY - $cmdletNodeH / 2

            $cmdletPositions += @{
                X     = $x
                Y     = $y
                NcX   = $ncX
                NcY   = $ncY
                Angle = $angle
                Ring  = $ring
            }

            # Track bounds
            $bounds.minX = [Math]::Min($bounds.minX, $x)
            $bounds.maxX = [Math]::Max($bounds.maxX, $x + $cmdletNodeW)
            $bounds.minY = [Math]::Min($bounds.minY, $y)
            $bounds.maxY = [Math]::Max($bounds.maxY, $y + $cmdletNodeH)
        }

        # -- Also track spoke nodes ----------------------------------------
        foreach ($s in $spokes) {
            $bounds.minX = [Math]::Min($bounds.minX, $s.X)
            $bounds.maxX = [Math]::Max($bounds.maxX, $s.X + 200)
            $bounds.minY = [Math]::Min($bounds.minY, $s.Y)
            $bounds.maxY = [Math]::Max($bounds.maxY, $s.Y + 60)
        }

        # -- Canvas size = bounding box + padding --------------------------
        $padding = 40
        $canvasW = [Math]::Max($bounds.maxX - $bounds.minX + $padding * 2, $baseW)
        $canvasH = [Math]::Max($bounds.maxY - $bounds.minY + $padding * 2, $baseH)
        $offsetX = -$bounds.minX + $padding
        $offsetY = -$bounds.minY + $padding

        $cv.Width  = $canvasW
        $cv.Height = $canvasH

        # -- Helper: arrowhead polygon (returns the Polygon so callers can
        #    track and update it when the connected line moves) ------------
        $addArrow = {
            param([System.Windows.Controls.Canvas]$canvas,
                  [double]$tipX, [double]$tipY, [double]$angle, [string]$color)
            $al   = 8; $aw = 0.35
            $back = $angle + [Math]::PI
            $poly = [System.Windows.Shapes.Polygon]::new()
            $pts  = [System.Windows.Media.PointCollection]::new()
            $null = $pts.Add([System.Windows.Point]::new($tipX, $tipY))
            $null = $pts.Add([System.Windows.Point]::new(
                $tipX + $al * [Math]::Cos($back + $aw),
                $tipY + $al * [Math]::Sin($back + $aw)))
            $null = $pts.Add([System.Windows.Point]::new(
                $tipX + $al * [Math]::Cos($back - $aw),
                $tipY + $al * [Math]::Sin($back - $aw)))
            $poly.Points = $pts
            $poly.Fill   = $color
            $null = $canvas.Children.Add($poly)
            return $poly
        }

        # -- Helper: add drag support to a Border --------------------------
        # State + connected-line links are stashed on $elem.Tag so the event
        # handlers don't depend on the enclosing scope (which can be lost when
        # event handlers fire outside Render-Visualizer's frame).
        $makeDraggable = {
            param([System.Windows.Controls.Border]$elem, [array]$Links = @())
            $elem.Tag = @{
                Links  = $Links
                Drag   = $false
                StartX = 0; StartY = 0
                ElemX  = 0; ElemY  = 0
                Canvas = $cv
            }
            $elem.Cursor = [System.Windows.Input.Cursors]::SizeAll

            $elem.Add_MouseLeftButtonDown({
                param($s, $e)
                $t = $s.Tag
                $p = $e.GetPosition($t.Canvas)
                $t.Drag   = $true
                $t.StartX = $p.X; $t.StartY = $p.Y
                $t.ElemX  = [System.Windows.Controls.Canvas]::GetLeft($s)
                $t.ElemY  = [System.Windows.Controls.Canvas]::GetTop($s)
                $null = $s.CaptureMouse()
                $e.Handled = $true   # prevent canvas pan from firing
            })
            $elem.Add_MouseLeftButtonUp({
                param($s, $e)
                $s.Tag.Drag = $false
                $s.ReleaseMouseCapture()
                $e.Handled = $true
            })
            $elem.Add_MouseMove({
                param($s, $e)
                $t = $s.Tag
                if (-not $t.Drag) { return }
                $p = $e.GetPosition($t.Canvas)
                $newX = $t.ElemX + ($p.X - $t.StartX)
                $newY = $t.ElemY + ($p.Y - $t.StartY)
                [System.Windows.Controls.Canvas]::SetLeft($s, $newX)
                [System.Windows.Controls.Canvas]::SetTop($s, $newY)
                foreach ($lk in $t.Links) {
                    $ax = $newX + $lk.OffsetX
                    $ay = $newY + $lk.OffsetY
                    if ($lk.End -eq 'start') {
                        $lk.Line.X1 = $ax; $lk.Line.Y1 = $ay
                    } else {
                        $lk.Line.X2 = $ax; $lk.Line.Y2 = $ay
                    }
                    # Recompute arrowhead points if the line has one
                    if ($lk.Arrow) {
                        $tipX  = $lk.Line.X2; $tipY = $lk.Line.Y2
                        $angle = [Math]::Atan2($lk.Line.Y2 - $lk.Line.Y1, $lk.Line.X2 - $lk.Line.X1)
                        $back  = $angle + [Math]::PI
                        $al    = 8; $aw = 0.35
                        $pts   = [System.Windows.Media.PointCollection]::new()
                        $null  = $pts.Add([System.Windows.Point]::new($tipX, $tipY))
                        $null  = $pts.Add([System.Windows.Point]::new(
                            $tipX + $al * [Math]::Cos($back + $aw),
                            $tipY + $al * [Math]::Sin($back + $aw)))
                        $null  = $pts.Add([System.Windows.Point]::new(
                            $tipX + $al * [Math]::Cos($back - $aw),
                            $tipY + $al * [Math]::Sin($back - $aw)))
                        $lk.Arrow.Points = $pts
                    }
                }
            })
        }

        # -- Edges: hub → spokes (stored so node drag can update them) ----
        $spokeLines = @()
        foreach ($s in $spokes) {
            $line = [System.Windows.Shapes.Line]::new()
            $line.X1 = $cx + $offsetX; $line.Y1 = $cy + $offsetY
            $line.X2 = $s.X + 90 + $offsetX; $line.Y2 = $s.Y + 30 + $offsetY
            $line.Stroke = '#605E5C'
            $line.StrokeThickness = 1.5
            $null = $cv.Children.Add($line)
            $spokeLines += $line
        }

        # -- Edges: role node → cmdlet nodes (stored too) -----------------
        $dashes = [System.Windows.Media.DoubleCollection]::new()
        $null = $dashes.Add(4.0)
        $null = $dashes.Add(2.0)

        $cmdletLines  = @()
        $cmdletArrows = @()
        for ($i = 0; $i -lt $allEntries.Count; $i++) {
            $pos  = $cmdletPositions[$i]
            $line = [System.Windows.Shapes.Line]::new()
            $line.X1 = $roleNcX + $offsetX; $line.Y1 = $roleNcY + $offsetY
            $line.X2 = $pos.NcX + $offsetX; $line.Y2 = $pos.NcY + $offsetY
            $line.Stroke          = '#558B2F'
            $line.StrokeThickness = 1.2
            $line.StrokeDashArray = $dashes
            $null = $cv.Children.Add($line)
            $arrow = & $addArrow $cv ($pos.NcX + $offsetX) ($pos.NcY + $offsetY) $pos.Angle '#558B2F'
            $cmdletLines  += $line
            $cmdletArrows += $arrow
        }

        # -- Hub -----------------------------------------------------------
        $hub = [System.Windows.Controls.Border]::new()
        $hub.Width = $hubR * 2; $hub.Height = $hubR * 2
        $hub.CornerRadius = "$hubR"
        $hub.Background = '#E6E0F8'
        $hub.BorderBrush = '#0078D4'
        $hub.BorderThickness = 2
        $sp = [System.Windows.Controls.StackPanel]::new()
        $sp.HorizontalAlignment = 'Center'; $sp.VerticalAlignment = 'Center'
        $tb1 = [System.Windows.Controls.TextBlock]::new()
        $tb1.Text = 'ASSIGNMENT'; $tb1.FontFamily = 'Consolas'; $tb1.FontSize = 9; $tb1.Foreground = '#605E5C'
        $tb1.HorizontalAlignment = 'Center'
        $tb2 = [System.Windows.Controls.TextBlock]::new()
        $tb2.Text = $a.Name; $tb2.FontWeight = 'SemiBold'; $tb2.FontSize = 11
        $tb2.HorizontalAlignment = 'Center'; $tb2.TextWrapping = 'Wrap'; $tb2.TextAlignment = 'Center'
        $tb2.MaxWidth = $hubR * 2 - 16
        $null = $sp.Children.Add($tb1)
        $null = $sp.Children.Add($tb2)
        $hub.Child = $sp
        [System.Windows.Controls.Canvas]::SetLeft($hub, $cx - $hubR + $offsetX)
        [System.Windows.Controls.Canvas]::SetTop($hub,  $cy - $hubR + $offsetY)
        $null = $cv.Children.Add($hub)
        # Hub anchors the START of each spoke line (offset = hub centre)
        $hubLinks = @()
        foreach ($l in $spokeLines) {
            $hubLinks += @{ Line = $l; End = 'start'; OffsetX = $hubR; OffsetY = $hubR }
        }
        & $makeDraggable $hub $hubLinks

        # -- Spoke nodes ---------------------------------------------------
        for ($si = 0; $si -lt $spokes.Count; $si++) {
            $s = $spokes[$si]
            $node = [System.Windows.Controls.Border]::new()
            $node.Width = 200
            $node.CornerRadius = '4'
            $node.Background = $s.Bg
            $node.BorderBrush = '#605E5C'
            $node.BorderThickness = 1
            $node.Padding = '10,8'
            $st = [System.Windows.Controls.StackPanel]::new()
            $lbl = [System.Windows.Controls.TextBlock]::new()
            $lbl.Text = $s.Label; $lbl.FontFamily = 'Consolas'; $lbl.FontSize = 10
            $lbl.Foreground = '#605E5C'
            $name = [System.Windows.Controls.TextBlock]::new()
            $name.Text = $s.Name; $name.FontSize = 13; $name.FontWeight = 'SemiBold'
            $name.TextWrapping = 'Wrap'
            $null = $st.Children.Add($lbl)
            $null = $st.Children.Add($name)
            if ($s.Sub) {
                $sub = [System.Windows.Controls.TextBlock]::new()
                $sub.Text = $s.Sub; $sub.FontFamily = 'Consolas'; $sub.FontSize = 10
                $sub.Foreground = '#605E5C'; $sub.TextWrapping = 'Wrap'
                $null = $st.Children.Add($sub)
            }
            $node.Child = $st
            [System.Windows.Controls.Canvas]::SetLeft($node, $s.X + $offsetX)
            [System.Windows.Controls.Canvas]::SetTop($node,  $s.Y + $offsetY)
            $null = $cv.Children.Add($node)

            # Each spoke node owns the END of its hub-spoke line (anchor = node centre).
            $links = @( @{ Line = $spokeLines[$si]; End = 'end'; OffsetX = 100; OffsetY = 30; Arrow = $null } )
            # The Role spoke (index 0) also anchors the START of every cmdlet line + its arrow.
            if ($si -eq 0) {
                for ($ci = 0; $ci -lt $cmdletLines.Count; $ci++) {
                    $links += @{
                        Line    = $cmdletLines[$ci]
                        End     = 'start'
                        OffsetX = $nodeW / 2
                        OffsetY = $nodeH / 2
                        Arrow   = $cmdletArrows[$ci]
                    }
                }
            }
            & $makeDraggable $node $links
        }

        # -- Cmdlet nodes --------------------------------------------------
        for ($i = 0; $i -lt $allEntries.Count; $i++) {
            $pos   = $cmdletPositions[$i]
            $entry = $allEntries[$i]
            $node  = [System.Windows.Controls.Border]::new()
            $node.Width        = $cmdletNodeW
            $node.CornerRadius = '3'
            $node.Background   = '#C5E1A5'
            $node.BorderBrush  = '#558B2F'
            $node.BorderThickness = 1
            $node.Padding      = '5,2'
            $tb = [System.Windows.Controls.TextBlock]::new()
            $tb.Text        = $entry.Name
            $tb.FontSize    = 9; $tb.FontWeight = 'SemiBold'
            $tb.TextTrimming = 'CharacterEllipsis'; $tb.Foreground = '#33691E'
            $tb.ToolTip = "$($entry.Name) [$($entry.Type)]"
            $node.Child = $tb
            [System.Windows.Controls.Canvas]::SetLeft($node, $pos.X + $offsetX)
            [System.Windows.Controls.Canvas]::SetTop($node,  $pos.Y + $offsetY)
            $null = $cv.Children.Add($node)
            $links = @( @{
                Line    = $cmdletLines[$i]
                End     = 'end'
                OffsetX = $cmdletNodeW / 2
                OffsetY = $cmdletNodeH / 2
                Arrow   = $cmdletArrows[$i]
            } )
            & $makeDraggable $node $links
        }
    }

    # ---------------- Data loaders ----------------
    function Require-Connected {
        if (-not (Test-RBACExchangeConnection)) {
            Set-Status 'Not connected. Click Connect in the sidebar.' 'warn'
            $UI.MainGrid.ItemsSource = $null
            return $false
        }
        return $true
    }

    function Load-ViewData {
        param([string]$View)
        if ($View -ne 'UserRights' -and $View -ne 'Commands' -and $View -ne 'Visualizer') {
            if (-not (Require-Connected)) { return }
        }
        try {
            switch ($View) {
                'RoleGroups' {
                    Set-Status 'Loading role groups…'
                    $data = Get-RBACRoleGroups
                    $script:Cache.RoleGroups = $data
                    $UI.MainGrid.ItemsSource = $data
                    $UI.ItemCount.Text = "$(@($data).Count) items"
                    Set-Status "Loaded $(@($data).Count) role groups." 'ok'
                }
                'Roles' {
                    Set-Status 'Loading roles…'
                    $roles = Get-RBACRoles
                    $display = foreach ($r in $roles) {
                        $origin = if ($r.RoleType -eq 'UnScoped') { 'Custom' } elseif ("$($r.Parent)") { 'Custom' } else { 'Built-in' }
                        [PSCustomObject]@{
                            Name        = $r.Name
                            RoleType    = $r.RoleType
                            Origin      = $origin
                            Parent      = $r.Parent
                            Description = $r.Description
                            _raw        = $r
                        }
                    }
                    $script:Cache.Roles = $display
                    $UI.MainGrid.ItemsSource = $display
                    $UI.ItemCount.Text = "$(@($display).Count) items"
                    Set-Status "Loaded $(@($display).Count) roles." 'ok'
                }
                'Assignments' {
                    Set-Status 'Loading role assignments…'
                    $data = Get-RBACRoleAssignments
                    $script:Cache.Assignments = $data
                    $UI.MainGrid.ItemsSource = $data
                    $UI.ItemCount.Text = "$(@($data).Count) items"
                    Set-Status "Loaded $(@($data).Count) role assignments." 'ok'
                }
                'Scopes' {
                    Set-Status 'Loading management scopes…'
                    $data = Get-RBACManagementScopes
                    $script:Cache.Scopes = $data
                    $UI.MainGrid.ItemsSource = $data
                    $UI.ItemCount.Text = "$(@($data).Count) items"
                    Set-Status "Loaded $(@($data).Count) scopes." 'ok'
                }
                'UserRights' {
                    $UI.MainGrid.ItemsSource = $null
                    $UI.ItemCount.Text = '0 items'
                    Set-Status 'Type a user (UPN or alias) and press Search.' 'info'
                }
                'Commands' {
                    $UI.MainGrid.ItemsSource = $null
                    $UI.ItemCount.Text = '0 items'
                    Set-Status 'Type a cmdlet (e.g. Set-Mailbox) and press Search.' 'info'
                }
                'Visualizer' {
                    if (-not (Test-RBACExchangeConnection)) {
                        Set-Status 'Connect first to load assignments.' 'warn'; return
                    }
                    if (-not $script:Cache.Assignments) { $script:Cache.Assignments = Get-RBACRoleAssignments }
                    if (@($script:Cache.Assignments).Count -gt 0 -and -not $script:VizAssignment) {
                        $script:VizAssignment = $script:Cache.Assignments[0]
                    }
                    $UI.ItemCount.Text = "$(@($script:Cache.Assignments).Count) assignments"
                    Render-Visualizer
                    Set-Status "Visualizing $($script:VizAssignment.Name)." 'ok'
                }
                'Audit' {
                    Load-Audit -Days 7
                }
            }
        }
        catch {
            Set-Status "Error: $($_.Exception.Message)" 'error'
        }
    }

    function Load-Audit {
        param([int]$Days = 7)
        if (-not (Require-Connected)) { return }
        Set-Status "Querying Search-AdminAuditLog (last $Days days)…"
        try {
            $end = Get-Date
            $start = $end.AddDays(-$Days)
            $raw = Search-AdminAuditLog -StartDate $start -EndDate $end -ResultSize 500 -ErrorAction Stop
            $rows = foreach ($e in $raw) {
                $paramParts = foreach ($cp in $e.CmdletParameters) { "$($cp.Name)=$($cp.Value)" }
                $params = $paramParts -join '; '
                [PSCustomObject]@{
                    Timestamp  = ($e.RunDate.ToString('yyyy-MM-dd HH:mm:ss'))
                    Caller     = $e.Caller
                    Cmdlet     = $e.CmdletName
                    Object     = $e.ObjectModified
                    Parameters = $params
                    Succeeded  = $e.Succeeded
                }
            }
            $script:Cache.Audit = $rows
            $UI.MainGrid.ItemsSource = $rows
            $UI.ItemCount.Text = "$(@($rows).Count) items"
            Set-Status "Audit log: $(@($rows).Count) entries (last $Days days)." 'ok'
        }
        catch {
            Set-Status "Search-AdminAuditLog failed: $($_.Exception.Message)" 'error'
        }
    }

    # ---------------- Search / filter ----------------
    function Test-ChipMatch {
        # Returns $true if the row matches the active chip for the current view.
        # Chip 'all' (or null) is a no-op.
        param($Row, [string]$View, [string]$Chip)
        if (-not $Chip -or $Chip -eq 'all') { return $true }
        switch ($View) {
            'RoleGroups' {
                switch ($Chip) {
                    'built-in' { return ($Row.Origin -eq 'Built-in') }
                    'custom'   { return ($Row.Origin -eq 'Custom') }
                }
            }
            'Roles' {
                switch ($Chip) {
                    'built-in'   { return ($Row.Origin -eq 'Built-in') }
                    'custom'     { return ($Row.Origin -eq 'Custom') }
                    'unassigned' {
                        # Roles with no live assignment in the cache
                        if (-not $script:Cache.Assignments) { return $true }
                        $name = $Row.Name
                        foreach ($asg in $script:Cache.Assignments) {
                            if ($asg.Role -eq $name) { return $false }
                        }
                        return $true
                    }
                }
            }
            'Assignments' {
                switch ($Chip) {
                    'enabled'  { return ([bool]$Row.Enabled -eq $true) }
                    'disabled' { return ([bool]$Row.Enabled -eq $false) }
                }
            }
            'Scopes' {
                $t = "$($Row.ScopeRestrictionType)"
                switch ($Chip) {
                    'implicit'  { return ($t -like '*Implicit*') }
                    'custom'    { return ($t -notlike '*Implicit*') }
                    'recipient' { return ($t -like '*Recipient*') }
                    'server'    { return ($t -like '*Server*') }
                }
            }
            'Audit' {
                # Audit chips drive the query window — handled at load time, not here.
                return $true
            }
        }
        return $true
    }

    function Apply-Filters {
        $view = $script:CurrentView
        $q = $UI.SearchBox.Text
        if (-not $q) { $q = '' }
        $q = $q.Trim()

        switch ($view) {
            'RoleGroups'  { $src = $script:Cache.RoleGroups }
            'Roles'       { $src = $script:Cache.Roles }
            'Assignments' { $src = $script:Cache.Assignments }
            'Scopes'      { $src = $script:Cache.Scopes }
            'Audit'       { $src = $script:Cache.Audit }
            'UserRights'  {
                if (-not $q) { Set-Status 'Type a user (UPN or alias) and press Search.' 'info'; return }
                Lookup-UserRights -User $q
                return
            }
            'Commands' {
                if (-not $q) { Set-Status 'Type a cmdlet name and press Search.' 'info'; return }
                Lookup-Command -Cmdlet $q
                return
            }
            default { return }
        }
        if (-not $src) { return }

        $chip = $script:ActiveChip[$view]
        $filtered = foreach ($row in $src) {
            if (-not (Test-ChipMatch -Row $row -View $view -Chip $chip)) { continue }
            if ($q -ne '') {
                $hit = $false
                foreach ($p in $row.PSObject.Properties) {
                    if ($p.Name -like '_*') { continue }
                    $v = "$($p.Value)"
                    if ($v -and $v -like "*$q*") { $hit = $true; break }
                }
                if (-not $hit) { continue }
            }
            $row
        }
        $filtered = @($filtered)
        $UI.MainGrid.ItemsSource = $filtered
        $UI.ItemCount.Text = "$(@($filtered).Count) items"
    }

    # Backward-compat alias kept for existing event wiring
    function Apply-Search { Apply-Filters }

    function Lookup-UserRights {
        param([string]$User)
        if (-not (Require-Connected)) { return }
        Set-Status "Resolving rights for '$User'…"
        try {
            if (-not $script:Cache.Assignments) { $script:Cache.Assignments = Get-RBACRoleAssignments }
            $matches = @()
            foreach ($asg in $script:Cache.Assignments) {
                $hit = $false
                if ($asg.RoleAssignee -like "*$User*") { $hit = $true; $via = 'Direct or named' }
                if (-not $hit -and $asg.RoleAssigneeType -eq 'RoleGroup') {
                    try {
                        $g = Get-RoleGroup -Identity $asg.RoleAssignee -ErrorAction SilentlyContinue
                        if ($g -and ($g.Members | Where-Object { "$_" -like "*$User*" })) {
                            $hit = $true; $via = "via $($asg.RoleAssignee)"
                        }
                    } catch { }
                }
                if ($hit) {
                    $matches += [PSCustomObject]@{
                        User       = $User
                        Role       = $asg.Role
                        Via        = $via
                        ReadScope  = $asg.RecipientReadScope
                        WriteScope = $asg.RecipientWriteScope
                        _raw       = $asg
                    }
                }
            }
            $UI.MainGrid.ItemsSource = $matches
            $UI.ItemCount.Text = "$(@($matches).Count) items"
            if (@($matches).Count -gt 0) { Set-Status "$User has $(@($matches).Count) effective role(s)." 'ok' }
            else { Set-Status "No assignments found for '$User'." 'warn' }
        }
        catch { Set-Status "Lookup failed: $($_.Exception.Message)" 'error' }
    }

    function Lookup-Command {
        param([string]$Cmdlet)
        if (-not (Require-Connected)) { return }
        Set-Status "Searching roles that grant '$Cmdlet'…"
        try {
            $roles = Get-ManagementRole -Cmdlet $Cmdlet -ErrorAction Stop
            $rows = foreach ($r in $roles) {
                [PSCustomObject]@{
                    RoleName    = $r.Name
                    RoleType    = $r.RoleType
                    Origin      = if ($r.Parent) { 'Custom' } else { 'Built-in' }
                    Description = $r.Description
                }
            }
            $UI.MainGrid.ItemsSource = $rows
            $UI.ItemCount.Text = "$(@($rows).Count) items"
            Set-Status "$(@($rows).Count) role(s) grant '$Cmdlet'." 'ok'
        }
        catch { Set-Status "Command lookup failed: $($_.Exception.Message)" 'error' }
    }

    # ---------------- View switching ----------------
    function Switch-View {
        param([string]$View)

        # Update toggle states
        $btnMap = @{
            RoleGroups  = $UI.NavRoleGroups;  Roles       = $UI.NavRoles
            Assignments = $UI.NavAssignments; Scopes      = $UI.NavScopes
            UserRights  = $UI.NavUserRights;  Commands    = $UI.NavCommands
            Visualizer  = $UI.NavVisualizer;  Audit       = $UI.NavAudit
        }
        foreach ($k in $btnMap.Keys) { $btnMap[$k].IsChecked = ($k -eq $View) }

        $script:CurrentView = $View
        $cfg = $script:Views[$View]

        $UI.Crumbs.Text    = $cfg.Crumbs
        $UI.ViewTitle.Text = $cfg.Title
        $UI.ViewDesc.Text  = $cfg.Desc
        $UI.SearchBox.Text = ''
        $defaultChip = if ($cfg.Chips -and $cfg.Chips.Count -gt 0) { $cfg.Chips[0] } else { '' }
        Set-Chips -Labels $cfg.Chips -ActiveLabel $defaultChip
        $UI.ItemCount.Text = '0 items'
        $UI.SelectionCount.Text = '0 selected'
        Hide-Details

        # Switch table vs visualizer
        if ($View -eq 'Visualizer') {
            $UI.MainGrid.Visibility = 'Collapsed'
            $UI.VizHost.Visibility  = 'Visible'
        }
        else {
            $UI.VizHost.Visibility  = 'Collapsed'
            $UI.MainGrid.Visibility = 'Visible'
            Set-GridColumns -Columns $cfg.Columns
        }

        # Action bar
        Set-Actions -Buttons (Get-ActionsForView -View $View)

        Load-ViewData -View $View
    }

    function Get-ActionsForView {
        param([string]$View)
        $list = @()
        switch ($View) {
            'RoleGroups' {
                $list += (New-ActionButton -Label '+ New'             -Style 'PrimaryBtn' -OnClick { Do-NewRoleGroup })
                $list += (New-ActionButton -Label 'Edit'              -Style 'ActionBtn'  -OnClick { Do-EditRoleGroup })
                $list += (New-ActionButton -Label 'Copy'              -Style 'ActionBtn'  -OnClick { Do-CopyRoleGroup })
                $list += (New-ActionButton -Label 'Delete'            -Style 'WarnBtn'    -OnClick { Do-DeleteRoleGroup })
                $list += (New-ActionButton -Label 'Export CSV'        -Style 'ActionBtn'  -OnClick { Export-CurrentView })
            }
            'Roles' {
                $list += (New-ActionButton -Label 'View Cmdlets'      -Style 'PrimaryBtn' -OnClick { Show-RoleCmdlets })
                $list += (New-ActionButton -Label '↗ Export CSV'      -Style 'ActionBtn'  -OnClick { Export-CurrentView })
            }
            'Assignments' {
                $list += (New-ActionButton -Label 'Visualize'         -Style 'PrimaryBtn' -OnClick { Visualize-Selected })
                $list += (New-ActionButton -Label '↗ Export CSV'      -Style 'ActionBtn'  -OnClick { Export-CurrentView })
            }
            'Scopes' {
                $list += (New-ActionButton -Label '↗ Export CSV'      -Style 'ActionBtn' -OnClick { Export-CurrentView })
            }
            'UserRights' {
                $list += (New-ActionButton -Label 'Lookup'            -Style 'PrimaryBtn' -OnClick { Apply-Search })
                $list += (New-ActionButton -Label 'Visualize'         -Style 'ActionBtn'  -OnClick { Visualize-Selected })
                $list += (New-ActionButton -Label '↗ Export CSV'      -Style 'ActionBtn'  -OnClick { Export-CurrentView })
            }
            'Commands' {
                $list += (New-ActionButton -Label 'Lookup'            -Style 'PrimaryBtn' -OnClick { Apply-Search })
                $list += (New-ActionButton -Label '↗ Export CSV'      -Style 'ActionBtn'  -OnClick { Export-CurrentView })
            }
            'Visualizer' {
                $list += (New-ActionButton -Label 'Pick assignment…'  -Style 'PrimaryBtn' -OnClick { Pick-VizAssignment })
                $list += (New-ActionButton -Label '➕ Zoom in'         -Style 'ActionBtn'  -OnClick { Zoom-Viz 1.2 })
                $list += (New-ActionButton -Label '➖ Zoom out'        -Style 'ActionBtn'  -OnClick { Zoom-Viz (1 / 1.2) })
                $list += (New-ActionButton -Label '⌖ Center'          -Style 'ActionBtn'  -OnClick { Reset-VizTransform; Render-Visualizer })
                $list += (New-ActionButton -Label '↗ Export PNG'      -Style 'ActionBtn'  -OnClick { Export-VizPng })
            }
            'Audit' {
                $list += (New-ActionButton -Label '⟳ 7 days'          -Style 'ActionBtn' -OnClick { Load-Audit -Days 7 })
                $list += (New-ActionButton -Label '⟳ 30 days'         -Style 'ActionBtn' -OnClick { Load-Audit -Days 30 })
                $list += (New-ActionButton -Label '⟳ 90 days'         -Style 'ActionBtn' -OnClick { Load-Audit -Days 90 })
                $list += (New-ActionButton -Label '↗ Export CSV'      -Style 'ActionBtn' -OnClick { Export-CurrentView })
            }
        }
        return $list
    }

    # ---------------- Action implementations ----------------
    function Export-CurrentView {
        if (-not $UI.MainGrid.ItemsSource) { Set-Status 'Nothing to export.' 'warn'; return }
        $dlg = [System.Windows.Forms.SaveFileDialog]::new()
        $dlg.Filter = 'CSV (*.csv)|*.csv'
        $dlg.FileName = "rbac-$($script:CurrentView)-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
        if ($dlg.ShowDialog() -eq 'OK') {
            $UI.MainGrid.ItemsSource | Select-Object * -ExcludeProperty _raw |
                Export-Csv -Path $dlg.FileName -NoTypeInformation -Encoding UTF8
            Set-Status "Exported to $($dlg.FileName)." 'ok'
        }
    }

    # ---------------- Role Group write actions ----------------
    function Do-NewRoleGroup {
        if (-not (Require-Connected)) { return }
        $form = Show-RoleGroupForm -Title 'New Role Group'
        if (-not $form) { return }
        if ($script:DryRun) {
            $r = New-RBACRoleGroup -Name $form.Name -Description $form.Description -Roles $form.Roles -Members $form.Members -DryRun
        }
        else {
            if (-not (Confirm-WriteAction -Title 'Create role group' -Message "Create '$($form.Name)' in the connected tenant?")) { return }
            $r = New-RBACRoleGroup -Name $form.Name -Description $form.Description -Roles $form.Roles -Members $form.Members
        }
        Handle-WriteResult -Result $r -SuccessMsg "Created role group '$($form.Name)'." -DryRunTitle 'New-RoleGroup (dry-run)'
        if (-not $script:DryRun -and $r -and -not $r.Error) { Load-ViewData -View 'RoleGroups' }
    }

    function Do-EditRoleGroup {
        if (-not (Require-Connected)) { return }
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select a role group first.' 'warn'; return }
        if ($sel.Origin -eq 'Built-in') {
            Set-Status "Built-in role groups can't be edited from this UI." 'warn'; return
        }
        $existingRoles   = @($sel.Roles   | ForEach-Object { "$_" } | Where-Object { $_ })
        $existingMembers = @($sel.Members | ForEach-Object { "$_" } | Where-Object { $_ })
        $form = Show-RoleGroupForm `
                    -Title              "Edit role group: $($sel.Name)" `
                    -DefaultName        $sel.Name `
                    -DefaultDescription $sel.Description `
                    -DefaultRoles       $existingRoles `
                    -DefaultMembers     $existingMembers `
                    -NameReadOnly       $true
        if (-not $form) { return }
        $params = @{
            Identity    = $sel.Name
            Description = $form.Description
            Members     = $form.Members
        }
        if ($script:DryRun) {
            $params.DryRun = $true
            $r = Set-RBACRoleGroup @params
        }
        else {
            if (-not (Confirm-WriteAction -Title 'Update role group' -Message "Update '$($sel.Name)' (description and member list)?`nNote: role list and rename are not edited here.")) { return }
            $r = Set-RBACRoleGroup @params
        }
        Handle-WriteResult -Result $r -SuccessMsg "Updated role group '$($sel.Name)'." -DryRunTitle 'Set-RoleGroup (dry-run)'
        if (-not $script:DryRun) {
            $hasErr = $false
            if ($r -is [System.Array]) { $hasErr = @($r | Where-Object { $_.Error }).Count -gt 0 }
            elseif ($r.Error) { $hasErr = $true }
            if (-not $hasErr) { Load-ViewData -View 'RoleGroups' }
        }
    }

    function Do-CopyRoleGroup {
        if (-not (Require-Connected)) { return }
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select a role group to copy.' 'warn'; return }
        $existingRoles   = @($sel.Roles   | ForEach-Object { "$_" } | Where-Object { $_ })
        $existingMembers = @($sel.Members | ForEach-Object { "$_" } | Where-Object { $_ })
        $form = Show-RoleGroupForm `
                    -Title                "Copy role group: $($sel.Name)" `
                    -DefaultName          ("$($sel.Name) - Copy") `
                    -DefaultDescription   ("$($sel.Description) (copy of $($sel.Name))".Trim()) `
                    -DefaultRoles         $existingRoles `
                    -DefaultMembers       $existingMembers `
                    -NameLabel            'New name' `
                    -ShowIncludeMembers   $true `
                    -DefaultIncludeMembers $false
        if (-not $form) { return }
        if ($script:DryRun) {
            $r = Copy-RBACRoleGroup -SourceName $sel.Name -NewName $form.Name -NewDescription $form.Description -IncludeMembers:$form.IncludeMembers -DryRun
        }
        else {
            if (-not (Confirm-WriteAction -Title 'Copy role group' -Message "Create '$($form.Name)' as a copy of '$($sel.Name)'?")) { return }
            $r = Copy-RBACRoleGroup -SourceName $sel.Name -NewName $form.Name -NewDescription $form.Description -IncludeMembers:$form.IncludeMembers
        }
        Handle-WriteResult -Result $r -SuccessMsg "Copied to '$($form.Name)'." -DryRunTitle 'New-RoleGroup (dry-run)'
        if (-not $script:DryRun -and $r -and -not $r.Error) { Load-ViewData -View 'RoleGroups' }
    }

    function Do-DeleteRoleGroup {
        if (-not (Require-Connected)) { return }
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select a role group to delete.' 'warn'; return }
        if ($sel.Origin -eq 'Built-in') {
            Set-Status "Built-in role groups can't be deleted." 'warn'; return
        }
        if ($script:DryRun) {
            $r = Remove-RBACRoleGroup -Identity $sel.Name -DryRun
        }
        else {
            $msg = "Delete role group '$($sel.Name)' permanently?`n`nThis cannot be undone. Existing role assignments referencing this group will be removed too."
            if (-not (Confirm-WriteAction -Title 'Delete role group' -Message $msg)) { return }
            $r = Remove-RBACRoleGroup -Identity $sel.Name
        }
        Handle-WriteResult -Result $r -SuccessMsg "Deleted '$($sel.Name)'." -DryRunTitle 'Remove-RoleGroup (dry-run)'
        if (-not $script:DryRun -and $r -and -not $r.Error) { Load-ViewData -View 'RoleGroups' }
    }

    function Show-RoleCmdlets {
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select a role first.' 'warn'; return }
        try {
            $entries = Get-ManagementRoleEntry -Identity "$($sel.Name)\*" -ErrorAction Stop
            $names = foreach ($entry in $entries) { $entry.Name }
            $msg = ($names | Sort-Object) -join "`n"
            $null = [System.Windows.MessageBox]::Show($msg, "Cmdlets in role: $($sel.Name)", 'OK', 'Information')
        }
        catch { Set-Status "Could not list cmdlets: $($_.Exception.Message)" 'error' }
    }

    function Visualize-Selected {
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select an assignment first.' 'warn'; return }
        $a = if ($sel._raw) { $sel._raw } else { $sel }
        if (-not $a.Role -or -not $a.RoleAssignee) {
            Set-Status 'Selected row is not an assignment.' 'warn'; return
        }
        $script:VizAssignment = $a
        Switch-View -View 'Visualizer'
    }

    function Pick-VizAssignment {
        if (-not $script:Cache.Assignments) { $script:Cache.Assignments = Get-RBACRoleAssignments }
        $names = foreach ($asg in $script:Cache.Assignments) { $asg.Name }
        $names = @($names)
        if (@($names).Count -eq 0) { Set-Status 'No assignments loaded.' 'warn'; return }
        $sel = ($names | Out-GridView -Title 'Pick assignment to visualize' -OutputMode Single)
        if ($sel) {
            $script:VizAssignment = $script:Cache.Assignments | Where-Object { $_.Name -eq $sel } | Select-Object -First 1
            Render-Visualizer
            Set-Status "Visualizing $sel." 'ok'
        }
    }

    function Export-VizPng {
        $dlg = [System.Windows.Forms.SaveFileDialog]::new()
        $dlg.Filter = 'PNG (*.png)|*.png'
        $dlg.FileName = "rbac-viz-$(Get-Date -Format 'yyyyMMdd-HHmmss').png"
        if ($dlg.ShowDialog() -ne 'OK') { return }
        try {
            $cv = $UI.VizCanvas
            $rtb = [System.Windows.Media.Imaging.RenderTargetBitmap]::new(
                [int]$cv.ActualWidth, [int]$cv.ActualHeight, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
            $rtb.Render($cv)
            $enc = [System.Windows.Media.Imaging.PngBitmapEncoder]::new()
            $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
            $fs = [System.IO.File]::Open($dlg.FileName, 'Create')
            $enc.Save($fs); $fs.Close()
            Set-Status "Exported to $($dlg.FileName)." 'ok'
        }
        catch { Set-Status "Export failed: $($_.Exception.Message)" 'error' }
    }

    # ---------------- Connect / Disconnect ----------------
    function Do-Connect {
        try {
            Set-Status 'Connecting to Exchange Online…'
            $null = Connect-RBACExchangeOnline
            Update-ConnectionUI
            Set-Status 'Connected.' 'ok'
            if ($script:CurrentView) { Load-ViewData -View $script:CurrentView }
        }
        catch { Set-Status "Connect failed: $($_.Exception.Message)" 'error' }
    }
    function Do-Disconnect {
        try {
            $null = Disconnect-RBACExchange
            $script:Cache.Clear()
            $UI.MainGrid.ItemsSource = $null
            $UI.ItemCount.Text = '0 items'
            Update-ConnectionUI
            Set-Status 'Disconnected.' 'ok'
        }
        catch { Set-Status "Disconnect failed: $($_.Exception.Message)" 'error' }
    }

    # ---------------- Wire events ----------------
    $UI.BtnConnect.Add_Click({ Do-Connect })
    $UI.BtnDisconnect.Add_Click({ Do-Disconnect })
    $UI.BtnRefresh.Add_Click({ if ($script:CurrentView) { Load-ViewData -View $script:CurrentView } })
    $UI.BtnDryRun.Add_Click({ Toggle-DryRun })

    # Make ToggleButton click-only-go-on (prevent uncheck of active)
    $navBtns = @($UI.NavRoleGroups,$UI.NavRoles,$UI.NavAssignments,$UI.NavScopes,
                 $UI.NavUserRights,$UI.NavCommands,$UI.NavVisualizer,$UI.NavAudit)
    foreach ($btn in $navBtns) {
        $btn.Add_PreviewMouseDown({
            param($s,$e)
            if ($s.IsChecked) { $e.Handled = $true }
        })
    }
    $UI.NavRoleGroups.Add_Click({ Switch-View -View 'RoleGroups' })
    $UI.NavRoles.Add_Click({       Switch-View -View 'Roles' })
    $UI.NavAssignments.Add_Click({ Switch-View -View 'Assignments' })
    $UI.NavScopes.Add_Click({      Switch-View -View 'Scopes' })
    $UI.NavUserRights.Add_Click({  Switch-View -View 'UserRights' })
    $UI.NavCommands.Add_Click({    Switch-View -View 'Commands' })
    $UI.NavVisualizer.Add_Click({  Switch-View -View 'Visualizer' })
    $UI.NavAudit.Add_Click({       Switch-View -View 'Audit' })

    $UI.SearchBox.Add_KeyDown({
        param($s,$e)
        if ($e.Key -eq 'Return') { Apply-Search; $e.Handled = $true }
    })

    $UI.MainGrid.Add_SelectionChanged({
        $n = @($UI.MainGrid.SelectedItems).Count
        $UI.SelectionCount.Text = "$n selected"
        if ($n -eq 1) { Show-Details -Item $UI.MainGrid.SelectedItem } else { Hide-Details }
    })
    $UI.BtnDetailsClose.Add_Click({ Hide-Details })

    $UI.VizCanvas.Add_SizeChanged({ if ($script:CurrentView -eq 'Visualizer') { Render-Visualizer } })

    # ---------------- Visualizer pan + zoom ----------------
    $script:VizPan = @{ Active = $false; StartX = 0; StartY = 0; OrigX = 0; OrigY = 0 }
    $UI.VizCanvas.Add_MouseLeftButtonDown({
        param($s, $e)
        # Pan only when clicking the empty canvas (not a node)
        if ($e.Source -ne $s) { return }
        $p = $e.GetPosition($s)
        $script:VizPan.Active = $true
        $script:VizPan.StartX = $p.X; $script:VizPan.StartY = $p.Y
        if ($script:VizTranslate) {
            $script:VizPan.OrigX = $script:VizTranslate.X
            $script:VizPan.OrigY = $script:VizTranslate.Y
        }
        $null = $s.CaptureMouse()
        $s.Cursor = [System.Windows.Input.Cursors]::ScrollAll
    })
    $UI.VizCanvas.Add_MouseLeftButtonUp({
        param($s, $e)
        $script:VizPan.Active = $false
        $s.ReleaseMouseCapture()
        $s.Cursor = [System.Windows.Input.Cursors]::Arrow
    })
    $UI.VizCanvas.Add_MouseMove({
        param($s, $e)
        if (-not $script:VizPan.Active) { return }
        if (-not $script:VizTranslate)  { return }
        $p = $e.GetPosition($s)
        $script:VizTranslate.X = $script:VizPan.OrigX + ($p.X - $script:VizPan.StartX)
        $script:VizTranslate.Y = $script:VizPan.OrigY + ($p.Y - $script:VizPan.StartY)
    })
    $UI.VizCanvas.Add_MouseWheel({
        param($s, $e)
        if (-not $script:VizScale) { return }
        $factor = if ($e.Delta -gt 0) { 1.1 } else { 1 / 1.1 }
        $newScale = [Math]::Min([Math]::Max($script:VizScale.ScaleX * $factor, 0.2), 5.0)
        # Zoom centred on the mouse pointer for a natural feel
        $p = $e.GetPosition($s)
        $script:VizScale.CenterX = $p.X
        $script:VizScale.CenterY = $p.Y
        $script:VizScale.ScaleX = $newScale
        $script:VizScale.ScaleY = $newScale
        $e.Handled = $true
    })

    # ---------------- Initial state ----------------
    Update-ConnectionUI
    Update-ModeBadge
    Set-Status 'Ready. Connect to Exchange Online to load data.'
    Switch-View -View 'RoleGroups'

    $null = $window.ShowDialog()
    return
}
