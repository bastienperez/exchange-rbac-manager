function Invoke-ExchangeGUI {
    <#
    .SYNOPSIS
        Modern WPF GUI for Exchange RBAC Manager - wireframe-derived layout.
    .DESCRIPTION
        Sidebar (8 sections) + content head + toolbar + data area + action bar + status bar.
        Section 7 is the embedded RBAC Visualizer (hub-and-spoke).
        Section 8 is the Audit Log fed by Search-AdminAuditLog.

        READ-ONLY (current version): only browses, looks up and exports.
        Create / edit / delete actions are planned for the next version.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$Splash
    )

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
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="bd" Property="Opacity" Value="0.55"/>
                <Setter Property="Cursor" Value="No"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background"  Value="#F3F2F1"/>
          <Setter Property="BorderBrush" Value="#A19F9D"/>
        </Trigger>
        <Trigger Property="IsPressed" Value="True">
          <Setter Property="Background" Value="#EDEBE9"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="PrimaryBtn" TargetType="Button" BasedOn="{StaticResource ActionBtn}">
      <Setter Property="Background"  Value="#0078D4"/>
      <Setter Property="Foreground"  Value="White"/>
      <Setter Property="BorderBrush" Value="#0078D4"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background"  Value="#106EBE"/>
          <Setter Property="BorderBrush" Value="#106EBE"/>
        </Trigger>
        <Trigger Property="IsPressed" Value="True">
          <Setter Property="Background"  Value="#005A9E"/>
          <Setter Property="BorderBrush" Value="#005A9E"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style x:Key="WarnBtn" TargetType="Button" BasedOn="{StaticResource ActionBtn}">
      <Setter Property="Foreground"  Value="#A4262C"/>
      <Setter Property="BorderBrush" Value="#F1B0B0"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background"  Value="#FDF3F4"/>
          <Setter Property="BorderBrush" Value="#A4262C"/>
        </Trigger>
      </Style.Triggers>
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
      <Setter Property="CanUserResizeColumns" Value="True"/>
      <Setter Property="CanUserResizeRows" Value="False"/>
      <Setter Property="CanUserSortColumns" Value="True"/>
      <Setter Property="CanUserReorderColumns" Value="False"/>
      <Setter Property="AlternatingRowBackground" Value="#FAF9F8"/>
    </Style>
    <Style TargetType="DataGridColumnHeader">
      <Setter Property="Background" Value="#F8F8F8"/>
      <Setter Property="Foreground" Value="#323130"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="MinHeight" Value="40"/>
      <Setter Property="Padding" Value="14,8,14,8"/>
      <Setter Property="BorderBrush" Value="#0078D4"/>
      <Setter Property="BorderThickness" Value="0,0,0,2"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="SeparatorBrush" Value="#E1DFDD"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#EFF6FC"/>
          <Setter Property="Foreground" Value="#0078D4"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="DataGridRow">
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="#DEECF9"/>
          <Setter Property="Foreground" Value="#201F1E"/>
        </Trigger>
        <DataTrigger Binding="{Binding Enabled}" Value="False">
          <Setter Property="Foreground" Value="#A19F9D"/>
          <Setter Property="FontStyle" Value="Italic"/>
        </DataTrigger>
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
            <TextBlock x:Name="TenantLabel" Text="TENANT" Foreground="White" FontFamily="Consolas" FontSize="10" Opacity="0.85"/>
            <TextBlock x:Name="TenantName" Text="" Foreground="White" FontSize="13"
                       Margin="0,2,0,4" TextTrimming="CharacterEllipsis"/>
            <StackPanel Orientation="Horizontal">
              <Ellipse x:Name="ConnPulse" Width="8" Height="8" Fill="#E6C4C4" VerticalAlignment="Center"/>
              <TextBlock x:Name="ConnStatus" Text="disconnected" Foreground="White"
                         FontFamily="Consolas" FontSize="11" Margin="6,0,0,0"/>
            </StackPanel>
            <CheckBox x:Name="ChkUseWAM" Content="Use WAM (broker)" Foreground="White" Margin="0,8,0,0"
                      IsChecked="True"
                      ToolTip="Web Account Manager is the default broker in ExchangeOnlineManagement 3.7.0+. Uncheck to pass -DisableWAM."/>
            <Button x:Name="BtnConnect" Content="Connect to Exchange Online" Margin="0,8,0,0" Height="30"
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
                     FontFamily="Consolas" FontSize="11"/>
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
          <!-- Read-only badge: current version only supports browsing / lookup / export.
               Create / edit / delete actions are planned for the next version. -->
          <Border Grid.Column="1" VerticalAlignment="Top" Padding="8,3" CornerRadius="11"
                  Background="#FFF4CE" BorderBrush="#D29200" BorderThickness="1"
                  ToolTip="Read-only in this version. Create / edit / delete actions are coming in the next release.">
            <TextBlock Text="READ-ONLY · v1" FontFamily="Consolas" FontSize="10"
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
          <Border x:Name="SearchHost" Grid.Column="0" BorderBrush="#C8C6C4" BorderThickness="1" CornerRadius="2"
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
          <Popup x:Name="SuggestPopup"
                 Placement="Bottom" StaysOpen="False" AllowsTransparency="True"
                 PopupAnimation="Fade" IsOpen="False">
            <Border Background="White" BorderBrush="#C8C6C4" BorderThickness="1" CornerRadius="2"
                    Width="280" MaxHeight="260">
              <Border.Effect>
                <DropShadowEffect BlurRadius="10" ShadowDepth="2" Opacity="0.15"/>
              </Border.Effect>
              <ListBox x:Name="SuggestList" BorderThickness="0" FontSize="12"
                       ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
            </Border>
          </Popup>
          <ItemsControl x:Name="ChipsHost" Grid.Column="1" Margin="12,0,12,0" VerticalAlignment="Center">
            <ItemsControl.ItemsPanel>
              <ItemsPanelTemplate><WrapPanel Orientation="Horizontal"/></ItemsPanelTemplate>
            </ItemsControl.ItemsPanel>
          </ItemsControl>
          <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="0,0,8,0">
            <Button x:Name="BtnFilterRow" Content="Filter: off" Style="{StaticResource ActionBtn}" Margin="0,0,6,0"
                    ToolTip="Toggle a filter input in each column header"/>
            <Button x:Name="BtnWrap" Content="Wrap: on" Style="{StaticResource ActionBtn}" Margin="0,0,6,0"
                    ToolTip="Toggle text wrapping on long cells"/>
            <Button x:Name="BtnAutoFit" Content="Auto-fit" Style="{StaticResource ActionBtn}" Margin="0,0,6,0"
                    ToolTip="Resize columns to fit current content"/>
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
        [int]$iconSize = 32
        [double]$cx       = $iconSize / 2.0
        [double]$cy       = $iconSize / 2.0
        [double]$hubR     = $iconSize * 0.13
        [double]$spokeR   = $iconSize * 0.094
        [double]$radius   = $iconSize * 0.18
        [double]$strokeThickness = [Math]::Max(1.0, $iconSize * 0.045)

        $dv = [System.Windows.Media.DrawingVisual]::new()
        $ctx = $dv.RenderOpen()

        $bgBrush = [System.Windows.Media.SolidColorBrush]::new(
            [System.Windows.Media.ColorConverter]::ConvertFromString('#0078D4'))
        $ctx.DrawRoundedRectangle($bgBrush, $null,
            [System.Windows.Rect]::new(0, 0, $iconSize, $iconSize), $radius, $radius)

        $whiteBrush = [System.Windows.Media.SolidColorBrush]::new(
            [System.Windows.Media.Colors]::White)
        $pen = [System.Windows.Media.Pen]::new($whiteBrush, $strokeThickness)

        $spokes = @(
            ,@([double]($iconSize * 0.19), [double]($iconSize * 0.22))
            ,@([double]($iconSize * 0.81), [double]($iconSize * 0.22))
            ,@([double]($iconSize * 0.50), [double]($iconSize * 0.81))
        )
        foreach ($p in $spokes) {
            $ctx.DrawLine($pen,
                [System.Windows.Point]::new($cx, $cy),
                [System.Windows.Point]::new($p[0], $p[1]))
        }
        $ctx.DrawEllipse($whiteBrush, $null,
            [System.Windows.Point]::new($cx, $cy), $hubR, $hubR)
        foreach ($p in $spokes) {
            $ctx.DrawEllipse($whiteBrush, $null,
                [System.Windows.Point]::new($p[0], $p[1]), $spokeR, $spokeR)
        }
        $ctx.Close()

        $rtb = [System.Windows.Media.Imaging.RenderTargetBitmap]::new(
            $iconSize, $iconSize, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
        $rtb.Render($dv)
        $rtb.Freeze()
        # Wrapping in a BitmapFrame is required for Window.Icon to be picked up
        # reliably by the Windows 11 taskbar.
        $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create($rtb)
    }
    catch { Write-Warning "Icon generation skipped: $_" }

    # ---------------- UI lookup helpers ----------------
    $UI = @{}
    foreach ($n in @(
            'TenantLabel','TenantName','ConnPulse','ConnStatus','BtnConnect','BtnDisconnect','ChkUseWAM','VersionLabel',
            'NavRoleGroups','NavRoles','NavAssignments','NavScopes','NavUserRights','NavCommands','NavVisualizer','NavAudit',
            'Crumbs','ViewTitle','ViewDesc','SearchHost','SearchBox','SuggestPopup','SuggestList','ChipsHost','BtnRefresh','BtnFilterRow','BtnWrap','BtnAutoFit','ItemCount',
            'MainGrid','VizHost','VizCanvas','VizScroll','VizPlaceholder',
            'DetailsCol','DetailsPanel','DetailsTitle','DetailsList','BtnDetailsClose',
            'SelectionCount','ActionsHost',
            'StatusDot','StatusText','StatusSep','StatusItems','StatusVersion'
        )) { $UI[$n] = $window.FindName($n) }

    # Wire the suggestion Popup's PlacementTarget in code: doing it via a XAML
    # ElementName binding fails because Popup creates its own NameScope.
    if ($UI.SuggestPopup -and $UI.SearchHost) {
        $UI.SuggestPopup.PlacementTarget = $UI.SearchHost
    }

    $script:CurrentView   = $null
    $script:Cache         = @{}        # cached collections per view
    $script:ActiveChip    = @{}        # active chip label per view
    $script:CurrentChips  = @()        # chip labels for the current view
    $script:VizAssignment = $null      # currently visualized assignment

    # Module versions (sidebar = this module, status bar = ExchangeOnlineManagement)
    $modVer = Get-RBACModuleVersion
    $verStr = if ($modVer) { "v$($modVer.ToString())" } else { 'v?' }
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
            $UI.TenantLabel.Visibility   = 'Visible'
            $UI.TenantName.Visibility    = 'Visible'
            try {
                $info = Get-ConnectionInformation -ErrorAction SilentlyContinue | Select-Object -First 1
                $label = $null
                if ($info) {
                    foreach ($prop in 'Organization','UserPrincipalName','TenantId','ConnectionUri') {
                        $val = "$($info.$prop)".Trim()
                        if (-not [string]::IsNullOrEmpty($val)) { $label = $val; break }
                    }
                }
                if ([string]::IsNullOrEmpty($label)) { $label = 'Exchange Online' }
                $UI.TenantName.Text = $label
            } catch { }
        }
        else {
            $UI.ConnStatus.Text = 'disconnected'
            $UI.ConnPulse.Fill  = '#E6C4C4'
            $UI.TenantName.Text = ''
            $UI.TenantLabel.Visibility   = 'Collapsed'
            $UI.TenantName.Visibility    = 'Collapsed'
            $UI.BtnConnect.Visibility    = 'Visible'
            $UI.BtnDisconnect.Visibility = 'Collapsed'
        }
    }

    # ---------------- Chip / Action factories ----------------
    function New-Chip {
        param([string]$Label, [switch]$On)
        $b = [System.Windows.Controls.Border]::new()
        $b.CornerRadius = '11'; $b.BorderThickness = '1'; $b.Margin = '0,2,6,2'; $b.Padding = '10,4'; $b.Height = 22
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

    # ---------------- View descriptors ----------------
    # Badge palettes used across views. Keys are matched against the bound source
    # value via DataTrigger, so the comparison is exact-match and case-sensitive.
    # Values not in a palette render as plain text without a badge background.
    $BadgeOrigin = @{
        'Built-in' = @{ Bg='#DEF7E0'; Fg='#1B5E20' }
        'Custom'   = @{ Bg='#E3F2FD'; Fg='#0D47A1' }
        'Implicit' = @{ Bg='#ECEFF1'; Fg='#37474F' }
    }
    $BadgeAssigneeType = @{
        'User'                 = @{ Bg='#E3F2FD'; Fg='#0D47A1' }
        'RoleGroup'            = @{ Bg='#FFF3E0'; Fg='#E65100' }
        'SecurityGroup'        = @{ Bg='#F3E5F5'; Fg='#6A1B9A' }
        'RoleAssignmentPolicy' = @{ Bg='#E0F7FA'; Fg='#006064' }
        'Computer'             = @{ Bg='#ECEFF1'; Fg='#37474F' }
    }
    $BadgeScopeType = @{
        'Recipient'          = @{ Bg='#E3F2FD'; Fg='#0D47A1' }
        'Server'             = @{ Bg='#FFF3E0'; Fg='#E65100' }
        'Implicit'           = @{ Bg='#ECEFF1'; Fg='#37474F' }
        'Custom'             = @{ Bg='#DEF7E0'; Fg='#1B5E20' }
        'OrganizationConfig' = @{ Bg='#ECEFF1'; Fg='#37474F' }
        'MyGAL'              = @{ Bg='#F3E5F5'; Fg='#6A1B9A' }
    }
    $BadgeRoleType = @{
        'UnScoped' = @{ Bg='#E3F2FD'; Fg='#0D47A1' }
        'Role'     = @{ Bg='#ECEFF1'; Fg='#37474F' }
    }

    $script:Views = @{
        RoleGroups = @{
            Crumbs = 'RBAC ▸ Role Groups'
            Title  = 'Role Groups'
            Desc   = 'Universal Security Groups that bundle roles, members and scopes.'
            Chips  = @('all','built-in','custom')
            FrozenColumns = 1
            Columns = @(
                @{ Header='Name';        Path='Name';        Width=240; MinWidth=120 }
                @{ Header='Description'; Path='Description'; Width='*'; MinWidth=200 }
                @{ Header='Members';     Path='MemberCount'; Width=90;  MinWidth=70; Align='Right'; Format='N0' }
                @{ Header='Roles';       Path='RoleCount';   Width=80;  MinWidth=60; Align='Right'; Format='N0' }
            )
        }
        Roles = @{
            Crumbs = 'RBAC ▸ Management Roles'
            Title  = 'Roles'
            Desc   = 'Containers of cmdlets and parameters that grant capabilities.'
            Chips  = @('all','built-in','custom','unassigned')
            FrozenColumns = 1
            Columns = @(
                @{ Header='Role Name';   Path='Name';        Width=240; MinWidth=140 }
                @{ Header='Type';        Path='RoleType';    Width=140; MinWidth=100; Kind='Badge'; BadgeMap=$BadgeRoleType }
                @{ Header='Origin';      Path='Origin';      Width=100; MinWidth=90;  Kind='Badge'; BadgeMap=$BadgeOrigin }
                @{ Header='Parent Role'; Path='Parent';      Width=180; MinWidth=120 }
                @{ Header='Description'; Path='Description'; Width='*'; MinWidth=200 }
            )
        }
        Assignments = @{
            Crumbs = 'RBAC ▸ Role Assignments'
            Title  = 'Role Assignments'
            Desc   = 'Bindings of Role + Assignee + Scope.'
            Chips  = @('all','enabled','disabled')
            FrozenColumns = 1
            Columns = @(
                @{ Header='Assignment Name'; Path='Name';                Width=260; MinWidth=160 }
                @{ Header='Role';            Path='Role';                Width=200; MinWidth=140 }
                @{ Header='Assignee';        Path='RoleAssignee';        Width=180; MinWidth=120 }
                @{ Header='Type';            Path='RoleAssigneeType';    Width=130; MinWidth=110; Kind='Badge'; BadgeMap=$BadgeAssigneeType }
                @{ Header='Read Scope';      Path='RecipientReadScope';  Width='*'; MinWidth=140 }
                @{ Header='Write Scope';     Path='RecipientWriteScope'; Width='*'; MinWidth=140 }
            )
        }
        Scopes = @{
            Crumbs = 'RBAC ▸ Management Scopes'
            Title  = 'Scopes'
            Desc   = 'Where a role applies - recipient or server filters.'
            Chips  = @('all','implicit','custom','recipient','server')
            FrozenColumns = 1
            Columns = @(
                @{ Header='Scope Name';       Path='Name';                  Width=220; MinWidth=140 }
                @{ Header='Type';             Path='ScopeRestrictionType';  Width=160; MinWidth=130; Kind='Badge'; BadgeMap=$BadgeScopeType }
                @{ Header='OU';               Path='RecipientRoot';         Width=200; MinWidth=140 }
                @{ Header='Recipient Filter'; Path='FilterSummary';         Width='*'; MinWidth=160 }
            )
        }
        UserRights = @{
            Crumbs = 'RBAC ▸ User Rights'
            Title  = 'User Rights'
            Desc   = 'Effective permissions for a user - what they can run, where.'
            Chips  = @('expand role groups','show scopes')
            FrozenColumns = 1
            Columns = @(
                @{ Header='User';        Path='User';        Width=240; MinWidth=160 }
                @{ Header='Role';        Path='Role';        Width=220; MinWidth=140 }
                @{ Header='Granted Via'; Path='Via';         Width=200; MinWidth=140 }
                @{ Header='Read Scope';  Path='ReadScope';   Width=180; MinWidth=130 }
                @{ Header='Write Scope'; Path='WriteScope';  Width='*'; MinWidth=130 }
            )
        }
        Commands = @{
            Crumbs = 'RBAC ▸ Command Lookup'
            Title  = 'Command Lookup'
            Desc   = 'Reverse lookup: which roles grant a given cmdlet?'
            Chips  = @()
            FrozenColumns = 1
            Columns = @(
                @{ Header='Role';        Path='RoleName';    Width=240; MinWidth=140 }
                @{ Header='Type';        Path='RoleType';    Width=140; MinWidth=100; Kind='Badge'; BadgeMap=$BadgeRoleType }
                @{ Header='Origin';      Path='Origin';      Width=120; MinWidth=100; Kind='Badge'; BadgeMap=$BadgeOrigin }
                @{ Header='Description'; Path='Description'; Width='*'; MinWidth=200 }
            )
        }
        Visualizer = @{
            Crumbs = 'RBAC ▸ Visualizer'
            Title  = 'RBAC Visualizer · hub-and-spoke'
            Desc   = 'One assignment in the centre, three spokes out: Role · Assignee · Scope.'
            Chips  = @()
            FrozenColumns = 0
            Columns = @()
        }
        Audit = @{
            Crumbs = 'RBAC ▸ Audit Log'
            Title  = 'Audit Log'
            Desc   = 'Recent RBAC changes from Search-AdminAuditLog.'
            Chips  = @('last 7 days','last 30 days','last 90 days')
            FrozenColumns = 1
            Columns = @(
                @{ Header='Timestamp';   Path='Timestamp';  Width=170; MinWidth=160 }
                @{ Header='Caller';      Path='Caller';     Width=200; MinWidth=140 }
                @{ Header='Cmdlet';      Path='Cmdlet';     Width=220; MinWidth=140 }
                @{ Header='Object';      Path='Object';     Width=220; MinWidth=140 }
                @{ Header='Parameters';  Path='Parameters'; Width='*'; MinWidth=200 }
            )
        }
    }

    # ---------------- Grid configuration ----------------
    $script:ColumnFilters       = @{}
    $script:FilterRowEnabled    = $false
    $script:WrapEnabled         = $true
    $script:FilterDebounceTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $script:FilterDebounceTimer.Interval = [TimeSpan]::FromMilliseconds(250)
    $script:FilterDebounceTimer.Add_Tick({
        $script:FilterDebounceTimer.Stop()
        Apply-Filters
    })

    function Schedule-FilterApply {
        $script:FilterDebounceTimer.Stop()
        $script:FilterDebounceTimer.Start()
    }

    function New-Brush {
        param([string]$Hex)
        New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($Hex))
    }

    function Test-ContainsCI {
        # Case-insensitive literal substring match. Avoids -like wildcard surprises
        # (*, ?, [...]) when the input comes from a free-text filter input.
        param([string]$Haystack, [string]$Needle)
        if ([string]::IsNullOrEmpty($Needle))   { return $true }
        if ([string]::IsNullOrEmpty($Haystack)) { return $false }
        return ($Haystack.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
    }

    function Set-GridColumns {
        param([array]$Columns)
        $UI.MainGrid.Columns.Clear()

        foreach ($c in $Columns) {
            $col = [System.Windows.Controls.DataGridTextColumn]::new()
            $col.MinWidth        = if ($c.MinWidth) { [double]$c.MinWidth } else { 60.0 }
            $col.CanUserResize   = $true
            $col.CanUserSort     = $true
            $col.SortMemberPath  = $c.Path

            # ---- Header: label + optional filter TextBox ----
            $headerPanel = [System.Windows.Controls.StackPanel]::new()
            $headerPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical
            $headerLabel = [System.Windows.Controls.TextBlock]::new()
            $headerLabel.Text       = ([string]$c.Header).ToUpperInvariant()
            $headerLabel.FontWeight = [System.Windows.FontWeights]::SemiBold
            $headerLabel.FontSize   = 11
            $headerLabel.Foreground = (New-Brush '#323130')
            # Mirror the cell alignment in the header so numeric columns line up.
            if ($c.Align -eq 'Right') {
                $headerLabel.TextAlignment = [System.Windows.TextAlignment]::Right
                $headerPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
            }
            $null = $headerPanel.Children.Add($headerLabel)
            if ($script:FilterRowEnabled) {
                $fbox = [System.Windows.Controls.TextBox]::new()
                $fbox.Margin     = '0,4,0,0'
                $fbox.MinHeight  = 22
                $fbox.FontSize   = 11
                $fbox.FontWeight = [System.Windows.FontWeights]::Normal
                $fbox.Foreground = (New-Brush '#201F1E')
                $fbox.ToolTip    = 'Filter (contains)'
                $fbox.Tag        = $c.Path
                if ($script:ColumnFilters.ContainsKey($c.Path)) { $fbox.Text = [string]$script:ColumnFilters[$c.Path] }
                $fbox.Add_TextChanged({
                    param($s, $e)
                    $key = [string]$s.Tag
                    $val = [string]$s.Text
                    if ([string]::IsNullOrEmpty($val)) {
                        if ($script:ColumnFilters.ContainsKey($key)) { $null = $script:ColumnFilters.Remove($key) }
                    }
                    else { $script:ColumnFilters[$key] = $val }
                    Schedule-FilterApply
                })
                $null = $headerPanel.Children.Add($fbox)
            }
            $col.Header = $headerPanel

            # Push the header content (StackPanel) to the right edge of the column header
            # cell when the column is right-aligned, so the label sits above its numbers.
            # BasedOn the implicit DataGridColumnHeader style so right-aligned columns keep
            # the global look (hover, accent border, padding…).
            if ($c.Align -eq 'Right') {
                $baseStyle = $UI.MainGrid.TryFindResource(
                    [System.Windows.Controls.Primitives.DataGridColumnHeader])
                $hStyle = [System.Windows.Style]::new(
                    [System.Windows.Controls.Primitives.DataGridColumnHeader],
                    $baseStyle)
                $hStyle.Setters.Add([System.Windows.Setter]::new(
                    [System.Windows.Controls.Primitives.DataGridColumnHeader]::HorizontalContentAlignmentProperty,
                    [System.Windows.HorizontalAlignment]::Right))
                $col.HeaderStyle = $hStyle
            }

            # ---- Width ----
            if ($c.Width -eq '*') {
                $col.Width = [System.Windows.Controls.DataGridLength]::new(1, [System.Windows.Controls.DataGridLengthUnitType]::Star)
            }
            else {
                $col.Width = [System.Windows.Controls.DataGridLength]::new([double]$c.Width)
            }

            # ---- Binding (with optional StringFormat) ----
            $binding = [System.Windows.Data.Binding]::new($c.Path)
            if ($c.Format) { $binding.StringFormat = "{0:$($c.Format)}" }
            $col.Binding = $binding

            # ---- Cell ElementStyle (TextBlock) ----
            $eStyle = [System.Windows.Style]::new([System.Windows.Controls.TextBlock])

            # Wrap vs ellipsis
            if ($script:WrapEnabled) {
                $eStyle.Setters.Add([System.Windows.Setter]::new(
                    [System.Windows.Controls.TextBlock]::TextWrappingProperty,
                    [System.Windows.TextWrapping]::Wrap))
            }
            else {
                $eStyle.Setters.Add([System.Windows.Setter]::new(
                    [System.Windows.Controls.TextBlock]::TextTrimmingProperty,
                    [System.Windows.TextTrimming]::CharacterEllipsis))
            }

            # Right alignment for numeric columns
            if ($c.Align -eq 'Right') {
                $eStyle.Setters.Add([System.Windows.Setter]::new(
                    [System.Windows.Controls.TextBlock]::TextAlignmentProperty,
                    [System.Windows.TextAlignment]::Right))
            }

            # Tooltip with full value (helpful when ellipsis truncates)
            $tt = [System.Windows.Data.Binding]::new($c.Path)
            $eStyle.Setters.Add([System.Windows.Setter]::new(
                [System.Windows.Controls.ToolTipService]::ToolTipProperty, $tt))

            # Empty/null → "-" placeholder, subdued. Two DataTriggers: one for null source,
            # one for empty string. WPF DataTrigger does an exact-equals against Value so
            # we need both to cover real-world data.
            foreach ($missingValue in @($null, '')) {
                $dt = [System.Windows.DataTrigger]::new()
                $dt.Binding = [System.Windows.Data.Binding]::new($c.Path)
                $dt.Value   = $missingValue
                $dt.Setters.Add([System.Windows.Setter]::new(
                    [System.Windows.Controls.TextBlock]::TextProperty, [string]'-'))
                $dt.Setters.Add([System.Windows.Setter]::new(
                    [System.Windows.Controls.TextBlock]::ForegroundProperty, (New-Brush '#A19F9D')))
                $eStyle.Triggers.Add($dt)
            }

            # Badge: colorise per known value (also a DataTrigger on the bound source value)
            if ($c.Kind -eq 'Badge' -and $c.BadgeMap) {
                $eStyle.Setters.Add([System.Windows.Setter]::new(
                    [System.Windows.Controls.TextBlock]::PaddingProperty,
                    [System.Windows.Thickness]::new(8, 2, 8, 2)))
                $eStyle.Setters.Add([System.Windows.Setter]::new(
                    [System.Windows.FrameworkElement]::HorizontalAlignmentProperty,
                    [System.Windows.HorizontalAlignment]::Left))
                $eStyle.Setters.Add([System.Windows.Setter]::new(
                    [System.Windows.FrameworkElement]::VerticalAlignmentProperty,
                    [System.Windows.VerticalAlignment]::Center))
                foreach ($k in $c.BadgeMap.Keys) {
                    $palette = $c.BadgeMap[$k]
                    $bDT = [System.Windows.DataTrigger]::new()
                    $bDT.Binding = [System.Windows.Data.Binding]::new($c.Path)
                    $bDT.Value   = [string]$k
                    $bDT.Setters.Add([System.Windows.Setter]::new(
                        [System.Windows.Controls.TextBlock]::BackgroundProperty, (New-Brush $palette.Bg)))
                    $bDT.Setters.Add([System.Windows.Setter]::new(
                        [System.Windows.Controls.TextBlock]::ForegroundProperty, (New-Brush $palette.Fg)))
                    $bDT.Setters.Add([System.Windows.Setter]::new(
                        [System.Windows.Controls.TextBlock]::FontWeightProperty,
                        [System.Windows.FontWeights]::SemiBold))
                    $eStyle.Triggers.Add($bDT)
                }
            }

            $col.ElementStyle = $eStyle
            $null = $UI.MainGrid.Columns.Add($col)
        }

        # Frozen columns + row height per wrap mode
        $cv = $script:Views[$script:CurrentView]
        if ($cv -and $cv.ContainsKey('FrozenColumns')) {
            $UI.MainGrid.FrozenColumnCount = [int]$cv.FrozenColumns
        }
        else {
            $UI.MainGrid.FrozenColumnCount = 0
        }
        if ($script:WrapEnabled) { $UI.MainGrid.RowHeight = [double]::NaN }
        else                     { $UI.MainGrid.RowHeight = 34.0 }
    }

    function Auto-FitColumns {
        if (-not $UI.MainGrid -or -not $UI.MainGrid.Columns) { return }
        # Pass 1: ask WPF to size each column to its content
        foreach ($col in $UI.MainGrid.Columns) {
            try {
                $col.Width = [System.Windows.Controls.DataGridLength]::new(1, [System.Windows.Controls.DataGridLengthUnitType]::Auto)
            } catch { }
        }
        # Force layout so ActualWidth is up to date, then snap to fixed width so the user can keep dragging
        $UI.MainGrid.UpdateLayout()
        foreach ($col in $UI.MainGrid.Columns) {
            try {
                $w = $col.ActualWidth
                if ($w -gt 0) {
                    $col.Width = [System.Windows.Controls.DataGridLength]::new([double]$w)
                }
            } catch { }
        }
    }

    function Toggle-FilterRow {
        $script:FilterRowEnabled = -not $script:FilterRowEnabled
        $UI.BtnFilterRow.Content = if ($script:FilterRowEnabled) { 'Filter: on' } else { 'Filter: off' }
        if (-not $script:FilterRowEnabled) {
            $script:ColumnFilters.Clear()
        }
        $cfg = $script:Views[$script:CurrentView]
        if ($cfg -and $cfg.Columns -and $cfg.Columns.Count -gt 0) {
            Set-GridColumns -Columns $cfg.Columns
        }
        Apply-Filters
    }

    function Toggle-Wrap {
        $script:WrapEnabled = -not $script:WrapEnabled
        $UI.BtnWrap.Content = if ($script:WrapEnabled) { 'Wrap: on' } else { 'Wrap: off' }
        $cfg = $script:Views[$script:CurrentView]
        if ($cfg -and $cfg.Columns -and $cfg.Columns.Count -gt 0) {
            Set-GridColumns -Columns $cfg.Columns
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
        # Scroll the viewport so the assignment hub sits in the middle of the
        # visible area. UpdateLayout() ensures ViewportWidth/Height are valid
        # right after the transform reset.
        $sv = $UI.VizScroll
        if ($sv -and $script:VizHubCanvasX) {
            $sv.UpdateLayout()
            $targetX = $script:VizHubCanvasX - $sv.ViewportWidth  / 2
            $targetY = $script:VizHubCanvasY - $sv.ViewportHeight / 2
            $sv.ScrollToHorizontalOffset([Math]::Max(0, $targetX))
            $sv.ScrollToVerticalOffset(  [Math]::Max(0, $targetY))
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
        # Remember the hub's centre on the canvas so the Center button can scroll
        # the viewport to bring the assignment back into view.
        $script:VizHubCanvasX = $cx + $offsetX
        $script:VizHubCanvasY = $cy + $offsetY
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
        $colFilters = @{}
        if ($script:ColumnFilters) {
            foreach ($k in $script:ColumnFilters.Keys) {
                $v = "$($script:ColumnFilters[$k])".Trim()
                if ($v -ne '') { $colFilters[$k] = $v }
            }
        }
        $filtered = foreach ($row in $src) {
            if (-not (Test-ChipMatch -Row $row -View $view -Chip $chip)) { continue }
            if ($q -ne '') {
                $hit = $false
                foreach ($p in $row.PSObject.Properties) {
                    if ($p.Name -like '_*') { continue }
                    $v = "$($p.Value)"
                    if (Test-ContainsCI -Haystack $v -Needle $q) { $hit = $true; break }
                }
                if (-not $hit) { continue }
            }
            if ($colFilters.Count -gt 0) {
                $allMatch = $true
                foreach ($cf in $colFilters.GetEnumerator()) {
                    $cellVal = "$($row.$($cf.Key))"
                    if (-not (Test-ContainsCI -Haystack $cellVal -Needle $cf.Value)) {
                        $allMatch = $false; break
                    }
                }
                if (-not $allMatch) { continue }
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

        # Reset per-column filters on view switch (different views have different paths)
        if ($script:ColumnFilters) { $script:ColumnFilters.Clear() }

        $UI.Crumbs.Text    = $cfg.Crumbs
        $UI.ViewTitle.Text = $cfg.Title
        $UI.ViewDesc.Text  = $cfg.Desc
        $UI.SearchBox.Text = ''
        if ($UI.SuggestPopup) { $UI.SuggestPopup.IsOpen = $false }
        $defaultChip = if ($cfg.Chips -and $cfg.Chips.Count -gt 0) { $cfg.Chips[0] } else { '' }
        Set-Chips -Labels $cfg.Chips -ActiveLabel $defaultChip
        $UI.ItemCount.Text = '0 items'
        $UI.SelectionCount.Text = '0 selected'
        Hide-Details

        # Switch table vs visualizer
        if ($View -eq 'Visualizer') {
            $UI.MainGrid.Visibility   = 'Collapsed'
            $UI.VizHost.Visibility    = 'Visible'
            # SearchBox has no effect on the canvas; hide it to avoid confusion.
            $UI.SearchHost.Visibility = 'Collapsed'
        }
        else {
            $UI.VizHost.Visibility    = 'Collapsed'
            $UI.MainGrid.Visibility   = 'Visible'
            $UI.SearchHost.Visibility = 'Visible'
            Set-GridColumns -Columns $cfg.Columns
        }

        # Action bar
        Set-Actions -Buttons (Get-ActionsForView -View $View)

        # Prefetch cmdlet suggestions so the first keystroke is instant.
        if ($View -eq 'Commands') { Ensure-CommandSuggestions }

        Load-ViewData -View $View
    }

    function Get-ActionsForView {
        param([string]$View)
        $list = @()
        switch ($View) {
            # NOTE: read-only mode - no create / edit / delete actions are exposed.
            'RoleGroups' {
                $list += (New-ActionButton -Label '↗ Export CSV'      -Style 'ActionBtn' -OnClick { Export-CurrentView })
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
        $assignments = @($script:Cache.Assignments)
        if ($assignments.Count -eq 0) { Set-Status 'No assignments loaded.' 'warn'; return }

        $rows = foreach ($a in $assignments) {
            [PSCustomObject]@{
                Name     = $a.Name
                Role     = $a.Role
                Assignee = $a.RoleAssignee
                Scope    = if ($a.RecipientWriteScope) { $a.RecipientWriteScope } else { 'Organization' }
                _raw     = $a
            }
        }

        $dlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Pick assignment to visualize"
        Width="780" Height="540" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" Background="#FAF9F8" ShowInTaskbar="False">
  <Grid Margin="14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <TextBlock Grid.Row="0" Text="Pick a role assignment" FontSize="18" FontWeight="SemiBold" Foreground="#201F1E"/>
    <Border Grid.Row="1" Margin="0,12,0,8" Padding="8,4" Background="White"
            BorderBrush="#C8C6C4" BorderThickness="1" CornerRadius="2" Height="32">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBlock Grid.Column="0" Text="⌕" Margin="2,0,8,0" Foreground="#605E5C" VerticalAlignment="Center"/>
        <TextBox x:Name="FilterBox" Grid.Column="1" BorderThickness="0" VerticalContentAlignment="Center"
                 Background="Transparent"/>
        <TextBlock x:Name="CountText" Grid.Column="2" Margin="8,0,2,0" Foreground="#605E5C"
                   FontFamily="Consolas" FontSize="11" VerticalAlignment="Center"/>
      </Grid>
    </Border>
    <ListView x:Name="List" Grid.Row="2" BorderBrush="#E1DFDD" BorderThickness="1" Background="White"
              SelectionMode="Single">
      <ListView.View>
        <GridView>
          <GridViewColumn Header="Name"     Width="240" DisplayMemberBinding="{Binding Name}"/>
          <GridViewColumn Header="Role"     Width="160" DisplayMemberBinding="{Binding Role}"/>
          <GridViewColumn Header="Assignee" Width="180" DisplayMemberBinding="{Binding Assignee}"/>
          <GridViewColumn Header="Scope"    Width="160" DisplayMemberBinding="{Binding Scope}"/>
        </GridView>
      </ListView.View>
    </ListView>
    <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
      <Button x:Name="BtnCancel" Content="Cancel" Width="90" Height="32" Margin="0,0,8,0"
              Background="White" BorderBrush="#C8C6C4" BorderThickness="1" Foreground="#201F1E" Cursor="Hand"/>
      <Button x:Name="BtnOK" Content="Visualize" Width="110" Height="32"
              Background="#0078D4" BorderBrush="#0078D4" BorderThickness="1" Foreground="White"
              FontWeight="SemiBold" Cursor="Hand" IsDefault="True"/>
    </StackPanel>
  </Grid>
</Window>
'@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($dlgXaml))
        $dlg    = [System.Windows.Markup.XamlReader]::Load($reader)
        $dlg.Owner = $window

        $list      = $dlg.FindName('List')
        $filterBox = $dlg.FindName('FilterBox')
        $countText = $dlg.FindName('CountText')
        $btnOK     = $dlg.FindName('BtnOK')
        $btnCancel = $dlg.FindName('BtnCancel')

        $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($rows)
        $list.ItemsSource = $rows
        $countText.Text   = "$($rows.Count) items"

        $applyFilter = {
            $needle = ([string]$filterBox.Text).Trim().ToLowerInvariant()
            if ([string]::IsNullOrEmpty($needle)) {
                $view.Filter = $null
            }
            else {
                $view.Filter = [Predicate[object]]{
                    param($it)
                    foreach ($prop in 'Name','Role','Assignee','Scope') {
                        $v = "$($it.$prop)".ToLowerInvariant()
                        if ($v.Contains($needle)) { return $true }
                    }
                    return $false
                }
            }
            $countText.Text = "$(@($view).Count) items"
        }

        $filterBox.Add_TextChanged({ & $applyFilter })

        $list.Add_MouseDoubleClick({
            param($s, $e)
            if ($list.SelectedItem) { $btnOK.RaiseEvent(
                [System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent)) }
        })

        $btnOK.Add_Click({ $dlg.DialogResult = $true; $dlg.Close() })
        $btnCancel.Add_Click({ $dlg.DialogResult = $false; $dlg.Close() })

        $filterBox.Focus() | Out-Null
        if ($rows.Count -gt 0) { $list.SelectedIndex = 0 }

        if ($dlg.ShowDialog() -eq $true -and $list.SelectedItem) {
            $script:VizAssignment = $list.SelectedItem._raw
            Render-Visualizer
            Set-Status "Visualizing $($list.SelectedItem.Name)." 'ok'
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
            $useWam = ($UI.ChkUseWAM.IsChecked -eq $true)
            $brokerLabel = if ($useWam) { 'WAM enabled' } else { 'WAM disabled' }
            Set-Status "Connecting to Exchange Online ($brokerLabel)…"

            # Force the UI to repaint before Connect-ExchangeOnline takes over the thread
            # (the auth flow blocks this dispatcher and would otherwise hide the status).
            $window.Dispatcher.Invoke(
                [action]{},
                [System.Windows.Threading.DispatcherPriority]::Render
            )

            $connectArgs = @{}
            if (-not $useWam) { $connectArgs['DisableWAM'] = $true }
            $null = Connect-RBACExchangeOnline @connectArgs
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
    $UI.BtnFilterRow.Add_Click({ Toggle-FilterRow })
    $UI.BtnWrap.Add_Click({ Toggle-Wrap })
    $UI.BtnAutoFit.Add_Click({ Auto-FitColumns })

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
        # Arrow keys / Enter on a visible suggestion list = list-driven nav
        if ($UI.SuggestPopup -and $UI.SuggestPopup.IsOpen -and $UI.SuggestList.Items.Count -gt 0) {
            switch ($e.Key) {
                'Down' {
                    $idx = $UI.SuggestList.SelectedIndex
                    if ($idx -lt ($UI.SuggestList.Items.Count - 1)) { $UI.SuggestList.SelectedIndex = $idx + 1 }
                    else { $UI.SuggestList.SelectedIndex = 0 }
                    $UI.SuggestList.ScrollIntoView($UI.SuggestList.SelectedItem)
                    $e.Handled = $true; return
                }
                'Up' {
                    $idx = $UI.SuggestList.SelectedIndex
                    if ($idx -gt 0) { $UI.SuggestList.SelectedIndex = $idx - 1 }
                    else { $UI.SuggestList.SelectedIndex = $UI.SuggestList.Items.Count - 1 }
                    $UI.SuggestList.ScrollIntoView($UI.SuggestList.SelectedItem)
                    $e.Handled = $true; return
                }
                'Return' {
                    if ($UI.SuggestList.SelectedItem) {
                        $UI.SearchBox.Text = [string]$UI.SuggestList.SelectedItem
                        $UI.SearchBox.CaretIndex = $UI.SearchBox.Text.Length
                        $UI.SuggestPopup.IsOpen = $false
                        Apply-Search
                        $e.Handled = $true; return
                    }
                }
                'Escape' { $UI.SuggestPopup.IsOpen = $false; $e.Handled = $true; return }
            }
        }
        if ($e.Key -eq 'Return') { Apply-Search; $e.Handled = $true }
    })

    # Build the cmdlet suggestion cache lazily on first need (Commands view).
    # Source = the EOM session's temporary proxy module (ModuleName from
    # Get-ConnectionInformation). Get-Command on that module is in-memory and
    # returns in milliseconds, unlike Get-ManagementRoleEntry which calls the
    # service for every role/cmdlet pair.
    function Ensure-CommandSuggestions {
        if ($script:CommandSuggestions -and $script:CommandSuggestions.Count -gt 0) { return }
        if (-not (Test-RBACExchangeConnection)) { return }
        try {
            $moduleNames = @(
                Get-ConnectionInformation -ErrorAction SilentlyContinue |
                    Where-Object { $_.ModuleName } |
                    Select-Object -ExpandProperty ModuleName -Unique
            )
            $list = @()
            if ($moduleNames.Count -gt 0) {
                $list = Get-Command -Module $moduleNames -ErrorAction SilentlyContinue |
                        Select-Object -ExpandProperty Name -Unique |
                        Sort-Object
            }
            $script:CommandSuggestions = @($list)
        }
        catch { $script:CommandSuggestions = @() }
    }

    function Update-SuggestPopup {
        if (-not $UI.SuggestPopup) { return }
        if ($script:CurrentView -ne 'Commands') { $UI.SuggestPopup.IsOpen = $false; return }
        $q = [string]$UI.SearchBox.Text
        if ([string]::IsNullOrWhiteSpace($q) -or $q.Length -lt 2) {
            $UI.SuggestPopup.IsOpen = $false; return
        }
        Ensure-CommandSuggestions
        if (-not $script:CommandSuggestions -or $script:CommandSuggestions.Count -eq 0) {
            $UI.SuggestPopup.IsOpen = $false; return
        }
        # Rank: starts-with first, then contains.
        $needle = $q.ToLowerInvariant()
        $starts = @(); $contains = @()
        foreach ($name in $script:CommandSuggestions) {
            $low = $name.ToLowerInvariant()
            if ($low.StartsWith($needle))    { $starts += $name }
            elseif ($low.Contains($needle))  { $contains += $name }
            if (($starts.Count + $contains.Count) -ge 50) { break }
        }
        $matches = @($starts) + @($contains) | Select-Object -First 30
        if ($matches.Count -eq 0) { $UI.SuggestPopup.IsOpen = $false; return }
        $UI.SuggestList.ItemsSource = $matches
        $UI.SuggestList.SelectedIndex = 0
        $UI.SuggestPopup.IsOpen = $true
    }

    $UI.SearchBox.Add_TextChanged({ Update-SuggestPopup })
    $UI.SearchBox.Add_LostFocus({
        if (-not $UI.SuggestPopup) { return }
        # Defer close so a click on the suggestion list isn't swallowed.
        $UI.SuggestPopup.Dispatcher.BeginInvoke(
            [action]{
                if ($UI.SuggestPopup -and -not $UI.SuggestList.IsKeyboardFocusWithin) {
                    $UI.SuggestPopup.IsOpen = $false
                }
            },
            [System.Windows.Threading.DispatcherPriority]::Background) | Out-Null
    })
    $UI.SuggestList.Add_MouseLeftButtonUp({
        if ($UI.SuggestList.SelectedItem) {
            $UI.SearchBox.Text = [string]$UI.SuggestList.SelectedItem
            $UI.SearchBox.CaretIndex = $UI.SearchBox.Text.Length
            $UI.SuggestPopup.IsOpen = $false
            Apply-Search
        }
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
    Set-Status 'Ready. Connect to Exchange Online to load data.'
    Switch-View -View 'RoleGroups'

    # Dismiss the splash once the main window is fully rendered so the user
    # never sees a gap between splash close and main window paint.
    if ($Splash) {
        $splashRef = $Splash
        $window.Add_ContentRendered({
            try { $splashRef.Close() } catch { }
        }.GetNewClosure())
    }

    $null = $window.ShowDialog()
    return
}
