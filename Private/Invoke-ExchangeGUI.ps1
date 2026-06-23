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
    <!-- Single chrome surface used by toolbar, action bar, details panel and Visualizer host. -->
    <SolidColorBrush x:Key="ToolbarBg"   Color="#F8F8F8"/>
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
            <!-- Thin margin on the right so the active "pill" doesn't bleed into the content area. -->
            <Border x:Name="bd" Background="{TemplateBinding Background}" Padding="18,0" Margin="0,1,0,1"
                    CornerRadius="0">
              <Grid>
                <TextBlock x:Name="lbl" Text="{TemplateBinding Content}"
                           Foreground="White" VerticalAlignment="Center"/>
                <Border x:Name="active" HorizontalAlignment="Left" Width="3" Background="#0078D4" Opacity="0" Margin="-18,0,0,0"/>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#0064B0"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="bd" Property="Background" Value="White"/>
                <Setter TargetName="bd" Property="CornerRadius" Value="6,0,0,6"/>
                <Setter TargetName="bd" Property="Margin" Value="8,1,0,1"/>
                <Setter TargetName="bd" Property="Padding" Value="10,0"/>
                <Setter TargetName="lbl" Property="Foreground" Value="#0078D4"/>
                <Setter TargetName="active" Property="Opacity" Value="1"/>
                <Setter TargetName="active" Property="Margin" Value="-10,0,0,0"/>
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
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4" Padding="{TemplateBinding Padding}">
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

    <!-- Compact pill button used inside the floating contextual action bar. -->
    <Style x:Key="BtnDark" TargetType="Button">
      <Setter Property="Background"  Value="Transparent"/>
      <Setter Property="Foreground"  Value="#201F1E"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="10,4"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="FontWeight" Value="Medium"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="6"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#F3F2F1"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Destructive variant - red text on light surface, soft red on hover. -->
    <Style x:Key="BtnDarkDanger" TargetType="Button" BasedOn="{StaticResource BtnDark}">
      <Setter Property="Foreground" Value="#A4262C"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="6"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#FDF3F4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <!-- Stateful toggle (Filter, Wrap…). Same template as ActionBtn but reacts to IsChecked. -->
    <Style x:Key="ToggleActionBtn" TargetType="ToggleButton">
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
          <ControlTemplate TargetType="ToggleButton">
            <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background"  Value="#F3F2F1"/>
          <Setter Property="BorderBrush" Value="#A19F9D"/>
        </Trigger>
        <Trigger Property="IsChecked" Value="True">
          <Setter Property="Background"  Value="#DEECF9"/>
          <Setter Property="BorderBrush" Value="#0078D4"/>
          <Setter Property="Foreground"  Value="#0078D4"/>
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
      <Setter Property="AlternatingRowBackground" Value="#FCFCFC"/>
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
      <Setter Property="BorderThickness" Value="3,0,0,0"/>
      <Setter Property="BorderBrush" Value="Transparent"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#F5FBFF"/>
        </Trigger>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background"  Value="#DEECF9"/>
          <Setter Property="Foreground"  Value="#201F1E"/>
          <Setter Property="BorderBrush" Value="#0078D4"/>
        </Trigger>
        <DataTrigger Binding="{Binding Enabled}" Value="False">
          <Setter Property="Foreground" Value="#A19F9D"/>
          <Setter Property="FontStyle" Value="Italic"/>
        </DataTrigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="DataGridCell">
      <Setter Property="Padding" Value="14,6,14,6"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="DataGridCell">
            <Border Padding="{TemplateBinding Padding}"
                    Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}">
              <ContentPresenter VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="Transparent"/>
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
    <Border Grid.Column="0">
      <Border.Background>
        <SolidColorBrush Color="#106EBE"/>
      </Border.Background>
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
            <StackPanel Orientation="Horizontal" Margin="0,8,0,0" VerticalAlignment="Center">
              <CheckBox x:Name="ChkUseWAM" Content="Use WAM (broker)" Foreground="White"
                        IsChecked="False" VerticalAlignment="Center"/>
              <Button x:Name="BtnWamInfo" Margin="6,0,0,0" Padding="0"
                      Background="Transparent" BorderThickness="0" Cursor="Hand"
                      ToolTip="What is WAM?">
                <Button.Template>
                  <ControlTemplate TargetType="Button">
                    <TextBlock x:Name="lbl" Text="&#xE946;" FontFamily="Segoe MDL2 Assets"
                               Foreground="#DEECF9" FontSize="14"
                               VerticalAlignment="Center" HorizontalAlignment="Center"/>
                    <ControlTemplate.Triggers>
                      <Trigger Property="IsMouseOver" Value="True">
                        <Setter TargetName="lbl" Property="Foreground" Value="White"/>
                      </Trigger>
                    </ControlTemplate.Triggers>
                  </ControlTemplate>
                </Button.Template>
              </Button>
            </StackPanel>
            <Button x:Name="BtnConnect" Content="Connect to Exchange Online" Margin="0,8,0,0" Height="30"
                    Background="White" Foreground="#0078D4" BorderThickness="0" FontWeight="SemiBold" Cursor="Hand"/>
            <Button x:Name="BtnDisconnect" Content="Disconnect" Margin="0,4,0,0" Height="28"
                    Background="Transparent" Foreground="White" BorderBrush="White" BorderThickness="1"
                    Cursor="Hand" Visibility="Collapsed"/>
          </StackPanel>
        </Border>

        <StackPanel Grid.Row="2" Margin="0,0,0,0">
          <ToggleButton x:Name="NavRoleGroups"  Style="{StaticResource NavButton}" Content="◈   Role Groups"/>
          <ToggleButton x:Name="NavRoles"       Style="{StaticResource NavButton}" Content="▤   Roles"/>
          <ToggleButton x:Name="NavAssignments" Style="{StaticResource NavButton}" Content="⇄   Role Assignments"/>
          <ToggleButton x:Name="NavScopes"      Style="{StaticResource NavButton}" Content="⊙   Scopes"/>
          <Border Height="1" Opacity="0.2" Background="White" Margin="14,8,14,8"/>
          <ToggleButton x:Name="NavUserRights"  Style="{StaticResource NavButton}" Content="⌕   User Rights"/>
          <ToggleButton x:Name="NavCommands"    Style="{StaticResource NavButton}" Content="⌘   Command Lookup"/>
          <ToggleButton x:Name="NavMyCmdlets"   Style="{StaticResource NavButton}" Content="≣   My Cmdlets"/>
          <Border Height="1" Opacity="0.2" Background="White" Margin="14,8,14,8"/>
          <ToggleButton x:Name="NavVisualizer"  Style="{StaticResource NavButton}" Content="⤳   RBAC Visualizer"/>
          <ToggleButton x:Name="NavAudit"       Style="{StaticResource NavButton}" Content="◷   Audit Log"/>
        </StackPanel>

        <Border Grid.Row="3" Padding="14,10" BorderThickness="0,1,0,0">
          <Border.BorderBrush><SolidColorBrush Color="White" Opacity="0.25"/></Border.BorderBrush>
          <StackPanel>
            <TextBlock x:Name="VersionLabel" Foreground="White" Opacity="0.7"
                       FontFamily="Consolas" FontSize="11"/>
            <StackPanel Orientation="Horizontal" Margin="0,6,0,0">
              <TextBlock x:Name="LinkLinkedIn" Text="LinkedIn" Foreground="White" Opacity="0.85"
                         FontSize="11" Cursor="Hand" TextDecorations="Underline"
                         ToolTip="https://www.linkedin.com/in/perez-bastien/"/>
              <TextBlock Text="·" Foreground="White" Opacity="0.5" Margin="6,0" FontSize="11"/>
              <TextBlock x:Name="LinkGitHub" Text="GitHub" Foreground="White" Opacity="0.85"
                         FontSize="11" Cursor="Hand" TextDecorations="Underline"
                         ToolTip="https://github.com/bastienperez/exchange-rbac-manager"/>
              <TextBlock Text="·" Foreground="White" Opacity="0.5" Margin="6,0" FontSize="11"/>
              <TextBlock x:Name="LinkClidsys" Text="Clidsys" Foreground="White" Opacity="0.85"
                         FontSize="11" Cursor="Hand" TextDecorations="Underline"
                         ToolTip="https://clidsys.com"/>
            </StackPanel>
          </StackPanel>
        </Border>
      </Grid>
    </Border>

    <!-- Main content -->
    <Grid Grid.Column="1" Background="White">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>  <!-- Content head -->
        <RowDefinition Height="Auto"/>  <!-- Toolbar -->
        <RowDefinition Height="Auto"/>  <!-- Filter chips row (collapses when no chips) -->
        <RowDefinition Height="*"/>     <!-- Content + floating action bar overlay -->
        <RowDefinition Height="Auto"/>  <!-- Activity log drawer -->
        <RowDefinition Height="Auto"/>  <!-- Status bar -->
      </Grid.RowDefinitions>

      <!-- Content head - no bottom border, the toolbar's own divider handles separation. -->
      <Border Grid.Row="0" Padding="24,18,24,16">
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
        </Grid>
      </Border>

      <!-- Toolbar -->
      <Border Grid.Row="1" Background="{StaticResource ToolbarBg}" Padding="24,12"
              BorderBrush="{StaticResource BorderC}" BorderThickness="0,0,0,1">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>  <!-- Search box -->
            <ColumnDefinition Width="*"/>     <!-- spacer -->
            <ColumnDefinition Width="Auto"/>  <!-- View modifiers (Filter/Wrap/Auto-fit) -->
            <ColumnDefinition Width="Auto"/>  <!-- View-level Tool buttons (Refresh, Export, …) -->
            <ColumnDefinition Width="Auto"/>  <!-- Primary action (+ New) -->
          </Grid.ColumnDefinitions>
          <Border x:Name="SearchHost" Grid.Column="0" BorderThickness="1" CornerRadius="4"
                  Background="White" Width="280" Height="30">
            <Border.Style>
              <Style TargetType="Border">
                <Setter Property="BorderBrush" Value="#C8C6C4"/>
                <Style.Triggers>
                  <Trigger Property="IsKeyboardFocusWithin" Value="True">
                    <Setter Property="BorderBrush" Value="#0078D4"/>
                  </Trigger>
                </Style.Triggers>
              </Style>
            </Border.Style>
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
          <StackPanel x:Name="GridModifiers" Grid.Column="2" Orientation="Horizontal" Margin="0,0,8,0">
            <ToggleButton x:Name="BtnFilterRow" Content="Filter" Style="{StaticResource ToggleActionBtn}" Margin="0,0,6,0"
                          ToolTip="Toggle a filter input in each column header"/>
            <ToggleButton x:Name="BtnWrap" Content="Wrap" Style="{StaticResource ToggleActionBtn}" Margin="0,0,6,0"
                          ToolTip="Toggle text wrapping on long cells"/>
            <Button x:Name="BtnAutoFit" Content="Auto-fit" Style="{StaticResource ActionBtn}" Margin="0,0,6,0"
                    ToolTip="Resize columns to fit current content"/>
          </StackPanel>
          <!-- View-level tools (Refresh, Export, audit timeframes…) injected by Set-Actions. -->
          <StackPanel x:Name="ToolbarTools"   Grid.Column="3" Orientation="Horizontal" Margin="0,0,0,0"/>
          <!-- Primary view action (+ New, Lookup, Pick assignment…) injected by Set-Actions. -->
          <StackPanel x:Name="ToolbarPrimary" Grid.Column="4" Orientation="Horizontal" Margin="12,0,0,0"/>
        </Grid>
      </Border>

      <!-- Filter chips (per-view buckets) on their own row to avoid squeezing them
           against the toolbar's right-hand cluster. Hidden when a view has no chips. -->
      <Border x:Name="ChipsHostBorder" Grid.Row="2" Background="{StaticResource ToolbarBg}"
              Padding="24,8" BorderBrush="{StaticResource BorderC}" BorderThickness="0,0,0,1">
        <ItemsControl x:Name="ChipsHost">
          <ItemsControl.ItemsPanel>
            <ItemsPanelTemplate><WrapPanel Orientation="Horizontal"/></ItemsPanelTemplate>
          </ItemsControl.ItemsPanel>
        </ItemsControl>
      </Border>

      <!-- Content area: table OR visualizer + slide-out details panel -->
      <Grid Grid.Row="3">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition x:Name="DetailsCol" Width="0"/>
        </Grid.ColumnDefinitions>
        <Grid Grid.Column="0">
          <DataGrid x:Name="MainGrid"/>
        <Grid>
          <Grid x:Name="VizHost" Visibility="Collapsed" Background="White">
            <ScrollViewer x:Name="VizScroll" HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Hidden">
              <Canvas x:Name="VizCanvas" Background="White" ClipToBounds="False"/>
            </ScrollViewer>
            <Border x:Name="VizPlaceholderBox" HorizontalAlignment="Center" VerticalAlignment="Center"
                    Background="#F3F2F1" CornerRadius="6" Padding="14,10">
              <TextBlock x:Name="VizPlaceholder" Text="Pick an assignment in the toolbar to visualize."
                         Foreground="#605E5C" FontSize="13"/>
            </Border>
          </Grid>
          <Border x:Name="LoadingOverlay" Background="#B3FFFFFF" Visibility="Collapsed">
            <Border Background="White" BorderBrush="#0078D4" BorderThickness="1" CornerRadius="8"
                    Padding="20,16" HorizontalAlignment="Center" VerticalAlignment="Center" MinWidth="260">
              <Border.Effect>
                <DropShadowEffect Color="Black" BlurRadius="20" ShadowDepth="4" Opacity="0.18" Direction="270"/>
              </Border.Effect>
              <StackPanel>
                <TextBlock x:Name="LoadingText" Text="Loading…" Foreground="#201F1E" FontSize="13"
                           FontWeight="SemiBold" Margin="0,0,0,8" HorizontalAlignment="Center"
                           TextAlignment="Center" TextWrapping="Wrap" MaxWidth="320"/>
                <ProgressBar IsIndeterminate="True" Height="6" Foreground="#0078D4" Background="#EDEBE9"
                             BorderThickness="0" Width="240"/>
              </StackPanel>
            </Border>
          </Border>
        </Grid>
        </Grid>
        <Border x:Name="DetailsPanel" Grid.Column="1" Background="{StaticResource ToolbarBg}"
                BorderBrush="{StaticResource BorderC}" BorderThickness="1,0,0,0" Visibility="Collapsed">
          <Grid>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <Grid Grid.Row="0" Margin="16,14,8,10">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <StackPanel Grid.Column="0">
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="DETAILS" FontFamily="Consolas" FontSize="10" Foreground="{StaticResource Subdued}"
                             VerticalAlignment="Center"/>
                  <Border x:Name="DetailsTypeBadge" Margin="8,0,0,0" Padding="6,1" CornerRadius="6"
                          Background="#DEECF9" Visibility="Collapsed">
                    <TextBlock x:Name="DetailsTypeBadgeText" FontFamily="Consolas" FontSize="10"
                               FontWeight="SemiBold" Foreground="#0078D4"/>
                  </Border>
                </StackPanel>
                <TextBlock x:Name="DetailsTitle" FontSize="16" FontWeight="SemiBold"
                           Foreground="{StaticResource Ink}" TextTrimming="CharacterEllipsis" Margin="0,2,0,0"/>
              </StackPanel>
              <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Top">
                <Button x:Name="BtnDetailsCopy" Content="⧉" Width="28" Height="28" ToolTip="Copy name"
                        Background="Transparent" BorderThickness="0" Cursor="Hand" FontSize="14">
                  <Button.Style>
                    <Style TargetType="Button">
                      <Setter Property="Foreground" Value="#605E5C"/>
                      <Style.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                          <Setter Property="Foreground" Value="#0078D4"/>
                        </Trigger>
                      </Style.Triggers>
                    </Style>
                  </Button.Style>
                </Button>
                <Button x:Name="BtnDetailsClose" Content="✕" Width="28" Height="28"
                        Background="Transparent" BorderThickness="0" Cursor="Hand" FontSize="14">
                  <Button.Style>
                    <Style TargetType="Button">
                      <Setter Property="Foreground" Value="#605E5C"/>
                      <Style.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                          <Setter Property="Foreground" Value="#0078D4"/>
                        </Trigger>
                      </Style.Triggers>
                    </Style>
                  </Button.Style>
                </Button>
              </StackPanel>
            </Grid>
            <Button x:Name="BtnDetailsGoto" Grid.Row="1" HorizontalAlignment="Left" Margin="16,0,16,8"
                    Padding="0" Background="Transparent" BorderThickness="0" Cursor="Hand"
                    FontSize="12" Visibility="Collapsed">
              <Button.Style>
                <Style TargetType="Button">
                  <Setter Property="Foreground" Value="#0078D4"/>
                  <Style.Triggers>
                    <Trigger Property="IsMouseOver" Value="True">
                      <Setter Property="Foreground" Value="#005A9E"/>
                    </Trigger>
                  </Style.Triggers>
                </Style>
              </Button.Style>
            </Button>
            <Border Grid.Row="2" Height="1" Background="#E1DFDD" Margin="16,0,16,8"/>
            <ScrollViewer Grid.Row="3" VerticalScrollBarVisibility="Auto" Padding="16,0,16,16">
              <ItemsControl x:Name="DetailsList">
                <ItemsControl.ItemTemplate>
                  <DataTemplate>
                    <StackPanel>
                      <StackPanel.Style>
                        <Style TargetType="StackPanel">
                          <Setter Property="Margin" Value="0,0,0,12"/>
                          <Style.Triggers>
                            <!-- Compact row when there is no Key (cmdlet list, etc.) -->
                            <DataTrigger Binding="{Binding Key}" Value="">
                              <Setter Property="Margin" Value="0,0,0,1"/>
                            </DataTrigger>
                          </Style.Triggers>
                        </Style>
                      </StackPanel.Style>
                      <TextBlock Text="{Binding Key}" FontFamily="Consolas" FontSize="10"
                                 Foreground="#605E5C" TextTrimming="CharacterEllipsis">
                        <TextBlock.Style>
                          <Style TargetType="TextBlock">
                            <Style.Triggers>
                              <DataTrigger Binding="{Binding Key}" Value="">
                                <Setter Property="Visibility" Value="Collapsed"/>
                              </DataTrigger>
                            </Style.Triggers>
                          </Style>
                        </TextBlock.Style>
                      </TextBlock>
                      <TextBlock Text="{Binding Value}" FontSize="12" Foreground="#201F1E"
                                 TextWrapping="Wrap">
                        <TextBlock.Style>
                          <Style TargetType="TextBlock">
                            <Setter Property="Margin" Value="0,2,0,0"/>
                            <Style.Triggers>
                              <DataTrigger Binding="{Binding Key}" Value="">
                                <Setter Property="Margin" Value="0,0,0,0"/>
                              </DataTrigger>
                              <!-- Empty value (header-only row) collapses to nothing -->
                              <DataTrigger Binding="{Binding Value}" Value="">
                                <Setter Property="Visibility" Value="Collapsed"/>
                              </DataTrigger>
                            </Style.Triggers>
                          </Style>
                        </TextBlock.Style>
                      </TextBlock>
                    </StackPanel>
                  </DataTemplate>
                </ItemsControl.ItemTemplate>
              </ItemsControl>
            </ScrollViewer>
          </Grid>
        </Border>
      </Grid>

      <!-- Floating contextual action bar - only visible when at least one row is selected.
           Light Fluent pill matching the rest of the app. Sits in Grid.Column=0 only so the
           details panel slide-out doesn't push the bar off-center. -->
      <Border x:Name="FloatingActions" Grid.Row="3" Grid.Column="0"
              Background="White" CornerRadius="9" Padding="6,3"
              BorderBrush="#0078D4" BorderThickness="2"
              VerticalAlignment="Bottom" HorizontalAlignment="Left"
              Margin="24,0,0,18" Visibility="Collapsed">
        <Border.Effect>
          <DropShadowEffect Color="Black" BlurRadius="18" ShadowDepth="3" Opacity="0.12" Direction="270"/>
        </Border.Effect>
        <StackPanel Orientation="Horizontal">
          <Border Background="#EFF6FC" CornerRadius="4" Padding="8,2" VerticalAlignment="Center" Margin="2,0">
            <StackPanel Orientation="Horizontal">
              <TextBlock x:Name="FloatingCount" Text="0" Foreground="#0078D4" FontFamily="Consolas" FontSize="11" FontWeight="SemiBold"/>
              <TextBlock Text=" selected" Foreground="#0078D4" FontSize="11" Margin="2,0,0,0"/>
            </StackPanel>
          </Border>
          <Border Width="1" Height="14" Background="#E1DFDD" Margin="6,0"/>
          <StackPanel x:Name="FloatingSelectionActions" Orientation="Horizontal"/>
          <Border x:Name="FloatingSep" Width="1" Height="14" Background="#E1DFDD" Margin="4,0" Visibility="Collapsed"/>
          <StackPanel x:Name="FloatingDestructive" Orientation="Horizontal"/>
        </StackPanel>
      </Border>

      <!-- Activity log: collapsed drawer sitting just above the status bar. -->
      <Expander x:Name="LogDrawer" Grid.Row="4" IsExpanded="False"
                Background="{StaticResource ToolbarBg}" BorderBrush="{StaticResource BorderC}"
                BorderThickness="0,1,0,0" Padding="16,2">
        <Expander.Header>
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="ACTIVITY LOG" FontFamily="Consolas" FontSize="11" Foreground="#605E5C" VerticalAlignment="Center"/>
            <TextBlock x:Name="LogCount" Text="" FontFamily="Consolas" FontSize="11" Foreground="#A19F9D" Margin="8,0,0,0" VerticalAlignment="Center"/>
            <Button x:Name="BtnLogClear"  Content="Clear"   Margin="12,0,0,0" Padding="9,2" FontSize="11" Cursor="Hand"/>
            <Button x:Name="BtnLogExport" Content="Export…" Margin="6,0,0,0"  Padding="9,2" FontSize="11" Cursor="Hand"/>
          </StackPanel>
        </Expander.Header>
        <TextBox x:Name="TxtLog" IsReadOnly="True" Height="150" VerticalScrollBarVisibility="Auto"
                 HorizontalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="11.5"
                 TextWrapping="NoWrap" Background="White" Foreground="#3A3A3A" BorderThickness="0"
                 Margin="0,4,0,6"/>
      </Expander>

      <!-- Status bar -->
      <Border Grid.Row="5" Background="{StaticResource StatusBg}"
              BorderBrush="{StaticResource BorderC}" BorderThickness="0,1,0,0"
              Padding="0,8">
        <Grid MinHeight="48">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <Grid Grid.Column="0" Margin="16,0">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="StatusDot" Grid.Column="0" Foreground="#107C10" Text="●" FontSize="16"
                       VerticalAlignment="Center"/>
            <TextBlock x:Name="StatusText" Grid.Column="1" Margin="10,0,0,0" Text="Ready"
                       VerticalAlignment="Center"
                       FontFamily="Segoe UI" FontSize="14" FontWeight="SemiBold" Foreground="#201F1E"
                       TextWrapping="Wrap" TextTrimming="None"/>
            <TextBlock x:Name="StatusSep" Grid.Column="2" Margin="14,0" Text="|"
                       Foreground="#A19F9D" VerticalAlignment="Center"/>
            <TextBlock x:Name="StatusItems" Grid.Column="3" VerticalAlignment="Center"
                       FontFamily="Segoe UI" FontSize="12" Foreground="#605E5C"/>
          </Grid>
          <StackPanel Grid.Column="1" Orientation="Horizontal" Margin="0,0,16,0" VerticalAlignment="Center">
            <TextBlock x:Name="ItemCount" Text="0 items" VerticalAlignment="Center"
                       FontFamily="Segoe UI" FontSize="12" Foreground="#605E5C"/>
            <TextBlock Text="|" Margin="14,0" Foreground="#A19F9D" VerticalAlignment="Center"/>
            <TextBlock x:Name="StatusVersion" VerticalAlignment="Center"
                       FontFamily="Consolas" FontSize="11" Foreground="#A19F9D"/>
          </StackPanel>
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
            'TenantLabel','TenantName','ConnPulse','ConnStatus','BtnConnect','BtnDisconnect','ChkUseWAM','BtnWamInfo','VersionLabel',
            'LinkLinkedIn','LinkGitHub','LinkClidsys',
            'NavRoleGroups','NavRoles','NavAssignments','NavScopes','NavUserRights','NavCommands','NavMyCmdlets','NavVisualizer','NavAudit',
            'Crumbs','ViewTitle','ViewDesc','SearchHost','SearchBox','SuggestPopup','SuggestList','ChipsHost','ChipsHostBorder',
            'BtnFilterRow','BtnWrap','BtnAutoFit','GridModifiers',
            'ItemCount','ToolbarTools','ToolbarPrimary',
            'MainGrid','VizHost','VizCanvas','VizScroll','VizPlaceholder','VizPlaceholderBox',
            'DetailsCol','DetailsPanel','DetailsTitle','DetailsTypeBadge','DetailsTypeBadgeText','DetailsList','BtnDetailsClose','BtnDetailsCopy','BtnDetailsGoto',
            'FloatingActions','FloatingCount','FloatingSelectionActions','FloatingSep','FloatingDestructive',
            'LoadingOverlay','LoadingText',
            'StatusDot','StatusText','StatusSep','StatusItems','StatusVersion',
            'LogDrawer','TxtLog','LogCount','BtnLogClear','BtnLogExport'
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

    # Scope members resolved for the current assignment's write scope, drawn as a
    # fan of nodes off the Scope spoke. Null = not resolved yet (button not clicked).
    $script:VizScopeMembers   = $null
    $script:VizScopeInfo      = $null   # the resolved Get-ManagementScope object
    $script:VizScopeTruncated = $false  # preview hit the cap below
    $script:VizScopeCap       = 60      # members drawn on the canvas at most
    # Cache of resolved custom-scope names keyed "<assignmentName>|Write|Read".
    # The bulk Get-ManagementRoleAssignment often returns CustomRecipient*Scope /
    # *ScopeDetails EMPTY (e.g. AutoManaged-* assignments); the name only comes
    # through when the assignment is re-queried by identity, so we do that once
    # and remember it rather than re-fetching on every render.
    $script:VizScopeNameCache = @{}
    # Cached management-scope catalog (Name + flattened Filter + Root) used to
    # cross-reference an assignment to its scope name when the assignment object
    # exposes neither the name nor a usable *ScopeDetails.Name.
    $script:VizScopeCatalog = $null

    # Where the details panel's "Open in ..." button should navigate (set per
    # Visualizer node, cleared for grid rows). @{ View; Name; Label } or $null.
    $script:DetailsNavTarget = $null

    # Shared cmdlet verb -> group classification + colour palette. Defined once at
    # script scope so the WPF visualizer render AND the interactive HTML export
    # colour-code cmdlets identically.
    $script:VizVerbPalettes = @{
        Read        = @{ Bg='#C5E1A5'; Border='#558B2F'; Fg='#33691E' } # green
        Modify      = @{ Bg='#FFE082'; Border='#B28704'; Fg='#5C3A00' } # amber
        Destructive = @{ Bg='#FFCDD2'; Border='#A4262C'; Fg='#7A1A1F' } # red
        Create      = @{ Bg='#BBDEFB'; Border='#0078D4'; Fg='#0B4A78' } # blue
        Other       = @{ Bg='#E1BEE7'; Border='#6A1B9A'; Fg='#3F0C57' } # purple
    }
    $script:VizVerbToGroup = @{
        'Get' = 'Read'; 'Find' = 'Read'; 'Search' = 'Read'; 'Test' = 'Read'; 'Measure' = 'Read'
        'Set' = 'Modify'; 'Update' = 'Modify'; 'Edit' = 'Modify'; 'Sync' = 'Modify'
        'Remove' = 'Destructive'; 'Disable' = 'Destructive'; 'Stop' = 'Destructive'; 'Clear' = 'Destructive'
        'New' = 'Create'; 'Add' = 'Create'; 'Enable' = 'Create'; 'Start' = 'Create'; 'Install' = 'Create'
    }
    $script:VizGroupOrder    = @{ Read=0; Modify=1; Destructive=2; Create=3; Other=4 }
    $script:VizMemberPalette = @{ Bg='#EAF3FB'; Border='#2B88D8'; Fg='#0B4A78' } # scope members

    # Module versions (sidebar = this module, status bar = ExchangeOnlineManagement)
    $modVer = Get-RBACModuleVersion
    $verStr = if ($modVer) { "v$($modVer.ToString())" } else { 'v?' }
    $UI.VersionLabel.Text = "ExchangeRBACManager $verStr"

    $exoVer = (Get-Module -Name 'ExchangeOnlineManagement' -ListAvailable |
               Sort-Object Version -Descending | Select-Object -First 1).Version
    $UI.StatusVersion.Text = if ($exoVer) { "ExchangeOnlineManagement v$exoVer" } else { 'ExchangeOnlineManagement n/a' }

    # ---------------- Activity log ----------------
    # Per-session log file (best-effort) mirroring the on-screen Activity log drawer.
    $script:GuiLogFile  = Join-Path $env:TEMP ("ExchangeRBACManager-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $script:GuiLogCount = 0

    function Write-GuiLog {
        param([string]$Message, [ValidateSet('INFO','OK','WARN','ERROR')]$Tag = 'INFO')
        if (-not $UI.TxtLog) { return }
        # Pad the tag so messages line up in the monospaced drawer (longest tag = ERROR).
        $line = "$(Get-Date -Format 'HH:mm:ss') [$($Tag.PadRight(5))] $Message"
        $UI.TxtLog.AppendText("$line`r`n")
        $UI.TxtLog.ScrollToEnd()
        $script:GuiLogCount++
        if ($UI.LogCount) { $UI.LogCount.Text = "($script:GuiLogCount)" }
        # Surface problems automatically: pop the drawer open on the first error so
        # the user actually sees what went wrong without hunting for it.
        if ($Tag -eq 'ERROR' -and $UI.LogDrawer -and -not $UI.LogDrawer.IsExpanded) {
            $UI.LogDrawer.IsExpanded = $true
        }
        # Persist to the per-session file; never let logging break the UI.
        if ($script:GuiLogFile) {
            try { Add-Content -LiteralPath $script:GuiLogFile -Value $line -Encoding UTF8 -ErrorAction Stop } catch { }
        }
    }

    # ---------------- Status helpers ----------------
    function Set-Status {
        param([string]$Message, [ValidateSet('info','warn','error','ok')]$Level = 'info')
        $UI.StatusText.Text = $Message
        switch ($Level) {
            'error' {
                $UI.StatusDot.Foreground  = '#A4262C'
                $UI.StatusText.Foreground = '#A4262C'
            }
            'warn'  {
                $UI.StatusDot.Foreground  = '#D29200'
                $UI.StatusText.Foreground = '#8A5A00'
            }
            'ok'    {
                $UI.StatusDot.Foreground  = '#107C10'
                $UI.StatusText.Foreground = '#201F1E'
            }
            default {
                $UI.StatusDot.Foreground  = '#0078D4'
                $UI.StatusText.Foreground = '#201F1E'
            }
        }
        # Mirror every status message into the Activity log drawer.
        $tag = switch ($Level) { 'error' { 'ERROR' } 'warn' { 'WARN' } 'ok' { 'OK' } default { 'INFO' } }
        Write-GuiLog -Message $Message -Tag $tag
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
        # Fluent-style filter chip: rounded pill, Segoe UI, hover state for inactive,
        # filled accent + bold when selected.
        $b = [System.Windows.Controls.Border]::new()
        $b.CornerRadius      = '13'
        $b.BorderThickness   = '1'
        $b.Margin            = '0,2,6,2'
        $b.Padding           = '14,5'
        $b.Height            = 26
        $b.VerticalAlignment = 'Center'
        $b.Cursor            = [System.Windows.Input.Cursors]::Hand
        $b.SnapsToDevicePixels = $true

        $t = [System.Windows.Controls.TextBlock]::new()
        # Tidy label: "all" → "All", "view-only" → "View-Only".
        $tidy = ($Label -split '[\s_-]+' | ForEach-Object {
            if ($_) { $_.Substring(0,1).ToUpper() + $_.Substring(1) }
        }) -join ' '
        $t.Text              = $tidy
        $t.FontFamily        = 'Segoe UI'
        $t.FontSize          = 12
        $t.VerticalAlignment = 'Center'
        $t.IsHitTestVisible  = $false   # so the chip border owns the hit
        $b.Child = $t

        if ($On) {
            $b.Background  = '#0078D4'
            $b.BorderBrush = '#0078D4'
            $t.Foreground  = 'White'
            $t.FontWeight  = [System.Windows.FontWeights]::SemiBold
            # Subtle drop shadow on the active pill so it sits above the toolbar surface.
            $shadow = [System.Windows.Media.Effects.DropShadowEffect]::new()
            $shadow.BlurRadius   = 4
            $shadow.ShadowDepth  = 1
            $shadow.Opacity      = 0.18
            $shadow.Color        = [System.Windows.Media.Colors]::Black
            $b.Effect = $shadow
        }
        else {
            $b.Background  = 'White'
            $b.BorderBrush = '#C8C6C4'
            $t.Foreground  = '#323130'
            # Hover effect for inactive chips: darken background, accent border.
            $b.Add_MouseEnter({
                $args[0].Background  = [System.Windows.Media.SolidColorBrush]::new(
                    [System.Windows.Media.ColorConverter]::ConvertFromString('#EFF6FC'))
                $args[0].BorderBrush = [System.Windows.Media.SolidColorBrush]::new(
                    [System.Windows.Media.ColorConverter]::ConvertFromString('#0078D4'))
            })
            $b.Add_MouseLeave({
                $args[0].Background  = [System.Windows.Media.SolidColorBrush]::new(
                    [System.Windows.Media.Colors]::White)
                $args[0].BorderBrush = [System.Windows.Media.SolidColorBrush]::new(
                    [System.Windows.Media.ColorConverter]::ConvertFromString('#C8C6C4'))
            })
        }

        # Stash the original (untidied) label on Tag so Switch-Chip resolves correctly.
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
        # Hide the chips row entirely when a view defines no chips.
        $UI.ChipsHostBorder.Visibility = if ($Labels.Count -gt 0) { 'Visible' } else { 'Collapsed' }
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
        param(
            [string]$Label,
            [string]$Style = 'ActionBtn',
            [scriptblock]$OnClick,
            [ValidateSet('Primary','Tool','Selection','Destructive')]
            [string]$Kind = 'Tool'
        )
        $b = [System.Windows.Controls.Button]::new()
        $b.Content = $Label
        $b.Style = $window.FindResource($Style)
        if ($OnClick) {
            $b.Tag = $OnClick
            $b.Add_Click({
                $sb = $args[0].Tag
                if ($sb -is [scriptblock]) { & $sb }
            })
        }
        # Wrap so the dispatcher knows which zone to put the button in.
        return [pscustomobject]@{ Button = $b; Kind = $Kind }
    }

    function Set-Actions {
        # Distributes buttons into 4 zones:
        #   - ToolbarTools     (top, view-level: Refresh, Export, audit timeframes…)
        #   - ToolbarPrimary   (top, signature action: + New, Lookup, Pick assignment…)
        #   - FloatingSelectionActions (bottom floating bar: Edit, Copy, Visualize…)
        #   - FloatingDestructive      (bottom floating bar, isolated: Delete)
        param([array]$Buttons)
        foreach ($p in 'ToolbarTools','ToolbarPrimary','FloatingSelectionActions','FloatingDestructive') {
            $UI[$p].Children.Clear()
        }
        $UI.FloatingSep.Visibility = 'Collapsed'

        foreach ($entry in $Buttons) {
            switch ($entry.Kind) {
                'Primary'     { $null = $UI.ToolbarPrimary.Children.Add($entry.Button) }
                'Tool'        { $null = $UI.ToolbarTools.Children.Add($entry.Button) }
                'Selection'   { $null = $UI.FloatingSelectionActions.Children.Add($entry.Button) }
                'Destructive' {
                    $null = $UI.FloatingDestructive.Children.Add($entry.Button)
                    $UI.FloatingSep.Visibility = 'Visible'
                }
            }
        }
    }

    # ---------------- Write-mode helpers ----------------
    # All write actions go through Show-CmdletPreview which exposes
    # "Run cmdlet" / "Copy cmdlet" / "Cancel" buttons - no global toggle needed.

    # Shared resource block injected into every modal dialog so they all share
    # the same input/button/label styling as the main window.
    $script:DlgResourcesXaml = @'
    <Window.Resources>
      <Style x:Key="DlgLabel" TargetType="TextBlock">
        <Setter Property="FontSize" Value="12"/>
        <Setter Property="FontWeight" Value="SemiBold"/>
        <Setter Property="Foreground" Value="#323130"/>
        <Setter Property="Margin" Value="0,0,0,4"/>
      </Style>
      <Style x:Key="DlgTextBox" TargetType="TextBox">
        <Setter Property="MinHeight" Value="32"/>
        <Setter Property="Padding" Value="10,7"/>
        <Setter Property="FontSize" Value="13"/>
        <Setter Property="Background" Value="White"/>
        <Setter Property="BorderBrush" Value="#C8C6C4"/>
        <Setter Property="BorderThickness" Value="1"/>
        <Setter Property="VerticalContentAlignment" Value="Center"/>
        <Setter Property="Template">
          <Setter.Value>
            <ControlTemplate TargetType="TextBox">
              <Border x:Name="bd" Background="{TemplateBinding Background}"
                      BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4">
                <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}"
                              VerticalAlignment="Center"/>
              </Border>
              <ControlTemplate.Triggers>
                <Trigger Property="IsKeyboardFocused" Value="True">
                  <Setter TargetName="bd" Property="BorderBrush" Value="#0078D4"/>
                </Trigger>
              </ControlTemplate.Triggers>
            </ControlTemplate>
          </Setter.Value>
        </Setter>
      </Style>
      <Style x:Key="DlgComboBox" TargetType="ComboBox">
        <Setter Property="MinHeight" Value="32"/>
        <Setter Property="FontSize" Value="13"/>
        <Setter Property="VerticalContentAlignment" Value="Center"/>
        <Setter Property="Background" Value="White"/>
        <Setter Property="BorderBrush" Value="#C8C6C4"/>
      </Style>
      <Style x:Key="DlgListBox" TargetType="ListBox">
        <Setter Property="Background" Value="White"/>
        <Setter Property="BorderBrush" Value="#C8C6C4"/>
        <Setter Property="BorderThickness" Value="1"/>
        <Setter Property="FontSize" Value="12"/>
        <Setter Property="Padding" Value="2"/>
      </Style>
      <Style x:Key="DlgBtn" TargetType="Button">
        <Setter Property="MinWidth" Value="92"/>
        <Setter Property="Height" Value="32"/>
        <Setter Property="Padding" Value="14,0"/>
        <Setter Property="FontSize" Value="13"/>
        <Setter Property="Background" Value="White"/>
        <Setter Property="Foreground" Value="#201F1E"/>
        <Setter Property="BorderBrush" Value="#C8C6C4"/>
        <Setter Property="BorderThickness" Value="1"/>
        <Setter Property="Cursor" Value="Hand"/>
        <Setter Property="Template">
          <Setter.Value>
            <ControlTemplate TargetType="Button">
              <Border x:Name="bd" Background="{TemplateBinding Background}"
                      BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="4"
                      Padding="{TemplateBinding Padding}">
                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
              <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                  <Setter TargetName="bd" Property="Background" Value="#F3F2F1"/>
                  <Setter TargetName="bd" Property="BorderBrush" Value="#A19F9D"/>
                </Trigger>
              </ControlTemplate.Triggers>
            </ControlTemplate>
          </Setter.Value>
        </Setter>
      </Style>
      <Style x:Key="DlgBtnPrimary" TargetType="Button" BasedOn="{StaticResource DlgBtn}">
        <Setter Property="Background" Value="#0078D4"/>
        <Setter Property="Foreground" Value="White"/>
        <Setter Property="BorderBrush" Value="#0078D4"/>
        <Setter Property="FontWeight" Value="SemiBold"/>
        <Setter Property="Template">
          <Setter.Value>
            <ControlTemplate TargetType="Button">
              <Border x:Name="bd" Background="{TemplateBinding Background}"
                      BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="4"
                      Padding="{TemplateBinding Padding}">
                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
              <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                  <Setter TargetName="bd" Property="Background" Value="#106EBE"/>
                  <Setter TargetName="bd" Property="BorderBrush" Value="#106EBE"/>
                </Trigger>
              </ControlTemplate.Triggers>
            </ControlTemplate>
          </Setter.Value>
        </Setter>
      </Style>
    </Window.Resources>
'@

    function Show-CmdletPreview {
        <#
        Shows the cmdlet that would be run. Returns $true if the user clicked
        "Run cmdlet"; otherwise $false (Copy cmdlet leaves the dialog open).
        #>
        param(
            [Parameter(Mandatory)] [string]$Title,
            [Parameter(Mandatory)] [string]$Cmdlet
        )
        $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="" Width="720" Height="380" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" Background="White" ResizeMode="CanResize"
        ShowInTaskbar="False" SizeToContent="Manual">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>  <!-- header band -->
      <RowDefinition Height="*"/>     <!-- code body -->
      <RowDefinition Height="Auto"/>  <!-- footer with buttons -->
    </Grid.RowDefinitions>

    <!-- Header band - same off-white surface as the main toolbar. -->
    <Border Grid.Row="0" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,0,0,1"
            Padding="20,16">
      <StackPanel>
        <TextBlock x:Name="DlgTitle" FontSize="16" FontWeight="SemiBold" Foreground="#201F1E"/>
        <TextBlock Text="Review the command that will be executed on Exchange Online."
                   FontSize="12" Foreground="#605E5C" Margin="0,2,0,0"/>
      </StackPanel>
    </Border>

    <!-- Code body - monospace on a soft surface so it reads as a code block. -->
    <Border Grid.Row="1" Background="#FAFAFA" BorderBrush="#E1DFDD" BorderThickness="0,0,0,1"
            Padding="20,16">
      <Border Background="White" BorderBrush="#E1DFDD" BorderThickness="1" CornerRadius="6">
        <TextBox x:Name="CmdletText" AcceptsReturn="True" TextWrapping="Wrap"
                 FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                 BorderThickness="0" Background="Transparent"
                 Padding="14,10" VerticalScrollBarVisibility="Auto"/>
      </Border>
    </Border>

    <!-- Footer: Copy on the left, Cancel + Run on the right. -->
    <Grid Grid.Row="2" Background="#F8F8F8">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <Button x:Name="BtnCopy" Grid.Column="0" Content="Copy cmdlet" Width="130" Height="32"
              Margin="20,12,0,12" Background="White" BorderBrush="#C8C6C4" BorderThickness="1"
              Foreground="#201F1E" Cursor="Hand">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="4">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#F3F2F1"/>
                <Setter TargetName="bd" Property="BorderBrush" Value="#A19F9D"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
      </Button>
      <Button x:Name="BtnCancel" Grid.Column="2" Content="Cancel" Width="90" Height="32"
              Margin="0,12,8,12" Background="White" BorderBrush="#C8C6C4" BorderThickness="1"
              Foreground="#201F1E" Cursor="Hand" IsCancel="True">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="4">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#F3F2F1"/>
                <Setter TargetName="bd" Property="BorderBrush" Value="#A19F9D"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
      </Button>
      <Button x:Name="BtnRun" Grid.Column="3" Content="Run cmdlet" Width="130" Height="32"
              Margin="0,12,20,12" Background="#0078D4" BorderBrush="#0078D4" BorderThickness="1"
              Foreground="White" FontWeight="SemiBold" Cursor="Hand" IsDefault="True">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="4">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#106EBE"/>
                <Setter TargetName="bd" Property="BorderBrush" Value="#106EBE"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
      </Button>
    </Grid>
  </Grid>
</Window>
'@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $w = [System.Windows.Markup.XamlReader]::Load($reader)
        $w.Title = $Title
        $w.Owner = $window
        $w.FindName('DlgTitle').Text = $Title
        $tb     = $w.FindName('CmdletText')
        $btnCp  = $w.FindName('BtnCopy')
        $btnCa  = $w.FindName('BtnCancel')
        $btnRn  = $w.FindName('BtnRun')
        $tb.Text = $Cmdlet

        $script:_PreviewRun = $false
        $btnCp.Add_Click({
            try { [System.Windows.Clipboard]::SetText($tb.Text); Set-Status 'Cmdlet copied to clipboard.' 'ok' } catch {}
        })
        $btnCa.Add_Click({ $w.Close() })
        $btnRn.Add_Click({ $script:_PreviewRun = $true; $w.Close() })

        $null = $w.ShowDialog()
        return $script:_PreviewRun
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
        $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="" Width="640" Height="760" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" Background="White" ResizeMode="CanResize" ShowInTaskbar="False">
$($script:DlgResourcesXaml)
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,0,0,1" Padding="20,16">
      <StackPanel>
        <TextBlock x:Name="DlgTitle" FontSize="16" FontWeight="SemiBold" Foreground="#201F1E"/>
        <TextBlock Text="Define name, description, granted roles and members."
                   FontSize="12" Foreground="#605E5C" Margin="0,2,0,0"/>
      </StackPanel>
    </Border>

    <Border Grid.Row="1" Padding="20,16">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock x:Name="LblName" Grid.Row="0" Text="Name" Style="{StaticResource DlgLabel}"/>
        <TextBox  x:Name="TxtName" Grid.Row="1" Style="{StaticResource DlgTextBox}" Margin="0,0,0,12"/>

        <TextBlock Grid.Row="2" Text="Description" Style="{StaticResource DlgLabel}"/>
        <TextBox  x:Name="TxtDesc" Grid.Row="3" Style="{StaticResource DlgTextBox}" Height="56" Margin="0,0,0,12"
                  AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>

        <!-- Roles -->
        <TextBlock Grid.Row="4" Text="Roles" Style="{StaticResource DlgLabel}"/>
        <Grid Grid.Row="5" Margin="0,0,0,12">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <Grid Grid.Row="0" Margin="0,0,0,6">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <ComboBox x:Name="CmbRoleAdd" Grid.Column="0" Style="{StaticResource DlgComboBox}" IsEditable="True"
                      StaysOpenOnEdit="True"
                      ToolTip="Pick from existing management roles or type a name"/>
            <Button   x:Name="BtnRoleAdd"    Grid.Column="1" Content="Add"    Style="{StaticResource DlgBtn}" Margin="6,0,0,0"/>
            <Button   x:Name="BtnRoleRemove" Grid.Column="2" Content="Remove" Style="{StaticResource DlgBtn}" Margin="6,0,0,0"/>
          </Grid>
          <ListBox x:Name="LstRoles" Grid.Row="1" Style="{StaticResource DlgListBox}"
                   SelectionMode="Extended" FontFamily="Consolas"/>
        </Grid>

        <!-- Members -->
        <TextBlock Grid.Row="6" Text="Members (UPN or alias)" Style="{StaticResource DlgLabel}"/>
        <Grid Grid.Row="7" Margin="0,0,0,12">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <Grid Grid.Row="0" Margin="0,0,0,6">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBox x:Name="TxtMemberAdd"  Grid.Column="0" Style="{StaticResource DlgTextBox}"
                     ToolTip="Type a UPN or mailbox alias and press Enter or Add"/>
            <Button  x:Name="BtnMemberAdd"    Grid.Column="1" Content="Add"    Style="{StaticResource DlgBtn}" Margin="6,0,0,0"/>
            <Button  x:Name="BtnMemberRemove" Grid.Column="2" Content="Remove" Style="{StaticResource DlgBtn}" Margin="6,0,0,0"/>
          </Grid>
          <ListBox x:Name="LstMembers" Grid.Row="1" Style="{StaticResource DlgListBox}"
                   SelectionMode="Extended" FontFamily="Consolas"/>
        </Grid>

        <CheckBox x:Name="ChkIncludeMembers" Grid.Row="8" Content="Include members from source"
                  Margin="0,0,0,0" Visibility="Collapsed"/>
      </Grid>
    </Border>

    <Border Grid.Row="2" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,1,0,0" Padding="20,12">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BtnCancel" Content="Cancel" Style="{StaticResource DlgBtn}"        Margin="0,0,8,0" IsCancel="True"/>
        <Button x:Name="BtnOk"     Content="OK"     Style="{StaticResource DlgBtnPrimary}" IsDefault="True"/>
      </StackPanel>
    </Border>
  </Grid>
</Window>
"@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $w = [System.Windows.Markup.XamlReader]::Load($reader)
        $w.Title = $Title
        $w.Owner = $window
        $w.FindName('DlgTitle').Text = $Title

        $UIDlg = @{}
        foreach ($n in @('LblName','TxtName','TxtDesc',
                         'CmbRoleAdd','BtnRoleAdd','BtnRoleRemove','LstRoles',
                         'TxtMemberAdd','BtnMemberAdd','BtnMemberRemove','LstMembers',
                         'ChkIncludeMembers','BtnOk','BtnCancel')) {
            $UIDlg[$n] = $w.FindName($n)
        }
        $UIDlg.LblName.Text       = $NameLabel
        $UIDlg.TxtName.Text       = $DefaultName
        $UIDlg.TxtName.IsReadOnly = $NameReadOnly
        $UIDlg.TxtDesc.Text       = $DefaultDescription

        # Backing collections for the two ListBoxes (ObservableCollection so Add/Remove
        # are reflected immediately without rebinding ItemsSource).
        $rolesCol   = New-Object System.Collections.ObjectModel.ObservableCollection[string]
        $membersCol = New-Object System.Collections.ObjectModel.ObservableCollection[string]
        foreach ($r in $DefaultRoles)   { if ($r) { $rolesCol.Add([string]$r) } }
        foreach ($m in $DefaultMembers) { if ($m) { $membersCol.Add([string]$m) } }
        $UIDlg.LstRoles.ItemsSource   = $rolesCol
        $UIDlg.LstMembers.ItemsSource = $membersCol

        # Populate the role dropdown with cached/fetched management roles.
        try {
            if (-not $script:Cache.Roles -or @($script:Cache.Roles).Count -eq 0) {
                $script:Cache.Roles = Get-RBACRoles
            }
            $UIDlg.CmbRoleAdd.ItemsSource = @($script:Cache.Roles | ForEach-Object Name | Sort-Object -Unique)
        }
        catch { $UIDlg.CmbRoleAdd.ItemsSource = @() }

        $addRole = {
            $val = "$($UIDlg.CmbRoleAdd.Text)".Trim()
            if (-not $val) { return }
            if ($rolesCol -notcontains $val) { $rolesCol.Add($val) }
            $UIDlg.CmbRoleAdd.Text = ''
            $UIDlg.CmbRoleAdd.Focus() | Out-Null
        }
        $removeRoles = {
            $sel = @($UIDlg.LstRoles.SelectedItems | ForEach-Object { "$_" })
            foreach ($s in $sel) { $null = $rolesCol.Remove($s) }
        }
        $UIDlg.BtnRoleAdd.Add_Click($addRole)
        $UIDlg.BtnRoleRemove.Add_Click($removeRoles)
        $UIDlg.CmbRoleAdd.Add_KeyDown({
            param($s, $e)
            if ($e.Key -eq 'Return') { & $addRole; $e.Handled = $true }
        })
        $UIDlg.LstRoles.Add_KeyDown({
            param($s, $e)
            if ($e.Key -eq 'Delete') { & $removeRoles; $e.Handled = $true }
        })

        $addMember = {
            $val = "$($UIDlg.TxtMemberAdd.Text)".Trim()
            if (-not $val) { return }
            if ($membersCol -notcontains $val) { $membersCol.Add($val) }
            $UIDlg.TxtMemberAdd.Text = ''
            $UIDlg.TxtMemberAdd.Focus() | Out-Null
        }
        $removeMembers = {
            $sel = @($UIDlg.LstMembers.SelectedItems | ForEach-Object { "$_" })
            foreach ($s in $sel) { $null = $membersCol.Remove($s) }
        }
        $UIDlg.BtnMemberAdd.Add_Click($addMember)
        $UIDlg.BtnMemberRemove.Add_Click($removeMembers)
        $UIDlg.TxtMemberAdd.Add_KeyDown({
            param($s, $e)
            if ($e.Key -eq 'Return') { & $addMember; $e.Handled = $true }
        })
        $UIDlg.LstMembers.Add_KeyDown({
            param($s, $e)
            if ($e.Key -eq 'Delete') { & $removeMembers; $e.Handled = $true }
        })

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
            $script:_FormResult = [pscustomobject]@{
                Name           = $name
                Description    = "$($UIDlg.TxtDesc.Text)".Trim()
                Roles          = @($rolesCol)
                Members        = @($membersCol)
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

    function Show-RoleForm {
        param(
            [string]$Title              = 'New management role',
            [string]$DefaultName        = '',
            [string]$DefaultParent      = '',
            [string]$DefaultDescription = '',
            [string[]]$DefaultCmdlets   = @(),
            [bool]$NameReadOnly         = $false,
            [bool]$ParentReadOnly       = $false,
            [bool]$ShowCmdlets          = $false
        )
        $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="" Width="620" Height="660" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" Background="White" ResizeMode="CanResize" ShowInTaskbar="False">
$($script:DlgResourcesXaml)
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,0,0,1" Padding="20,16">
      <StackPanel>
        <TextBlock x:Name="DlgTitle" FontSize="16" FontWeight="SemiBold" Foreground="#201F1E"/>
        <TextBlock Text="Pick a parent role and (optionally) trim its cmdlet set."
                   FontSize="12" Foreground="#605E5C" Margin="0,2,0,0"/>
      </StackPanel>
    </Border>

    <Border Grid.Row="1" Padding="20,16">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="120"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="Name" Style="{StaticResource DlgLabel}"/>
        <TextBox  x:Name="TxtName" Grid.Row="1" Style="{StaticResource DlgTextBox}" Margin="0,0,0,12"/>

        <TextBlock Grid.Row="2" Text="Parent role (built-in or custom)" Style="{StaticResource DlgLabel}"/>
        <ComboBox x:Name="TxtParent" Grid.Row="3" Style="{StaticResource DlgComboBox}" Margin="0,0,0,12"
                  IsEditable="True" StaysOpenOnEdit="True"
                  ToolTip="Type to search or pick from the list of existing management roles."/>

        <TextBlock Grid.Row="4" Text="Description" Style="{StaticResource DlgLabel}"/>
        <TextBox  x:Name="TxtDesc" Grid.Row="5" Style="{StaticResource DlgTextBox}" Margin="0,0,0,12"
                  AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>

        <!-- Cmdlets editor (only shown when editing) -->
        <TextBlock x:Name="LblCmdlets" Grid.Row="6" Text="Cmdlets" Style="{StaticResource DlgLabel}"
                   Visibility="Collapsed"/>
        <Grid x:Name="GrdCmdlets" Grid.Row="7" Visibility="Collapsed">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <Grid Grid.Row="0" Margin="0,0,0,6">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <ComboBox x:Name="CmbCmdletAdd" Grid.Column="0" Style="{StaticResource DlgComboBox}" IsEditable="True"
                      StaysOpenOnEdit="True"
                      ToolTip="Pick from available Exchange Online cmdlets or type a name"/>
            <Button   x:Name="BtnCmdletAdd"    Grid.Column="1" Content="Add"    Style="{StaticResource DlgBtn}" Margin="6,0,0,0"/>
            <Button   x:Name="BtnCmdletRemove" Grid.Column="2" Content="Remove" Style="{StaticResource DlgBtn}" Margin="6,0,0,0"/>
          </Grid>
          <ListBox x:Name="LstCmdlets" Grid.Row="1" Style="{StaticResource DlgListBox}"
                   SelectionMode="Extended" FontFamily="Consolas"/>
        </Grid>
      </Grid>
    </Border>

    <Border Grid.Row="2" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,1,0,0" Padding="20,12">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BtnCancel" Content="Cancel" Style="{StaticResource DlgBtn}"        Margin="0,0,8,0" IsCancel="True"/>
        <Button x:Name="BtnOk"     Content="OK"     Style="{StaticResource DlgBtnPrimary}" IsDefault="True"/>
      </StackPanel>
    </Border>
  </Grid>
</Window>
"@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $w = [System.Windows.Markup.XamlReader]::Load($reader); $w.Title = $Title; $w.Owner = $window
        $w.FindName('DlgTitle').Text = $Title
        $UIDlg = @{}
        foreach ($n in @('TxtName','TxtParent','TxtDesc',
                         'LblCmdlets','GrdCmdlets','CmbCmdletAdd','BtnCmdletAdd','BtnCmdletRemove','LstCmdlets',
                         'BtnOk','BtnCancel')) { $UIDlg[$n] = $w.FindName($n) }
        $UIDlg.TxtName.Text   = $DefaultName
        $UIDlg.TxtDesc.Text   = $DefaultDescription
        $UIDlg.TxtName.IsReadOnly = $NameReadOnly

        # Populate the parent ComboBox with the cached list of management roles
        # (loaded from the Roles view, or fetched on-demand if missing).
        try {
            if (-not $script:Cache.Roles -or @($script:Cache.Roles).Count -eq 0) {
                $script:Cache.Roles = Get-RBACRoles
            }
            $parentNames = @($script:Cache.Roles | ForEach-Object Name | Sort-Object -Unique)
            $UIDlg.TxtParent.ItemsSource = $parentNames
        }
        catch { $UIDlg.TxtParent.ItemsSource = @() }
        $UIDlg.TxtParent.Text       = $DefaultParent
        $UIDlg.TxtParent.IsEnabled  = -not $ParentReadOnly

        # Cmdlets editor: backing collection + Add/Remove handlers.
        $cmdletsCol = New-Object System.Collections.ObjectModel.ObservableCollection[string]
        foreach ($c in $DefaultCmdlets) { if ($c) { $cmdletsCol.Add([string]$c) } }
        $UIDlg.LstCmdlets.ItemsSource = $cmdletsCol

        if ($ShowCmdlets) {
            $UIDlg.LblCmdlets.Visibility = 'Visible'
            $UIDlg.GrdCmdlets.Visibility = 'Visible'
            # Suggest from the same source as the Command Lookup view (in-memory EOM session).
            try {
                Ensure-CommandSuggestions
                if ($script:CommandSuggestions) {
                    $UIDlg.CmbCmdletAdd.ItemsSource = $script:CommandSuggestions
                }
            }
            catch { }

            $addCmdlet = {
                $val = "$($UIDlg.CmbCmdletAdd.Text)".Trim()
                if (-not $val) { return }
                if ($cmdletsCol -notcontains $val) { $cmdletsCol.Add($val) }
                $UIDlg.CmbCmdletAdd.Text = ''
                $UIDlg.CmbCmdletAdd.Focus() | Out-Null
            }
            $removeCmdlets = {
                $sel = @($UIDlg.LstCmdlets.SelectedItems | ForEach-Object { "$_" })
                foreach ($s in $sel) { $null = $cmdletsCol.Remove($s) }
            }
            $UIDlg.BtnCmdletAdd.Add_Click($addCmdlet)
            $UIDlg.BtnCmdletRemove.Add_Click($removeCmdlets)
            $UIDlg.CmbCmdletAdd.Add_KeyDown({
                param($s, $e)
                if ($e.Key -eq 'Return') { & $addCmdlet; $e.Handled = $true }
            })
            $UIDlg.LstCmdlets.Add_KeyDown({
                param($s, $e)
                if ($e.Key -eq 'Delete') { & $removeCmdlets; $e.Handled = $true }
            })
        }

        $script:_FormResult = $null
        $UIDlg.BtnOk.Add_Click({
            $name   = "$($UIDlg.TxtName.Text)".Trim()
            $parent = "$($UIDlg.TxtParent.Text)".Trim()
            if (-not $name) {
                [System.Windows.MessageBox]::Show('Name is required.', 'Missing field',
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return
            }
            $script:_FormResult = [pscustomobject]@{
                Name        = $name
                Parent      = $parent
                Description = "$($UIDlg.TxtDesc.Text)".Trim()
                Cmdlets     = @($cmdletsCol)
            }
            $w.DialogResult = $true; $w.Close()
        })
        $UIDlg.BtnCancel.Add_Click({ $w.DialogResult = $false; $w.Close() })
        if ($w.ShowDialog()) { return $script:_FormResult }
        return $null
    }

    function Show-AssignmentForm {
        param(
            [string]$Title          = 'New role assignment',
            [string]$DefaultName    = '',
            [string]$DefaultRole    = '',
            [string]$DefaultAssigneeKind = 'SecurityGroup',
            [string]$DefaultAssignee     = '',
            [string]$DefaultRecipientOrganizationalUnitScope = '',
            [string]$DefaultCustomRecipientWriteScope        = ''
        )
        $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="" Width="600" Height="560" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" Background="White" ResizeMode="CanResize" ShowInTaskbar="False">
$($script:DlgResourcesXaml)
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,0,0,1" Padding="20,16">
      <StackPanel>
        <TextBlock x:Name="DlgTitle" FontSize="16" FontWeight="SemiBold" Foreground="#201F1E"/>
        <TextBlock Text="Bind a role to an assignee, optionally restricted by a recipient scope."
                   FontSize="12" Foreground="#605E5C" Margin="0,2,0,0" TextWrapping="Wrap"/>
      </StackPanel>
    </Border>

    <Border Grid.Row="1" Padding="20,16">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="Assignment name" Style="{StaticResource DlgLabel}"/>
        <TextBox  x:Name="TxtName" Grid.Row="1" Style="{StaticResource DlgTextBox}" Margin="0,0,0,12"/>

        <TextBlock Grid.Row="2" Text="Role" Style="{StaticResource DlgLabel}"/>
        <TextBox  x:Name="TxtRole" Grid.Row="3" Style="{StaticResource DlgTextBox}" Margin="0,0,0,12"/>

        <TextBlock Grid.Row="4" Text="Assignee kind" Style="{StaticResource DlgLabel}"/>
        <ComboBox x:Name="CmbKind" Grid.Row="5" Style="{StaticResource DlgComboBox}" Margin="0,0,0,12">
          <ComboBoxItem Content="SecurityGroup"/>
          <ComboBoxItem Content="User"/>
          <ComboBoxItem Content="Computer"/>
          <ComboBoxItem Content="Policy"/>
          <ComboBoxItem Content="App"/>
        </ComboBox>

        <TextBlock Grid.Row="6" Text="Assignee (UPN, alias or DN)" Style="{StaticResource DlgLabel}"/>
        <TextBox  x:Name="TxtAssignee" Grid.Row="7" Style="{StaticResource DlgTextBox}" Margin="0,0,0,12"/>

        <TextBlock Grid.Row="8" Text="Optional · RecipientOrganizationalUnitScope (DN)" Style="{StaticResource DlgLabel}"/>
        <TextBox  x:Name="TxtOuScope" Grid.Row="9" Style="{StaticResource DlgTextBox}" Margin="0,0,0,12"/>

        <TextBlock Grid.Row="10" Text="Optional · CustomRecipientWriteScope (existing scope name)" Style="{StaticResource DlgLabel}"/>
        <TextBox  x:Name="TxtCustomScope" Grid.Row="11" Style="{StaticResource DlgTextBox}"/>
      </Grid>
    </Border>

    <Border Grid.Row="2" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,1,0,0" Padding="20,12">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BtnCancel" Content="Cancel" Style="{StaticResource DlgBtn}"        Margin="0,0,8,0" IsCancel="True"/>
        <Button x:Name="BtnOk"     Content="OK"     Style="{StaticResource DlgBtnPrimary}" IsDefault="True"/>
      </StackPanel>
    </Border>
  </Grid>
</Window>
"@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $w = [System.Windows.Markup.XamlReader]::Load($reader); $w.Title = $Title; $w.Owner = $window
        $w.FindName('DlgTitle').Text = $Title
        $UIDlg = @{}
        foreach ($n in @('TxtName','TxtRole','CmbKind','TxtAssignee','TxtOuScope','TxtCustomScope','BtnOk','BtnCancel')) {
            $UIDlg[$n] = $w.FindName($n)
        }
        $UIDlg.TxtName.Text     = $DefaultName
        $UIDlg.TxtRole.Text     = $DefaultRole
        $UIDlg.TxtAssignee.Text = $DefaultAssignee
        $UIDlg.TxtOuScope.Text  = $DefaultRecipientOrganizationalUnitScope
        $UIDlg.TxtCustomScope.Text = $DefaultCustomRecipientWriteScope
        foreach ($it in $UIDlg.CmbKind.Items) {
            if ($it.Content -eq $DefaultAssigneeKind) { $UIDlg.CmbKind.SelectedItem = $it; break }
        }
        if (-not $UIDlg.CmbKind.SelectedItem) { $UIDlg.CmbKind.SelectedIndex = 0 }

        $script:_FormResult = $null
        $UIDlg.BtnOk.Add_Click({
            $name      = "$($UIDlg.TxtName.Text)".Trim()
            $role      = "$($UIDlg.TxtRole.Text)".Trim()
            $assignee  = "$($UIDlg.TxtAssignee.Text)".Trim()
            $kind      = "$($UIDlg.CmbKind.SelectedItem.Content)"
            if (-not $name -or -not $role -or -not $assignee) {
                [System.Windows.MessageBox]::Show('Name, Role and Assignee are required.', 'Missing field',
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return
            }
            $script:_FormResult = [pscustomobject]@{
                Name         = $name
                Role         = $role
                AssigneeKind = $kind
                Assignee     = $assignee
                RecipientOrganizationalUnitScope = "$($UIDlg.TxtOuScope.Text)".Trim()
                CustomRecipientWriteScope        = "$($UIDlg.TxtCustomScope.Text)".Trim()
            }
            $w.DialogResult = $true; $w.Close()
        })
        $UIDlg.BtnCancel.Add_Click({ $w.DialogResult = $false; $w.Close() })
        if ($w.ShowDialog()) { return $script:_FormResult }
        return $null
    }

    function Show-ScopeForm {
        param(
            [string]$Title           = 'New management scope',
            [string]$DefaultName     = '',
            [string]$DefaultNewName  = '',
            [string]$DefaultRoot     = '',
            [string]$DefaultFilter   = '',
            [bool]$NameReadOnly      = $false,
            [bool]$ShowNewName       = $false
        )
        $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="" Width="600" Height="500" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" Background="White" ResizeMode="CanResize" ShowInTaskbar="False">
$($script:DlgResourcesXaml)
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,0,0,1" Padding="20,16">
      <StackPanel>
        <TextBlock x:Name="DlgTitle" FontSize="16" FontWeight="SemiBold" Foreground="#201F1E"/>
        <TextBlock Text="Restrict where a role applies - by OU, by recipient filter, or both."
                   FontSize="12" Foreground="#605E5C" Margin="0,2,0,0" TextWrapping="Wrap"/>
      </StackPanel>
    </Border>

    <Border Grid.Row="1" Padding="20,16">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="Name" Style="{StaticResource DlgLabel}"/>
        <TextBox  x:Name="TxtName" Grid.Row="1" Style="{StaticResource DlgTextBox}" Margin="0,0,0,12"/>

        <TextBlock x:Name="LblNewName" Grid.Row="2" Text="New name (rename)" Style="{StaticResource DlgLabel}" Visibility="Collapsed"/>
        <TextBox  x:Name="TxtNewName" Grid.Row="3" Style="{StaticResource DlgTextBox}" Margin="0,0,0,12" Visibility="Collapsed"/>

        <TextBlock Grid.Row="4" Text="Recipient root (OU DN, optional)" Style="{StaticResource DlgLabel}"/>
        <TextBox  x:Name="TxtRoot" Grid.Row="5" Style="{StaticResource DlgTextBox}" Margin="0,0,0,12" FontFamily="Consolas"/>

        <TextBlock Grid.Row="6" Text="Recipient restriction filter (OPATH, optional)" Style="{StaticResource DlgLabel}"/>
        <TextBox  x:Name="TxtFilter" Grid.Row="7" Style="{StaticResource DlgTextBox}"
                  AcceptsReturn="True" TextWrapping="Wrap"
                  VerticalScrollBarVisibility="Auto" FontFamily="Consolas"/>
      </Grid>
    </Border>

    <Border Grid.Row="2" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,1,0,0" Padding="20,12">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BtnCancel" Content="Cancel" Style="{StaticResource DlgBtn}"        Margin="0,0,8,0" IsCancel="True"/>
        <Button x:Name="BtnOk"     Content="OK"     Style="{StaticResource DlgBtnPrimary}" IsDefault="True"/>
      </StackPanel>
    </Border>
  </Grid>
</Window>
"@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $w = [System.Windows.Markup.XamlReader]::Load($reader); $w.Title = $Title; $w.Owner = $window
        $w.FindName('DlgTitle').Text = $Title
        $UIDlg = @{}
        foreach ($n in @('TxtName','LblNewName','TxtNewName','TxtRoot','TxtFilter','BtnOk','BtnCancel')) {
            $UIDlg[$n] = $w.FindName($n)
        }
        $UIDlg.TxtName.Text   = $DefaultName
        $UIDlg.TxtName.IsReadOnly = $NameReadOnly
        $UIDlg.TxtRoot.Text   = $DefaultRoot
        $UIDlg.TxtFilter.Text = $DefaultFilter
        if ($ShowNewName) {
            $UIDlg.LblNewName.Visibility = 'Visible'
            $UIDlg.TxtNewName.Visibility = 'Visible'
            $UIDlg.TxtNewName.Text = $DefaultNewName
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
            $script:_FormResult = [pscustomobject]@{
                Name        = $name
                NewName     = "$($UIDlg.TxtNewName.Text)".Trim()
                Root        = "$($UIDlg.TxtRoot.Text)".Trim()
                Filter      = "$($UIDlg.TxtFilter.Text)".Trim()
            }
            $w.DialogResult = $true; $w.Close()
        })
        $UIDlg.BtnCancel.Add_Click({ $w.DialogResult = $false; $w.Close() })
        if ($w.ShowDialog()) { return $script:_FormResult }
        return $null
    }

    function Handle-WriteResult {
        <#
        Takes the dry-run result of a write action, shows the cmdlet preview to
        the user and - if they click "Run cmdlet" - invokes the supplied
        RunBlock to execute the action live.
        Returns $true when the live action ran successfully, $false otherwise.
        #>
        param(
            [Parameter(Mandatory)] $Result,
            [Parameter(Mandatory)] [string]$SuccessMsg,
            [Parameter(Mandatory)] [string]$Title,
            [Parameter(Mandatory)] [scriptblock]$RunBlock
        )
        if ($null -eq $Result) { return $false }

        # Aggregate preview text from a single result or an array of step results.
        $previewText = ''
        if ($Result -is [System.Array]) {
            $errs = @($Result | Where-Object { $_.Error })
            if ($errs.Count -gt 0) {
                Set-Status "Error: $($errs[0].Error.Exception.Message)" 'error'
                return $false
            }
            $previewText = (@($Result | ForEach-Object { $_.Preview } | Where-Object { $_ })) -join "`r`n"
        }
        elseif ($Result.Error) {
            Set-Status "Error: $($Result.Error.Exception.Message)" 'error'
            return $false
        }
        else {
            $previewText = [string]$Result.Preview
        }

        # Always show the preview; the user picks Run / Copy / Cancel.
        if (-not (Show-CmdletPreview -Title $Title -Cmdlet $previewText)) {
            Set-Status 'Cancelled. Nothing executed.' 'info'
            return $false
        }

        # User chose Run: execute the live action.
        try {
            $runResult = & $RunBlock

            # The RBAC write helpers (Invoke-RBACWrite) catch Exchange errors
            # internally and RETURN a result object (@{ Executed; Error }) rather
            # than throwing - so a failed live action would otherwise be reported
            # as a false success. Inspect the returned object(s) and surface the
            # real error instead of the success message.
            $failed = @($runResult) | Where-Object {
                $_ -and $_.PSObject.Properties.Match('Error').Count -gt 0 -and $_.Error
            }
            if ($failed.Count -gt 0) {
                $msg = "$($failed[0].Error.Exception.Message)"
                if (-not $msg) { $msg = "$($failed[0].Error)" }
                Set-Status "Error: $msg" 'error'
                return $false
            }
            # Some helpers flag an action that did not run (Executed = $false)
            # without an Error object; treat that as a failure too.
            $notRun = @($runResult) | Where-Object {
                $_ -and $_.PSObject.Properties.Match('Executed').Count -gt 0 -and -not $_.Executed
            }
            if ($notRun.Count -gt 0) {
                Set-Status 'The action did not complete - nothing was changed.' 'error'
                return $false
            }

            Set-Status $SuccessMsg 'ok'
            return $true
        }
        catch {
            Set-Status "Error: $($_.Exception.Message)" 'error'
            return $false
        }
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
                @{ Header='Origin';      Path='Origin';      Width=100; MinWidth=90;  Kind='Badge'; BadgeMap=$BadgeOrigin }
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
            Chips  = @('all','implicit','recipient','server')
            FrozenColumns = 1
            Columns = @(
                @{ Header='Scope Name';       Path='Name';                  Width=220; MinWidth=140 }
                @{ Header='Origin';           Path='Origin';                Width=100; MinWidth=90;  Kind='Badge'; BadgeMap=$BadgeOrigin }
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
        MyCmdlets = @{
            Crumbs = 'RBAC ▸ My Cmdlets'
            Title  = 'My Cmdlets'
            Desc   = 'Cmdlets the connected account can run in this session, with their parameters.'
            Chips  = @()
            FrozenColumns = 1
            Columns = @(
                @{ Header='Cmdlet';     Path='Name';       Width=320; MinWidth=200 }
                @{ Header='Parameters'; Path='Parameters'; Width='*'; MinWidth=320 }
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
    # Sync the toggle visuals with the default state.
    if ($UI.BtnFilterRow) { $UI.BtnFilterRow.IsChecked = $script:FilterRowEnabled }
    if ($UI.BtnWrap)      { $UI.BtnWrap.IsChecked      = $script:WrapEnabled }
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

    # Debounce the Command Lookup typeahead so each keystroke stays snappy - the
    # match loop (and the first Get-Command warm-up) runs after a short pause
    # instead of on every character.
    $script:SuggestDebounceTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $script:SuggestDebounceTimer.Interval = [TimeSpan]::FromMilliseconds(120)
    $script:SuggestDebounceTimer.Add_Tick({
        $script:SuggestDebounceTimer.Stop()
        Update-SuggestPopup
    })

    function Schedule-SuggestUpdate {
        $script:SuggestDebounceTimer.Stop()
        $script:SuggestDebounceTimer.Start()
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

            # ---- Header: label + sort arrow + optional filter TextBox ----
            $headerPanel = [System.Windows.Controls.StackPanel]::new()
            $headerPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical

            # Inline row: label on the left, sort arrow on the right.
            $titleRow = [System.Windows.Controls.StackPanel]::new()
            $titleRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal
            $headerLabel = [System.Windows.Controls.TextBlock]::new()
            $headerLabel.Text       = ([string]$c.Header).ToUpperInvariant()
            $headerLabel.FontWeight = [System.Windows.FontWeights]::SemiBold
            $headerLabel.FontSize   = 11
            $headerLabel.Foreground = (New-Brush '#323130')
            $headerLabel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $null = $titleRow.Children.Add($headerLabel)

            # Sort arrow - visibility/glyph driven by the parent DataGridColumnHeader's
            # SortDirection via DataTriggers (no direct event wiring needed).
            $sortArrow = [System.Windows.Controls.TextBlock]::new()
            $sortArrow.FontSize    = 9
            $sortArrow.Margin      = '4,0,0,0'
            $sortArrow.Foreground  = (New-Brush '#0078D4')
            $sortArrow.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $sortStyle = [System.Windows.Style]::new([System.Windows.Controls.TextBlock])
            $sortStyle.Setters.Add([System.Windows.Setter]::new(
                [System.Windows.UIElement]::VisibilityProperty,
                [System.Windows.Visibility]::Collapsed))
            # Ascending → ▲
            $dtAsc = [System.Windows.DataTrigger]::new()
            $dtAsc.Binding = [System.Windows.Data.Binding]::new('Column.SortDirection')
            $dtAsc.Binding.RelativeSource = [System.Windows.Data.RelativeSource]::new(
                [System.Windows.Data.RelativeSourceMode]::FindAncestor,
                [System.Windows.Controls.Primitives.DataGridColumnHeader], 1)
            $dtAsc.Value = [System.ComponentModel.ListSortDirection]::Ascending
            $dtAsc.Setters.Add([System.Windows.Setter]::new(
                [System.Windows.Controls.TextBlock]::TextProperty, [string]'▲'))
            $dtAsc.Setters.Add([System.Windows.Setter]::new(
                [System.Windows.UIElement]::VisibilityProperty,
                [System.Windows.Visibility]::Visible))
            $sortStyle.Triggers.Add($dtAsc)
            # Descending → ▼
            $dtDesc = [System.Windows.DataTrigger]::new()
            $dtDesc.Binding = [System.Windows.Data.Binding]::new('Column.SortDirection')
            $dtDesc.Binding.RelativeSource = [System.Windows.Data.RelativeSource]::new(
                [System.Windows.Data.RelativeSourceMode]::FindAncestor,
                [System.Windows.Controls.Primitives.DataGridColumnHeader], 1)
            $dtDesc.Value = [System.ComponentModel.ListSortDirection]::Descending
            $dtDesc.Setters.Add([System.Windows.Setter]::new(
                [System.Windows.Controls.TextBlock]::TextProperty, [string]'▼'))
            $dtDesc.Setters.Add([System.Windows.Setter]::new(
                [System.Windows.UIElement]::VisibilityProperty,
                [System.Windows.Visibility]::Visible))
            $sortStyle.Triggers.Add($dtDesc)
            $sortArrow.Style = $sortStyle
            $null = $titleRow.Children.Add($sortArrow)

            # Mirror the cell alignment in the header so numeric columns line up.
            if ($c.Align -eq 'Right') {
                $titleRow.HorizontalAlignment    = [System.Windows.HorizontalAlignment]::Right
                $headerPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
            }
            $null = $headerPanel.Children.Add($titleRow)
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
        # IsChecked is the source of truth (set by the ToggleButton itself when clicked).
        $script:FilterRowEnabled = [bool]$UI.BtnFilterRow.IsChecked
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
        $script:WrapEnabled = [bool]$UI.BtnWrap.IsChecked
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

        # Item-type chip in the header - derived from the current view name.
        $badgeMap = @{
            RoleGroups  = 'ROLE GROUP'
            Roles       = 'ROLE'
            Assignments = 'ASSIGNMENT'
            Scopes      = 'SCOPE'
            UserRights  = 'USER RIGHT'
            Commands    = 'ROLE'
            MyCmdlets   = 'CMDLET'
            Audit       = 'AUDIT EVENT'
        }
        $badgeText = $badgeMap[$script:CurrentView]
        if ($badgeText) {
            $UI.DetailsTypeBadgeText.Text = $badgeText
            $UI.DetailsTypeBadge.Visibility = 'Visible'
        }
        else {
            $UI.DetailsTypeBadge.Visibility = 'Collapsed'
        }

        # Map raw property names (Path) to user-facing labels (Header) using the current
        # view's column config - keeps the details panel consistent with the grid headers.
        $labelMap = @{}
        $cfg = $script:Views[$script:CurrentView]
        if ($cfg -and $cfg.Columns) {
            foreach ($c in $cfg.Columns) {
                if ($c.Path -and $c.Header) { $labelMap[[string]$c.Path] = [string]$c.Header }
            }
        }

        $rows = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
        foreach ($p in $Item.PSObject.Properties) {
            if ($p.Name -like '_*') { continue }
            $val = "$($p.Value)"
            if ([string]::IsNullOrEmpty($val)) { $val = '-' }
            $label = if ($labelMap.ContainsKey($p.Name)) { $labelMap[$p.Name] } else { $p.Name }
            $rows.Add([PSCustomObject]@{ Key = $label; Value = $val })
        }

        # In the Scopes view, list which role assignments reference this scope
        # (as CustomRecipientReadScope, CustomRecipientWriteScope, or as the
        # resolved Read/Write scope name). Sourced from the cached assignments
        # if available so it doesn't trigger an extra round-trip - if the cache
        # is empty we load it once and reuse it.
        if ($script:CurrentView -eq 'Scopes' -and $Item.Name) {
            $assignments = $script:Cache.Assignments
            if (-not $assignments) {
                try {
                    $assignments = @(Get-RBACRoleAssignments)
                    $script:Cache.Assignments = $assignments
                }
                catch { $assignments = @() }
            }
            $scopeName = "$($Item.Name)"
            $used = @($assignments | Where-Object {
                "$($_.CustomRecipientReadScope)"  -eq $scopeName -or
                "$($_.CustomRecipientWriteScope)" -eq $scopeName -or
                "$($_.RecipientReadScope)"        -like "*$scopeName*" -or
                "$($_.RecipientWriteScope)"       -like "*$scopeName*"
            } | Sort-Object Name)
            $rows.Add([PSCustomObject]@{
                Key   = "Used by ($($used.Count) assignment$(if ($used.Count -eq 1) { '' } else { 's' }))"
                Value = ''
            })
            if ($used.Count -eq 0) {
                $rows.Add([PSCustomObject]@{ Key = ''; Value = '(not referenced by any assignment)' })
            }
            else {
                foreach ($a in $used) {
                    $where = if    ("$($a.CustomRecipientReadScope)"  -eq $scopeName) { 'read' }
                             elseif ("$($a.CustomRecipientWriteScope)" -eq $scopeName) { 'write' }
                             else { 'scope' }
                    $rows.Add([PSCustomObject]@{
                        Key   = ''
                        Value = "$($a.Name) [$where -> $($a.Role)]"
                    })
                }
            }
        }

        # In the Roles view, append the role's cmdlets below the property rows.
        # Cache per role so reselecting the same role doesn't re-hit the service.
        if ($script:CurrentView -eq 'Roles' -and $Item.Name) {
            if (-not $script:Cache.RoleCmdlets) { $script:Cache.RoleCmdlets = @{} }
            $cmdletNames = $script:Cache.RoleCmdlets[$Item.Name]
            if (-not $cmdletNames) {
                try {
                    $entries = Get-ManagementRoleEntry -Identity "$($Item.Name)\*" -ErrorAction Stop
                    $cmdletNames = @($entries | ForEach-Object Name | Sort-Object)
                    $script:Cache.RoleCmdlets[$Item.Name] = $cmdletNames
                }
                catch { $cmdletNames = @() }
            }
            if ($cmdletNames.Count -gt 0) {
                $rows.Add([PSCustomObject]@{
                    Key   = "Cmdlets ($($cmdletNames.Count))"
                    Value = ''
                })
                foreach ($n in $cmdletNames) {
                    $rows.Add([PSCustomObject]@{ Key = ''; Value = $n })
                }
            }
        }

        $UI.DetailsList.ItemsSource = $rows
        # Grid rows don't drive the "Open in ..." navigation (that's a Visualizer-node
        # affordance), so clear any leftover target and hide the button.
        $script:DetailsNavTarget = $null
        if ($UI.BtnDetailsGoto) { $UI.BtnDetailsGoto.Visibility = 'Collapsed' }
        $UI.DetailsCol.Width = New-Object System.Windows.GridLength 360
        $UI.DetailsPanel.Visibility = 'Visible'
    }
    function Hide-Details {
        $UI.DetailsPanel.Visibility = 'Collapsed'
        $UI.DetailsCol.Width = New-Object System.Windows.GridLength 0
        $UI.DetailsList.ItemsSource = $null
        $script:DetailsNavTarget = $null
        if ($UI.BtnDetailsGoto) { $UI.BtnDetailsGoto.Visibility = 'Collapsed' }
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
        if (-not $a) { $UI.VizPlaceholderBox.Visibility = 'Visible'; return }
        $UI.VizPlaceholderBox.Visibility = 'Collapsed'

        # -- Initial layout dimensions -------------------------------------
        $baseW = 1000; $baseH = 600
        $cx = $baseW / 2; $cy = $baseH / 2
        $hubR = 70

        # -- Fetch + classify the role's cmdlets ---------------------------
        # Same-verb cmdlets are placed contiguously around the role node and
        # share a colour palette so the diagram instantly conveys "this role
        # grants 5 reads, 3 writes, 1 delete". The classification/sort lives in
        # Get-VizClassifiedEntries so the HTML export reuses it verbatim.
        $verbPalettes = $script:VizVerbPalettes
        $allEntries   = Get-VizClassifiedEntries -Role $a.Role

        # Scope display: prefer the custom scope *name* (e.g. "Sales recipients")
        # over the bare RecipientWriteScope type ("CustomRecipientScope") or the
        # pre-formatted "Custom: <name> (Filter: <opath>)" string, which is too
        # noisy to read on a node.
        $writeScopeName = Get-VizScopeDisplay -Assignment $a -Which Write
        $readScopeName  = Get-VizScopeDisplay -Assignment $a -Which Read
        $scopeSub = "Read: $readScopeName"
        if ($null -ne $script:VizScopeMembers) {
            $mCount   = @($script:VizScopeMembers).Count
            $scopeSub = "Read: $readScopeName`n$mCount member$(if ($mCount -eq 1) { '' } else { 's' })$(if ($script:VizScopeTruncated) { '+' } else { '' })"
        }

        $spokes = @(
            @{ Label='What · Role';     Name=$a.Role;          Sub='';              Bg='#DFF6DD'; X=$cx - 280; Y=$cy - 200 }
            @{ Label='Who · Assignee';  Name=$a.RoleAssignee;  Sub=$a.RoleAssigneeType; Bg='#FFF4CE'; X=$cx + 100; Y=$cy - 200 }
            @{ Label='Where · Scope';   Name=$writeScopeName;  Sub=$scopeSub;       Bg='#FCE4E4'; X=$cx - 100; Y=$cy + 130 }
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
        $cmdletPositions = [System.Collections.Generic.List[hashtable]]::new()
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

            $null = $cmdletPositions.Add(@{
                X     = $x
                Y     = $y
                NcX   = $ncX
                NcY   = $ncY
                Angle = $angle
                Ring  = $ring
            })

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

        # -- Scope member positioning (only when the user resolved them) ----
        # Members fan out around the Scope spoke the same way cmdlets fan around
        # the Role node: rings of nodes pointing away from the hub.
        $scopeS   = $spokes[2]
        $scopeNcX = $scopeS.X + $nodeW / 2
        $scopeNcY = $scopeS.Y + $nodeH / 2
        $svx = $scopeNcX - $cx; $svy = $scopeNcY - $cy
        $svlen = [Math]::Sqrt($svx * $svx + $svy * $svy)
        if ($svlen -gt 0) { $svx /= $svlen; $svy /= $svlen }
        $scopeBaseAngle = [Math]::Atan2($svy, $svx)

        $memberNodeW    = 150
        $memberNodeH    = 22
        $memBaseRadius  = 130
        $memRingSpacing = 60
        $memItemsPerRing = 12
        $memberPositions = [System.Collections.Generic.List[hashtable]]::new()
        # Filter out nulls: @($null) yields a 1-element array holding $null, which
        # would otherwise draw a single empty "phantom" member node before the user
        # has resolved any members.
        $members = @($script:VizScopeMembers | Where-Object { $null -ne $_ })
        for ($i = 0; $i -lt $members.Count; $i++) {
            $ring      = [int]($i / $memItemsPerRing)
            $posInRing = $i % $memItemsPerRing
            $radius    = $memBaseRadius + $ring * $memRingSpacing
            $angle     = $scopeBaseAngle + 2 * [Math]::PI * $posInRing / $memItemsPerRing

            $ncX = $scopeNcX + $radius * [Math]::Cos($angle)
            $ncY = $scopeNcY + $radius * [Math]::Sin($angle)
            $x   = $ncX - $memberNodeW / 2
            $y   = $ncY - $memberNodeH / 2

            $null = $memberPositions.Add(@{ X = $x; Y = $y; NcX = $ncX; NcY = $ncY; Angle = $angle; Ring = $ring })

            $bounds.minX = [Math]::Min($bounds.minX, $x)
            $bounds.maxX = [Math]::Max($bounds.maxX, $x + $memberNodeW)
            $bounds.minY = [Math]::Min($bounds.minY, $y)
            $bounds.maxY = [Math]::Max($bounds.maxY, $y + $memberNodeH)
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
            param([System.Windows.Controls.Border]$elem, [array]$Links = @(), $NodeInfo = $null)
            $elem.Tag = @{
                Links    = $Links
                NodeInfo = $NodeInfo
                Drag     = $false
                Moved    = $false
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
                $t.Moved  = $false
                $t.StartX = $p.X; $t.StartY = $p.Y
                $t.ElemX  = [System.Windows.Controls.Canvas]::GetLeft($s)
                $t.ElemY  = [System.Windows.Controls.Canvas]::GetTop($s)
                $null = $s.CaptureMouse()
                $e.Handled = $true   # prevent canvas pan from firing
            })
            $elem.Add_MouseLeftButtonUp({
                param($s, $e)
                $t = $s.Tag
                $t.Drag = $false
                $s.ReleaseMouseCapture()
                $e.Handled = $true
                # A press released without a real drag is a click -> open the
                # node's details in the slide-out panel.
                if (-not $t.Moved -and $t.NodeInfo -and $script:VizNodeDetailsAction) {
                    & $script:VizNodeDetailsAction $t.NodeInfo
                }
            })
            $elem.Add_MouseMove({
                param($s, $e)
                $t = $s.Tag
                if (-not $t.Drag) { return }
                $p = $e.GetPosition($t.Canvas)
                if (([Math]::Abs($p.X - $t.StartX) + [Math]::Abs($p.Y - $t.StartY)) -gt 3) { $t.Moved = $true }
                $newX = $t.ElemX + ($p.X - $t.StartX)
                $newY = $t.ElemY + ($p.Y - $t.StartY)
                [System.Windows.Controls.Canvas]::SetLeft($s, $newX)
                [System.Windows.Controls.Canvas]::SetTop($s, $newY)

                # Auto-grow the canvas so the dragged node never falls outside
                # the ScrollViewer's scrollable region. 60 = margin past the
                # element so users can keep dragging without hitting a wall.
                $needW = $newX + $s.ActualWidth  + 60
                $needH = $newY + $s.ActualHeight + 60
                if ($needW -gt $t.Canvas.Width)  { $t.Canvas.Width  = $needW }
                if ($needH -gt $t.Canvas.Height) { $t.Canvas.Height = $needH }
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
        $spokeLines = [System.Collections.Generic.List[System.Windows.Shapes.Line]]::new()
        foreach ($s in $spokes) {
            $line = [System.Windows.Shapes.Line]::new()
            $line.X1 = $cx + $offsetX; $line.Y1 = $cy + $offsetY
            $line.X2 = $s.X + 90 + $offsetX; $line.Y2 = $s.Y + 30 + $offsetY
            $line.Stroke = '#605E5C'
            $line.StrokeThickness = 1.5
            $null = $cv.Children.Add($line)
            $null = $spokeLines.Add($line)
        }

        # -- Edges: role node → cmdlet nodes (stored too) -----------------
        $dashes = [System.Windows.Media.DoubleCollection]::new()
        $null = $dashes.Add(4.0)
        $null = $dashes.Add(2.0)

        $cmdletLines  = [System.Collections.Generic.List[System.Windows.Shapes.Line]]::new()
        $cmdletArrows = [System.Collections.Generic.List[System.Windows.Shapes.Polygon]]::new()
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
            $null = $cmdletLines.Add($line)
            $null = $cmdletArrows.Add($arrow)
        }

        # -- Edges: scope node → member nodes (stored too) ----------------
        $memberLines  = [System.Collections.Generic.List[System.Windows.Shapes.Line]]::new()
        $memberArrows = [System.Collections.Generic.List[System.Windows.Shapes.Polygon]]::new()
        for ($i = 0; $i -lt $memberPositions.Count; $i++) {
            $pos  = $memberPositions[$i]
            $line = [System.Windows.Shapes.Line]::new()
            $line.X1 = $scopeNcX + $offsetX; $line.Y1 = $scopeNcY + $offsetY
            $line.X2 = $pos.NcX  + $offsetX; $line.Y2 = $pos.NcY  + $offsetY
            $line.Stroke          = $script:VizMemberPalette.Border
            $line.StrokeThickness = 1.0
            $line.StrokeDashArray = $dashes
            $null = $cv.Children.Add($line)
            $arrow = & $addArrow $cv ($pos.NcX + $offsetX) ($pos.NcY + $offsetY) $pos.Angle $script:VizMemberPalette.Border
            $null = $memberLines.Add($line)
            $null = $memberArrows.Add($arrow)
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
        $hubLinks = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($l in $spokeLines) {
            $null = $hubLinks.Add(@{ Line = $l; End = 'start'; OffsetX = $hubR; OffsetY = $hubR })
        }
        # Per-group cmdlet breakdown, reused by the hub + role node details.
        $grpCounts = @{}
        foreach ($e in $allEntries) {
            if (-not $grpCounts.ContainsKey($e.CmdletGroup)) { $grpCounts[$e.CmdletGroup] = 0 }
            $grpCounts[$e.CmdletGroup]++
        }
        $groupSummary = (@('Read','Modify','Destructive','Create','Other') | Where-Object { $grpCounts[$_] } |
            ForEach-Object { "$_ $($grpCounts[$_])" }) -join ' · '
        $hubInfo = @{
            Title = "$($a.Name)"; Badge = 'ASSIGNMENT'
            Nav   = @{ View='Assignments'; Name="$($a.Name)"; Label='Open in Role Assignments' }
            Rows = @(
                [pscustomobject]@{ Key='Role';          Value="$($a.Role)" }
                [pscustomobject]@{ Key='Assignee';      Value="$($a.RoleAssignee)" }
                [pscustomobject]@{ Key='Assignee type'; Value="$($a.RoleAssigneeType)" }
                [pscustomobject]@{ Key='Write scope';   Value=$writeScopeName }
                [pscustomobject]@{ Key='Read scope';    Value=$readScopeName }
                [pscustomobject]@{ Key='Enabled';       Value="$($a.Enabled)" }
                [pscustomobject]@{ Key='Cmdlets';       Value="$($allEntries.Count)" }
            )
        }
        & $makeDraggable $hub $hubLinks $hubInfo

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
            $links = [System.Collections.Generic.List[hashtable]]::new()
            $null = $links.Add(@{ Line = $spokeLines[$si]; End = 'end'; OffsetX = 100; OffsetY = 30; Arrow = $null })
            # The Role spoke (index 0) also anchors the START of every cmdlet line + its arrow.
            if ($si -eq 0) {
                for ($ci = 0; $ci -lt $cmdletLines.Count; $ci++) {
                    $null = $links.Add(@{
                        Line    = $cmdletLines[$ci]
                        End     = 'start'
                        OffsetX = $nodeW / 2
                        OffsetY = $nodeH / 2
                        Arrow   = $cmdletArrows[$ci]
                    })
                }
            }
            # The Scope spoke (index 2) anchors the START of every member line + its arrow.
            if ($si -eq 2) {
                for ($mi = 0; $mi -lt $memberLines.Count; $mi++) {
                    $null = $links.Add(@{
                        Line    = $memberLines[$mi]
                        End     = 'start'
                        OffsetX = $nodeW / 2
                        OffsetY = $nodeH / 2
                        Arrow   = $memberArrows[$mi]
                    })
                }
            }

            # Per-spoke details for the click-to-inspect panel.
            $spokeInfo = $null
            switch ($si) {
                0 {
                    $rows = @([pscustomobject]@{ Key='Cmdlets granted'; Value="$($allEntries.Count)" })
                    if ($groupSummary) { $rows += [pscustomobject]@{ Key='By group'; Value=$groupSummary } }
                    $spokeInfo = @{
                        Title="$($a.Role)"; Badge='ROLE'; Rows=$rows
                        Nav = @{ View='Roles'; Name="$($a.Role)"; Label='Open in Roles' }
                    }
                }
                1 {
                    $spokeInfo = @{
                        Title="$($a.RoleAssignee)"; Badge='ASSIGNEE'
                        Rows=@( [pscustomobject]@{ Key='Type'; Value="$($a.RoleAssigneeType)" } )
                        Nav = @{ View='UserRights'; Name="$($a.RoleAssignee)"; Label='Look up in User Rights' }
                    }
                }
                2 {
                    $rows = @(
                        [pscustomobject]@{ Key='Write scope'; Value=$writeScopeName }
                        [pscustomobject]@{ Key='Read scope';  Value=$readScopeName }
                    )
                    if ($script:VizScopeInfo) {
                        $f = ConvertTo-VizFilterString -RawFilter $script:VizScopeInfo.RecipientFilter
                        if ($f) { $rows += [pscustomobject]@{ Key='Recipient filter'; Value=$f } }
                        $root = "$($script:VizScopeInfo.RecipientRoot)".Trim()
                        if ($root) { $rows += [pscustomobject]@{ Key='Recipient root'; Value=$root } }
                    }
                    if ($null -ne $script:VizScopeMembers) {
                        $mc = @($script:VizScopeMembers | Where-Object { $null -ne $_ }).Count
                        $rows += [pscustomobject]@{ Key='Members resolved'; Value="$mc$(if ($script:VizScopeTruncated) { '+' } else { '' })" }
                    }
                    $spokeInfo = @{ Title=$writeScopeName; Badge='SCOPE'; Rows=$rows }
                    # Only custom scopes have a Scopes-view row to open.
                    $customScopeName = Get-VizScopeName -Assignment $a -Which Write
                    if ($customScopeName) {
                        $spokeInfo.Nav = @{ View='Scopes'; Name=$customScopeName; Label='Open in Scopes' }
                    }
                }
            }
            & $makeDraggable $node $links $spokeInfo
        }

        # -- Cmdlet nodes --------------------------------------------------
        for ($i = 0; $i -lt $allEntries.Count; $i++) {
            $pos   = $cmdletPositions[$i]
            $entry = $allEntries[$i]
            $pal   = $verbPalettes[$entry.CmdletGroup]
            $node  = [System.Windows.Controls.Border]::new()
            $node.Width        = $cmdletNodeW
            $node.CornerRadius = '3'
            $node.Background   = $pal.Bg
            $node.BorderBrush  = $pal.Border
            $node.BorderThickness = 1
            $node.Padding      = '5,2'
            $tb = [System.Windows.Controls.TextBlock]::new()
            $tb.Text        = if ($entry.CmdletShortName) { $entry.CmdletShortName } else { "$($entry.Name)" }
            $tb.FontSize    = 9; $tb.FontWeight = 'SemiBold'
            $tb.TextTrimming = 'CharacterEllipsis'; $tb.Foreground = $pal.Fg
            $tb.ToolTip = "$($entry.Name) [$($entry.CmdletGroup) - $($entry.CmdletVerb)]"
            $node.Child = $tb
            [System.Windows.Controls.Canvas]::SetLeft($node, $pos.X + $offsetX)
            [System.Windows.Controls.Canvas]::SetTop($node,  $pos.Y + $offsetY)
            $null = $cv.Children.Add($node)
            $links = [System.Collections.Generic.List[hashtable]]::new()
            $null = $links.Add(@{
                Line    = $cmdletLines[$i]
                End     = 'end'
                OffsetX = $cmdletNodeW / 2
                OffsetY = $cmdletNodeH / 2
                Arrow   = $cmdletArrows[$i]
            })
            $cmdInfo = @{
                Title="$($entry.CmdletShortName)"; Badge='CMDLET'
                Nav = @{ View='Commands'; Name="$($entry.CmdletShortName)"; Label='Look up in Command Lookup' }
                Rows=@(
                    [pscustomobject]@{ Key='Full name'; Value="$($entry.Name)" }
                    [pscustomobject]@{ Key='Group';     Value="$($entry.CmdletGroup)" }
                    [pscustomobject]@{ Key='Verb';      Value="$($entry.CmdletVerb)" }
                )
            }
            & $makeDraggable $node $links $cmdInfo
        }

        # -- Scope member nodes --------------------------------------------
        $memPal = $script:VizMemberPalette
        for ($i = 0; $i -lt $members.Count; $i++) {
            $pos  = $memberPositions[$i]
            $m    = $members[$i]
            $node = [System.Windows.Controls.Border]::new()
            $node.Width        = $memberNodeW
            $node.CornerRadius = '3'
            $node.Background   = $memPal.Bg
            $node.BorderBrush  = $memPal.Border
            $node.BorderThickness = 1
            $node.Padding      = '5,2'
            $tb = [System.Windows.Controls.TextBlock]::new()
            $tb.Text         = if ($m.Name) { "$($m.Name)" } else { "$($m.PrimarySmtpAddress)" }
            $tb.FontSize     = 9; $tb.FontWeight = 'SemiBold'
            $tb.TextTrimming = 'CharacterEllipsis'; $tb.Foreground = $memPal.Fg
            $tb.ToolTip      = "$($m.Name)`n$($m.PrimarySmtpAddress)`n$($m.RecipientTypeDetails)"
            $node.Child = $tb
            [System.Windows.Controls.Canvas]::SetLeft($node, $pos.X + $offsetX)
            [System.Windows.Controls.Canvas]::SetTop($node,  $pos.Y + $offsetY)
            $null = $cv.Children.Add($node)
            $links = [System.Collections.Generic.List[hashtable]]::new()
            $null = $links.Add(@{
                Line    = $memberLines[$i]
                End     = 'end'
                OffsetX = $memberNodeW / 2
                OffsetY = $memberNodeH / 2
                Arrow   = $memberArrows[$i]
            })
            $memInfo = @{
                Title="$($m.Name)"; Badge='SCOPE MEMBER'
                Rows=@(
                    [pscustomobject]@{ Key='Type';                Value="$($m.RecipientTypeDetails)" }
                    [pscustomobject]@{ Key='Primary SMTP';        Value="$($m.PrimarySmtpAddress)" }
                    [pscustomobject]@{ Key='Organizational unit'; Value="$($m.OrganizationalUnit)" }
                )
            }
            if ("$($m.Name)".Trim()) {
                $memInfo.Nav = @{ View='UserRights'; Name="$($m.Name)"; Label='Look up in User Rights' }
            }
            & $makeDraggable $node $links $memInfo
        }

        # -- Legend (when there are cmdlets and/or scope members to colour-code)
        if ($allEntries.Count -gt 0 -or $members.Count -gt 0) {
            # Count cmdlets per group to drive the legend labels.
            $groupCounts = @{}
            foreach ($e in $allEntries) {
                if (-not $groupCounts.ContainsKey($e.CmdletGroup)) { $groupCounts[$e.CmdletGroup] = 0 }
                $groupCounts[$e.CmdletGroup]++
            }
            $legend = [System.Windows.Controls.Border]::new()
            $legend.Background = '#F3F2F1'
            $legend.BorderBrush = '#C8C6C4'
            $legend.BorderThickness = 1
            $legend.CornerRadius = '4'
            $legend.Padding = '8,5'
            $legendPanel = [System.Windows.Controls.StackPanel]::new()
            $legendPanel.Orientation = 'Horizontal'
            $title = [System.Windows.Controls.TextBlock]::new()
            $title.Text = if ($allEntries.Count -gt 0) { 'CMDLETS BY GROUP' } else { 'LEGEND' }
            $title.FontFamily = 'Consolas'; $title.FontSize = 9
            $title.Foreground = '#605E5C'; $title.VerticalAlignment = 'Center'; $title.Margin = '0,0,10,0'
            $null = $legendPanel.Children.Add($title)
            $orderedGroups = @('Read','Modify','Destructive','Create','Other')
            foreach ($g in $orderedGroups) {
                if (-not $groupCounts.ContainsKey($g)) { continue }
                $p   = $verbPalettes[$g]
                $sw  = [System.Windows.Shapes.Rectangle]::new()
                $sw.Width = 12; $sw.Height = 12
                $sw.Fill = $p.Bg
                $sw.Stroke = $p.Border; $sw.StrokeThickness = 1
                $sw.Margin = '6,0,4,0'; $sw.VerticalAlignment = 'Center'
                $null = $legendPanel.Children.Add($sw)
                $lbl = [System.Windows.Controls.TextBlock]::new()
                $lbl.Text = "$g ($($groupCounts[$g]))"
                $lbl.FontSize = 11; $lbl.Foreground = '#201F1E'
                $lbl.VerticalAlignment = 'Center'
                $null = $legendPanel.Children.Add($lbl)
            }
            # Append a scope-members swatch when members are drawn on the canvas.
            if ($members.Count -gt 0) {
                $sw = [System.Windows.Shapes.Rectangle]::new()
                $sw.Width = 12; $sw.Height = 12
                $sw.Fill = $memPal.Bg; $sw.Stroke = $memPal.Border; $sw.StrokeThickness = 1
                $sw.Margin = '12,0,4,0'; $sw.VerticalAlignment = 'Center'
                $null = $legendPanel.Children.Add($sw)
                $lbl = [System.Windows.Controls.TextBlock]::new()
                $lbl.Text = "Scope members ($($members.Count)$(if ($script:VizScopeTruncated) { '+' } else { '' }))"
                $lbl.FontSize = 11; $lbl.Foreground = '#201F1E'; $lbl.VerticalAlignment = 'Center'
                $null = $legendPanel.Children.Add($lbl)
            }
            $legend.Child = $legendPanel
            [System.Windows.Controls.Canvas]::SetLeft($legend, 12)
            [System.Windows.Controls.Canvas]::SetTop($legend, 12)
            $null = $cv.Children.Add($legend)
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

    function Show-Loading {
        param([string]$Message = 'Loading…')
        $UI.LoadingText.Text = $Message
        $UI.LoadingOverlay.Visibility = 'Visible'
        # Force the dispatcher to render the overlay before the blocking call below
        # takes over the UI thread.
        $window.Dispatcher.Invoke(
            [action]{},
            [System.Windows.Threading.DispatcherPriority]::Render
        )
    }
    function Hide-Loading {
        $UI.LoadingOverlay.Visibility = 'Collapsed'
    }

    function Load-ViewData {
        param([string]$View)
        if ($View -ne 'UserRights' -and $View -ne 'Commands' -and $View -ne 'Visualizer') {
            if (-not (Require-Connected)) { return }
        }
        $loadingLabel = switch ($View) {
            'RoleGroups'  { 'Loading role groups…' }
            'Roles'       { 'Loading roles…' }
            'Assignments' { 'Loading role assignments…' }
            'Scopes'      { 'Loading management scopes…' }
            'UserRights'  { 'Loading…' }
            'Commands'    { 'Loading…' }
            'MyCmdlets'   { 'Loading session cmdlets…' }
            'Visualizer'  { 'Loading…' }
            default       { 'Loading…' }
        }
        Show-Loading -Message $loadingLabel
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
                        [PSCustomObject]@{
                            Name        = $r.Name
                            RoleType    = $r.RoleType
                            Origin      = $r.Origin
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
                    $data = @(Get-RBACManagementScopes)
                    $script:Cache.Scopes = $data
                    # Route the initial paint through Apply-Filters - which is
                    # the same code path that works correctly on chip clicks -
                    # instead of assigning ItemsSource directly. Direct assign
                    # was rendering only the first row on first paint; once
                    # we re-binded via Apply-Filters all rows appeared. So we
                    # just always go through Apply-Filters on scope load.
                    $UI.MainGrid.ItemsSource = $null
                    Apply-Filters
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
                    # The typeahead cache is built lazily (debounced) only while the
                    # user is actually typing in THIS view - never eagerly on view
                    # entry, so its Get-Command can't fire on the UI thread while the
                    # user is in another view (which read as a freeze in User Rights).
                }
                'MyCmdlets' {
                    # Local to the connected session module - fast, no Exchange round-trip.
                    $data = @(Get-RBACSessionCmdlets)
                    $script:Cache.MyCmdlets = $data
                    $UI.MainGrid.ItemsSource = $data
                    $UI.ItemCount.Text = "$(@($data).Count) items"
                    if (@($data).Count -gt 0) {
                        Set-Status "$(@($data).Count) cmdlet(s) available in this session." 'ok'
                    }
                    else {
                        Set-Status 'No session cmdlets found (is the Exchange Online session still active?).' 'warn'
                    }
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
        finally {
            Hide-Loading
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
                    'recipient' { return ($t -like '*Recipient*') }
                    'server'    { return ($t -like '*Server*') }
                }
            }
            'Audit' {
                # Audit chips drive the query window - handled at load time, not here.
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
            'MyCmdlets'   { $src = $script:Cache.MyCmdlets }
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
        $srcCount = @($src).Count
        $hasColFilter = ($colFilters.Count -gt 0)
        $hasSearch    = ($q -ne '')
        $diag = "chip='$chip' src=$srcCount → shown=$(@($filtered).Count)"
        if ($hasSearch)    { $diag += " (search='$q')" }
        if ($hasColFilter) { $diag += " (column filters active)" }
        Set-Status $diag 'info'
    }

    # Backward-compat alias kept for existing event wiring
    function Apply-Search { Apply-Filters }

    function Lookup-UserRights {
        param([string]$User)
        if (-not (Require-Connected)) { return }
        Set-Status "Resolving rights for '$User'…"
        try {
            if (-not $script:Cache.Assignments) { $script:Cache.Assignments = Get-RBACRoleAssignments }
            $matches = [System.Collections.Generic.List[pscustomobject]]::new()
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
                    $null = $matches.Add([PSCustomObject]@{
                        User       = $User
                        Role       = $asg.Role
                        Via        = $via
                        ReadScope  = $asg.RecipientReadScope
                        WriteScope = $asg.RecipientWriteScope
                        _raw       = $asg
                    })
                }
            }
            $UI.MainGrid.ItemsSource = $matches
            $UI.ItemCount.Text = "$($matches.Count) items"
            if ($matches.Count -gt 0) { Set-Status "$User has $($matches.Count) effective role(s)." 'ok' }
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
                $isBuiltIn = $r.IsRootRole -or $r.IsEndUserRole
                [PSCustomObject]@{
                    RoleName    = $r.Name
                    RoleType    = $r.RoleType
                    Origin      = if ($isBuiltIn) { 'Built-in' } else { 'Custom' }
                    Description = $r.Description
                }
            }
            $UI.MainGrid.ItemsSource = $rows
            $UI.ItemCount.Text = "$(@($rows).Count) items"
            Set-Status "$(@($rows).Count) role(s) grant '$Cmdlet'." 'ok'
        }
        catch { Set-Status "Command lookup failed: $($_.Exception.Message)" 'error' }
    }

    # Jump to a section with a specific element in focus. For grid views
    # (Roles / Assignments / Scopes) it switches and selects the row by Name; for
    # the lookup views it runs the query. Used by the details-panel "Open in ..."
    # button and by Command Lookup's "View role".
    function Navigate-ToEntity {
        param([string]$View, [string]$Name)
        $n = "$Name".Trim()
        if (-not $View -or -not $n) { return }
        if ($View -eq 'UserRights') {
            Switch-View -View 'UserRights'   # blanks the search box -> set it AFTER
            $UI.SearchBox.Text = $n
            Lookup-UserRights -User $n
            return
        }
        if ($View -eq 'Commands') {
            Switch-View -View 'Commands'
            $UI.SearchBox.Text = $n
            Lookup-Command -Cmdlet $n
            return
        }
        Switch-View -View $View   # Roles / Assignments / Scopes - grid loaded by Load-ViewData
        $match = @($UI.MainGrid.ItemsSource) | Where-Object { "$($_.Name)" -eq $n } | Select-Object -First 1
        if ($match) {
            $UI.MainGrid.SelectedItem = $match
            $UI.MainGrid.ScrollIntoView($match)
            Set-Status "Showing '$n'." 'ok'
        }
        else {
            Set-Status "'$n' is not in the $View list." 'warn'
        }
    }

    # From a Command Lookup row (a role that grants the looked-up cmdlet), jump to
    # the Roles view and select that role so the details panel lists ALL its cmdlets.
    function Show-RoleFromSelection {
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select a role first.' 'warn'; return }
        $roleName = "$($sel.RoleName)"
        if (-not $roleName) { $roleName = "$($sel.Name)" }
        if (-not "$roleName".Trim()) { Set-Status 'Selected row has no role.' 'warn'; return }
        Navigate-ToEntity -View 'Roles' -Name $roleName
    }

    # ---------------- View switching ----------------
    function Switch-View {
        param([string]$View)

        # Update toggle states
        $btnMap = @{
            RoleGroups  = $UI.NavRoleGroups;  Roles       = $UI.NavRoles
            Assignments = $UI.NavAssignments; Scopes      = $UI.NavScopes
            UserRights  = $UI.NavUserRights;  Commands    = $UI.NavCommands
            MyCmdlets   = $UI.NavMyCmdlets
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
        $UI.FloatingCount.Text = '0'
        $UI.FloatingActions.Visibility = 'Collapsed'
        Hide-Details

        # Switch table vs visualizer. Filter/Wrap/Auto-fit only apply to the DataGrid,
        # so they're hidden in views without one (Visualizer for now).
        if ($View -eq 'Visualizer') {
            $UI.MainGrid.Visibility      = 'Collapsed'
            $UI.VizHost.Visibility       = 'Visible'
            $UI.SearchHost.Visibility    = 'Collapsed'
            $UI.GridModifiers.Visibility = 'Collapsed'
        }
        else {
            $UI.VizHost.Visibility       = 'Collapsed'
            $UI.MainGrid.Visibility      = 'Visible'
            $UI.SearchHost.Visibility    = 'Visible'
            $UI.GridModifiers.Visibility = 'Visible'
            Set-GridColumns -Columns $cfg.Columns
        }

        # Action bar
        Set-Actions -Buttons (Get-ActionsForView -View $View)

        Load-ViewData -View $View
    }

    function Get-ActionsForView {
        param([string]$View)
        # Kind convention:
        #   Primary     → top-right of the toolbar (signature action: + New, Lookup, Pick…)
        #   Tool        → top toolbar, view-level (Refresh, Export, audit timeframes…)
        #   Selection   → floating bottom bar (only when a row is selected: Edit, Copy, Visualize…)
        #   Destructive → floating bottom bar, isolated zone (Delete)
        $list = [System.Collections.Generic.List[pscustomobject]]::new()
        switch ($View) {
            'RoleGroups' {
                $null = $list.Add((New-ActionButton -Label '+ New Role Group' -Style 'PrimaryBtn' -Kind 'Primary'     -OnClick { Do-NewRoleGroup }))
                $null = $list.Add((New-ActionButton -Label '⟳  Refresh'       -Style 'ActionBtn'  -Kind 'Tool'        -OnClick { Reload-CurrentView }))
                $null = $list.Add((New-ActionButton -Label 'Export CSV'       -Style 'ActionBtn'  -Kind 'Tool'        -OnClick { Export-CurrentView }))
                $null = $list.Add((New-ActionButton -Label 'Edit'             -Style 'BtnDark'    -Kind 'Selection'   -OnClick { Do-EditRoleGroup }))
                $null = $list.Add((New-ActionButton -Label 'Copy'             -Style 'BtnDark'    -Kind 'Selection'   -OnClick { Do-CopyRoleGroup }))
                $null = $list.Add((New-ActionButton -Label '⤳  Visualize'    -Style 'BtnDark'    -Kind 'Selection'   -OnClick { Visualize-Related }))
                $null = $list.Add((New-ActionButton -Label '🗑  Delete'       -Style 'BtnDarkDanger' -Kind 'Destructive' -OnClick { Do-DeleteRoleGroup }))
            }
            'Roles' {
                $null = $list.Add((New-ActionButton -Label '+ New Role'  -Style 'PrimaryBtn' -Kind 'Primary'     -OnClick { Do-NewRole }))
                $null = $list.Add((New-ActionButton -Label '⟳  Refresh'  -Style 'ActionBtn'  -Kind 'Tool'        -OnClick { Reload-CurrentView }))
                $null = $list.Add((New-ActionButton -Label 'Export CSV'  -Style 'ActionBtn'  -Kind 'Tool'        -OnClick { Export-CurrentView }))
                $null = $list.Add((New-ActionButton -Label 'Edit'        -Style 'BtnDark'    -Kind 'Selection'   -OnClick { Do-EditRole }))
                $null = $list.Add((New-ActionButton -Label 'Copy'        -Style 'BtnDark'    -Kind 'Selection'   -OnClick { Do-CopyRole }))
                $null = $list.Add((New-ActionButton -Label '⤳  Visualize' -Style 'BtnDark'  -Kind 'Selection'   -OnClick { Visualize-Related }))
                $null = $list.Add((New-ActionButton -Label '🗑  Delete'  -Style 'BtnDarkDanger' -Kind 'Destructive' -OnClick { Do-DeleteRole }))
            }
            'Assignments' {
                $null = $list.Add((New-ActionButton -Label '+ New Assignment' -Style 'PrimaryBtn' -Kind 'Primary'     -OnClick { Do-NewAssignment }))
                $null = $list.Add((New-ActionButton -Label '⟳  Refresh'      -Style 'ActionBtn'  -Kind 'Tool'        -OnClick { Reload-CurrentView }))
                $null = $list.Add((New-ActionButton -Label 'Export CSV'      -Style 'ActionBtn'  -Kind 'Tool'        -OnClick { Export-CurrentView }))
                $null = $list.Add((New-ActionButton -Label 'Edit'            -Style 'BtnDark'    -Kind 'Selection'   -OnClick { Do-EditAssignment }))
                $null = $list.Add((New-ActionButton -Label '⤳  Visualize'   -Style 'BtnDark'    -Kind 'Selection'   -OnClick { Visualize-Selected }))
                $null = $list.Add((New-ActionButton -Label '🗑  Delete'      -Style 'BtnDarkDanger' -Kind 'Destructive' -OnClick { Do-DeleteAssignment }))
            }
            'Scopes' {
                $null = $list.Add((New-ActionButton -Label '+ New Scope'      -Style 'PrimaryBtn' -Kind 'Primary'     -OnClick { Do-NewScope }))
                $null = $list.Add((New-ActionButton -Label '⟳  Refresh'      -Style 'ActionBtn'  -Kind 'Tool'        -OnClick { Reload-CurrentView }))
                $null = $list.Add((New-ActionButton -Label 'Export CSV'      -Style 'ActionBtn'  -Kind 'Tool'        -OnClick { Export-CurrentView }))
                $null = $list.Add((New-ActionButton -Label 'Edit'            -Style 'BtnDark'    -Kind 'Selection'   -OnClick { Do-EditScope }))
                $null = $list.Add((New-ActionButton -Label 'Preview members' -Style 'BtnDark'    -Kind 'Selection'   -OnClick { Preview-ScopeMembers }))
                $null = $list.Add((New-ActionButton -Label '⤳  Visualize'    -Style 'BtnDark'    -Kind 'Selection'   -OnClick { Visualize-Related }))
                $null = $list.Add((New-ActionButton -Label '🗑  Delete'      -Style 'BtnDarkDanger' -Kind 'Destructive' -OnClick { Do-DeleteScope }))
            }
            'UserRights' {
                $null = $list.Add((New-ActionButton -Label 'Lookup'       -Style 'PrimaryBtn' -Kind 'Primary'   -OnClick { Apply-Search }))
                $null = $list.Add((New-ActionButton -Label 'Export CSV'   -Style 'ActionBtn'  -Kind 'Tool'      -OnClick { Export-CurrentView }))
                $null = $list.Add((New-ActionButton -Label '⤳  Visualize' -Style 'BtnDark'   -Kind 'Selection' -OnClick { Visualize-Selected }))
            }
            'Commands' {
                $null = $list.Add((New-ActionButton -Label 'Lookup'       -Style 'PrimaryBtn' -Kind 'Primary'   -OnClick { Apply-Search }))
                $null = $list.Add((New-ActionButton -Label 'Export CSV'   -Style 'ActionBtn'  -Kind 'Tool'      -OnClick { Export-CurrentView }))
                $null = $list.Add((New-ActionButton -Label '⤳  View role' -Style 'BtnDark'    -Kind 'Selection' -OnClick { Show-RoleFromSelection }))
            }
            'MyCmdlets' {
                $null = $list.Add((New-ActionButton -Label '⟳  Refresh'  -Style 'ActionBtn' -Kind 'Tool' -OnClick { Reload-CurrentView }))
                $null = $list.Add((New-ActionButton -Label 'Export CSV' -Style 'ActionBtn' -Kind 'Tool' -OnClick { Export-CurrentView }))
            }
            'Visualizer' {
                $null = $list.Add((New-ActionButton -Label 'Pick assignment…' -Style 'PrimaryBtn' -Kind 'Primary' -OnClick { Pick-VizAssignment }))
                $null = $list.Add((New-ActionButton -Label '➕ Zoom in'  -Style 'ActionBtn'  -Kind 'Tool' -OnClick { Zoom-Viz 1.2 }))
                $null = $list.Add((New-ActionButton -Label '➖ Zoom out' -Style 'ActionBtn'  -Kind 'Tool' -OnClick { Zoom-Viz (1 / 1.2) }))
                $null = $list.Add((New-ActionButton -Label '⌖ Center'   -Style 'ActionBtn'  -Kind 'Tool' -OnClick { Reset-VizTransform; Render-Visualizer }))
                $null = $list.Add((New-ActionButton -Label '👥 Scope members' -Style 'ActionBtn' -Kind 'Tool' -OnClick { Show-VizScopeMembers }))
                $null = $list.Add((New-ActionButton -Label 'Export PNG'  -Style 'ActionBtn'  -Kind 'Tool' -OnClick { Export-VizPng }))
                $null = $list.Add((New-ActionButton -Label 'Export HTML' -Style 'ActionBtn'  -Kind 'Tool' -OnClick { Export-VizHtml }))
            }
            'Audit' {
                $null = $list.Add((New-ActionButton -Label '⟳ 7 days'   -Style 'ActionBtn' -Kind 'Tool' -OnClick { Load-Audit -Days 7 }))
                $null = $list.Add((New-ActionButton -Label '⟳ 30 days'  -Style 'ActionBtn' -Kind 'Tool' -OnClick { Load-Audit -Days 30 }))
                $null = $list.Add((New-ActionButton -Label '⟳ 90 days'  -Style 'ActionBtn' -Kind 'Tool' -OnClick { Load-Audit -Days 90 }))
                $null = $list.Add((New-ActionButton -Label 'Export CSV' -Style 'ActionBtn' -Kind 'Tool' -OnClick { Export-CurrentView }))
            }
        }
        return $list
    }

    function Reload-CurrentView {
        if ($script:CurrentView) { Load-ViewData -View $script:CurrentView }
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
    # All handlers follow the same pattern:
    #   1. Build the dry-run preview
    #   2. Show it to the user with Run / Copy / Cancel buttons
    #   3. Run live only if the user clicks "Run cmdlet"

    function Do-NewRoleGroup {
        if (-not (Require-Connected)) { return }
        $form = Show-RoleGroupForm -Title 'New Role Group'
        if (-not $form) { return }
        $r = New-RBACRoleGroup -Name $form.Name -Description $form.Description -Roles $form.Roles -Members $form.Members -DryRun
        $ok = Handle-WriteResult -Result $r -Title 'New-RoleGroup' `
                -SuccessMsg "Created role group '$($form.Name)'." -RunBlock {
            New-RBACRoleGroup -Name $form.Name -Description $form.Description -Roles $form.Roles -Members $form.Members
        }
        if ($ok) { Load-ViewData -View 'RoleGroups' }
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
        $r = Set-RBACRoleGroup @params -DryRun
        $ok = Handle-WriteResult -Result $r -Title 'Set-RoleGroup' `
                -SuccessMsg "Updated role group '$($sel.Name)'." -RunBlock {
            Set-RBACRoleGroup @params
        }
        if ($ok) { Load-ViewData -View 'RoleGroups' }
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
        $r = Copy-RBACRoleGroup -SourceName $sel.Name -NewName $form.Name -NewDescription $form.Description -IncludeMembers:$form.IncludeMembers -DryRun
        $ok = Handle-WriteResult -Result $r -Title 'New-RoleGroup (copy)' `
                -SuccessMsg "Copied to '$($form.Name)'." -RunBlock {
            Copy-RBACRoleGroup -SourceName $sel.Name -NewName $form.Name -NewDescription $form.Description -IncludeMembers:$form.IncludeMembers
        }
        if ($ok) { Load-ViewData -View 'RoleGroups' }
    }

    function Do-DeleteRoleGroup {
        if (-not (Require-Connected)) { return }
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select a role group to delete.' 'warn'; return }
        if ($sel.Origin -eq 'Built-in') {
            Set-Status "Built-in role groups can't be deleted." 'warn'; return
        }
        $r = Remove-RBACRoleGroup -Identity $sel.Name -DryRun
        $ok = Handle-WriteResult -Result $r -Title 'Remove-RoleGroup' `
                -SuccessMsg "Deleted '$($sel.Name)'." -RunBlock {
            Remove-RBACRoleGroup -Identity $sel.Name
        }
        if ($ok) { Load-ViewData -View 'RoleGroups' }
    }

    # ---------------- Role write actions ----------------
    function Do-NewRole {
        if (-not (Require-Connected)) { return }
        # If a role is selected in the grid, suggest it as the parent.
        $defaultParent = ''
        $sel = $UI.MainGrid.SelectedItem
        if ($sel -and $sel.Name -and $script:CurrentView -eq 'Roles') {
            $defaultParent = "$($sel.Name)"
        }
        $form = Show-RoleForm -Title 'New management role (from parent)' -DefaultParent $defaultParent
        if (-not $form) { return }
        if (-not $form.Parent) {
            Set-Status 'Parent role is required to create a new role.' 'warn'; return
        }
        $r = New-RBACRole -Name $form.Name -Parent $form.Parent -Description $form.Description -DryRun
        $ok = Handle-WriteResult -Result $r -Title 'New-ManagementRole' `
                -SuccessMsg "Created role '$($form.Name)'." -RunBlock {
            New-RBACRole -Name $form.Name -Parent $form.Parent -Description $form.Description
        }
        if ($ok) { Load-ViewData -View 'Roles' }
    }

    function Do-EditRole {
        if (-not (Require-Connected)) { return }
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select a role first.' 'warn'; return }
        if ($sel.Origin -eq 'Built-in') {
            Set-Status "Built-in roles can't be edited." 'warn'; return
        }
        # Fetch the current cmdlets so the user can edit the list. Cache per role.
        if (-not $script:Cache.RoleCmdlets) { $script:Cache.RoleCmdlets = @{} }
        $currentCmdlets = $script:Cache.RoleCmdlets[$sel.Name]
        if (-not $currentCmdlets) {
            try {
                $currentCmdlets = @(
                    Get-ManagementRoleEntry -Identity "$($sel.Name)\*" -ErrorAction Stop |
                        ForEach-Object Name | Sort-Object
                )
                $script:Cache.RoleCmdlets[$sel.Name] = $currentCmdlets
            }
            catch { $currentCmdlets = @() }
        }

        $form = Show-RoleForm `
                    -Title              "Edit role: $($sel.Name)" `
                    -DefaultName        $sel.Name `
                    -DefaultParent      "$($sel.Parent)" `
                    -DefaultDescription "$($sel.Description)" `
                    -DefaultCmdlets     $currentCmdlets `
                    -NameReadOnly       $true `
                    -ParentReadOnly     $true `
                    -ShowCmdlets        $true
        if (-not $form) { return }

        # Diff cmdlets: figure out what to add and what to remove.
        $newCmdlets = @($form.Cmdlets)
        $toAdd    = @($newCmdlets    | Where-Object { $currentCmdlets -notcontains $_ })
        $toRemove = @($currentCmdlets | Where-Object { $newCmdlets    -notcontains $_ })
        $descChanged = ($form.Description -ne "$($sel.Description)")

        if (-not $descChanged -and $toAdd.Count -eq 0 -and $toRemove.Count -eq 0) {
            Set-Status 'Nothing to update.' 'info'
            return
        }

        # Build a combined preview that aggregates description + entry deltas.
        $previewLines = New-Object System.Collections.Generic.List[string]
        if ($descChanged) {
            $r = Set-RBACRole -Identity $sel.Name -Description $form.Description -DryRun
            if ($r.Preview) { $previewLines.Add($r.Preview) }
        }
        foreach ($c in $toAdd) {
            $r = Add-RBACRoleEntry -Identity "$($sel.Name)\$c" -DryRun
            if ($r.Preview) { $previewLines.Add($r.Preview) }
        }
        foreach ($c in $toRemove) {
            $r = Remove-RBACRoleEntry -Identity "$($sel.Name)\$c" -DryRun
            if ($r.Preview) { $previewLines.Add($r.Preview) }
        }
        $combined = [pscustomobject]@{
            Preview  = ($previewLines -join "`r`n")
            Result   = $null
            Executed = $false
            Error    = $null
        }

        $ok = Handle-WriteResult -Result $combined -Title 'Edit role (Set + Add/Remove entries)' `
                -SuccessMsg "Updated role '$($sel.Name)' ($($toAdd.Count) cmdlet(s) added, $($toRemove.Count) removed)." -RunBlock {
            if ($descChanged) {
                Set-RBACRole -Identity $sel.Name -Description $form.Description | Out-Null
            }
            foreach ($c in $toAdd)    { Add-RBACRoleEntry    -Identity "$($sel.Name)\$c" | Out-Null }
            foreach ($c in $toRemove) { Remove-RBACRoleEntry -Identity "$($sel.Name)\$c" | Out-Null }
        }
        if ($ok) {
            $script:Cache.RoleCmdlets.Remove($sel.Name) | Out-Null
            Load-ViewData -View 'Roles'
        }
    }

    function Do-CopyRole {
        if (-not (Require-Connected)) { return }
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select a role to copy.' 'warn'; return }
        $form = Show-RoleForm `
                    -Title              "Copy role: $($sel.Name)" `
                    -DefaultName        ("$($sel.Name) - Copy") `
                    -DefaultParent      $sel.Name `
                    -DefaultDescription "$($sel.Description) (copy of $($sel.Name))".Trim() `
                    -ParentReadOnly     $true
        if (-not $form) { return }
        $r = New-RBACRole -Name $form.Name -Parent $form.Parent -Description $form.Description -DryRun
        $ok = Handle-WriteResult -Result $r -Title 'New-ManagementRole (copy)' `
                -SuccessMsg "Copied role to '$($form.Name)'." -RunBlock {
            New-RBACRole -Name $form.Name -Parent $form.Parent -Description $form.Description
        }
        if ($ok) { Load-ViewData -View 'Roles' }
    }

    function Do-DeleteRole {
        if (-not (Require-Connected)) { return }
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select a role to delete.' 'warn'; return }
        if ($sel.Origin -eq 'Built-in') {
            Set-Status "Built-in roles can't be deleted." 'warn'; return
        }
        $r = Remove-RBACRole -Identity $sel.Name -DryRun
        $ok = Handle-WriteResult -Result $r -Title 'Remove-ManagementRole' `
                -SuccessMsg "Deleted role '$($sel.Name)'." -RunBlock {
            Remove-RBACRole -Identity $sel.Name
        }
        if ($ok) { Load-ViewData -View 'Roles' }
    }

    # ---------------- Assignment write actions ----------------
    function Do-NewAssignment {
        if (-not (Require-Connected)) { return }
        $form = Show-AssignmentForm -Title 'New role assignment'
        if (-not $form) { return }
        $callArgs = @{
            Name         = $form.Name
            Role         = $form.Role
            AssigneeKind = $form.AssigneeKind
            Assignee     = $form.Assignee
        }
        if ($form.RecipientOrganizationalUnitScope) { $callArgs.RecipientOrganizationalUnitScope = $form.RecipientOrganizationalUnitScope }
        if ($form.CustomRecipientWriteScope)        { $callArgs.CustomRecipientWriteScope        = $form.CustomRecipientWriteScope }
        $r = New-RBACAssignment @callArgs -DryRun
        $ok = Handle-WriteResult -Result $r -Title 'New-ManagementRoleAssignment' `
                -SuccessMsg "Created assignment '$($form.Name)'." -RunBlock {
            New-RBACAssignment @callArgs
        }
        if ($ok) { Load-ViewData -View 'Assignments' }
    }

    function Show-EditAssignmentForm {
        param([Parameter(Mandatory)] $Assignment)
        $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="" Width="520" SizeToContent="Height" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" FontSize="12" Background="White" ResizeMode="NoResize" ShowInTaskbar="False">
$($script:DlgResourcesXaml)
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,0,0,1" Padding="16,10">
      <StackPanel>
        <TextBlock Text="Edit role assignment" FontSize="14" FontWeight="SemiBold" Foreground="#201F1E"/>
        <TextBlock Text="Only the write scope and enabled flag are editable. Read scope is inherited from the Role."
                   FontSize="11" Foreground="#605E5C" Margin="0,2,0,0" TextWrapping="Wrap"/>
      </StackPanel>
    </Border>

    <StackPanel Grid.Row="1" Margin="16,12">
      <!-- Two-column read-only block: label | value -->
      <Grid Margin="0,0,0,4">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="90"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Grid.Column="0" Text="Assignment" Foreground="#605E5C" Margin="0,2"/>
        <TextBlock x:Name="LblName"      Grid.Row="0" Grid.Column="1" Foreground="#201F1E" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" Margin="0,2"/>
        <TextBlock Grid.Row="1" Grid.Column="0" Text="Role"       Foreground="#605E5C" Margin="0,2"/>
        <TextBlock x:Name="LblRole"      Grid.Row="1" Grid.Column="1" Foreground="#201F1E" TextTrimming="CharacterEllipsis" Margin="0,2"/>
        <TextBlock Grid.Row="2" Grid.Column="0" Text="Assignee"   Foreground="#605E5C" Margin="0,2"/>
        <TextBlock x:Name="LblAssignee"  Grid.Row="2" Grid.Column="1" Foreground="#201F1E" TextTrimming="CharacterEllipsis" Margin="0,2"/>
        <TextBlock Grid.Row="3" Grid.Column="0" Text="Read scope" Foreground="#605E5C" Margin="0,2"/>
        <TextBlock x:Name="LblReadScope" Grid.Row="3" Grid.Column="1" Foreground="#201F1E" TextTrimming="CharacterEllipsis" Margin="0,2"/>
      </Grid>

      <Border BorderBrush="#E1DFDD" BorderThickness="0,1,0,0" Margin="0,10,0,10"/>

      <TextBlock Text="Write scope" FontWeight="SemiBold" Foreground="#201F1E" Margin="0,0,0,6"/>

      <ComboBox x:Name="CmbWriteKind" Style="{StaticResource DlgComboBox}">
        <ComboBoxItem Content="Keep current" Tag="Keep"/>
        <ComboBoxItem Content="Predefined (RecipientRelativeWriteScope)" Tag="Relative"/>
        <ComboBoxItem Content="Custom scope (existing scope name)" Tag="Custom"/>
        <ComboBoxItem Content="Organizational Unit (DN)" Tag="Ou"/>
        <ComboBoxItem Content="Clear (revert to role default)" Tag="Clear"/>
      </ComboBox>

      <!-- Dynamic input area: exactly one of these shows depending on CmbWriteKind. -->
      <Grid x:Name="GridInputs" Margin="0,8,0,0">
        <TextBlock x:Name="PnlKeep" Foreground="#605E5C" FontSize="11" TextWrapping="Wrap"/>
        <ComboBox x:Name="CmbRelative" Style="{StaticResource DlgComboBox}" Visibility="Collapsed"/>
        <ComboBox x:Name="CmbCustom"   Style="{StaticResource DlgComboBox}" Visibility="Collapsed" IsEditable="True"/>
        <TextBox  x:Name="TxtOu"       Style="{StaticResource DlgTextBox}"  Visibility="Collapsed"/>
        <TextBlock x:Name="PnlClear"   Foreground="#A4262C" FontSize="11" TextWrapping="Wrap" Visibility="Collapsed"
                   Text="The CustomRecipientWriteScope will be cleared; the assignment will fall back to the role's default write scope."/>
      </Grid>

      <CheckBox x:Name="ChkEnabled" Content="Enabled" Margin="0,12,0,0"/>
    </StackPanel>

    <Border Grid.Row="2" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,1,0,0" Padding="16,10">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BtnCancel" Content="Cancel" Style="{StaticResource DlgBtn}"        Margin="0,0,8,0" IsCancel="True"/>
        <Button x:Name="BtnOk"     Content="OK"     Style="{StaticResource DlgBtnPrimary}" IsDefault="True"/>
      </StackPanel>
    </Border>
  </Grid>
</Window>
"@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $w = [System.Windows.Markup.XamlReader]::Load($reader); $w.Title = 'Edit assignment'; $w.Owner = $window
        $UIDlg = @{}
        foreach ($n in @('LblName','LblRole','LblAssignee','LblReadScope',
                          'CmbWriteKind','PnlKeep','CmbRelative','CmbCustom','TxtOu','PnlClear',
                          'ChkEnabled','BtnOk','BtnCancel')) {
            $UIDlg[$n] = $w.FindName($n)
        }
        $UIDlg.LblName.Text      = "$($Assignment.Name)"
        $UIDlg.LblRole.Text      = "$($Assignment.Role)"
        $UIDlg.LblAssignee.Text  = "$($Assignment.RoleAssignee) ($($Assignment.RoleAssigneeType))"
        $UIDlg.LblReadScope.Text = "$($Assignment.RecipientReadScope) (implicit, from Role)"
        $UIDlg.PnlKeep.Text      = "Current: $($Assignment.RecipientWriteScope)"
        $UIDlg.ChkEnabled.IsChecked = [bool]$Assignment.Enabled

        # Switch which input is visible based on the WriteKind combo. Only the
        # selected variant takes screen space, so the popup stays compact.
        $UIDlg.CmbWriteKind.Add_SelectionChanged({
            $tag = "$($UIDlg.CmbWriteKind.SelectedItem.Tag)"
            $UIDlg.PnlKeep.Visibility     = if ($tag -eq 'Keep')     { 'Visible' } else { 'Collapsed' }
            $UIDlg.CmbRelative.Visibility = if ($tag -eq 'Relative') { 'Visible' } else { 'Collapsed' }
            $UIDlg.CmbCustom.Visibility   = if ($tag -eq 'Custom')   { 'Visible' } else { 'Collapsed' }
            $UIDlg.TxtOu.Visibility       = if ($tag -eq 'Ou')       { 'Visible' } else { 'Collapsed' }
            $UIDlg.PnlClear.Visibility    = if ($tag -eq 'Clear')    { 'Visible' } else { 'Collapsed' }

            # Lazy-populate the predefined enum the first time the user picks
            # "Predefined". The values are the public RecipientWriteScopeEnum,
            # stable across EXO versions.
            if ($tag -eq 'Relative' -and $UIDlg.CmbRelative.Items.Count -eq 0) {
                $values = @('Organization','Self','MyGAL','MyDirectReports','MyDistributionGroups','NotApplicable')
                foreach ($v in $values) {
                    $it = [System.Windows.Controls.ComboBoxItem]::new()
                    $it.Content = $v
                    [void]$UIDlg.CmbRelative.Items.Add($it)
                }
                $UIDlg.CmbRelative.SelectedIndex = 0
            }

            # Lazy-populate the custom-scope list with existing recipient
            # scopes. Reuse $script:Cache.Scopes when available (saves a round
            # trip); otherwise call Get-ManagementScope once and cache it.
            if ($tag -eq 'Custom' -and $UIDlg.CmbCustom.Items.Count -eq 0) {
                try {
                    $src = $script:Cache.Scopes
                    if (-not $src) {
                        Set-Status 'Loading management scopes...' 'info'
                        $src = @(Get-RBACManagementScopes)
                        $script:Cache.Scopes = $src
                    }
                    # Only recipient-type scopes can be used as
                    # CustomRecipientWriteScope; filter to those for safety.
                    $candidates = $src | Where-Object {
                        "$($_.ScopeRestrictionType)" -like '*Recipient*'
                    } | Sort-Object Name
                    foreach ($s in $candidates) {
                        $it = [System.Windows.Controls.ComboBoxItem]::new()
                        $it.Content = "$($s.Name)"
                        [void]$UIDlg.CmbCustom.Items.Add($it)
                    }
                    if ($UIDlg.CmbCustom.Items.Count -gt 0) {
                        # Pre-select the assignment's current scope if it's in the list.
                        $cur = "$($Assignment.CustomRecipientWriteScope)"
                        if ($cur) { $UIDlg.CmbCustom.Text = $cur }
                    }
                }
                catch {
                    Set-Status "Could not load scopes: $($_.Exception.Message)" 'error'
                }
            }
        })
        $UIDlg.CmbWriteKind.SelectedIndex = 0  # default: Keep current

        $script:_FormResult = $null
        $UIDlg.BtnOk.Add_Click({
            $tag = "$($UIDlg.CmbWriteKind.SelectedItem.Tag)"
            $result = [pscustomobject]@{
                Identity                          = "$($UIDlg.LblName.Text)".Trim()
                Action                            = $tag
                RecipientRelativeWriteScope       = $null
                CustomRecipientWriteScope         = $null
                RecipientOrganizationalUnitScope  = $null
                Enabled                           = [bool]$UIDlg.ChkEnabled.IsChecked
            }
            switch ($tag) {
                'Relative' {
                    $v = "$($UIDlg.CmbRelative.SelectedItem.Content)".Trim()
                    if (-not $v) {
                        [System.Windows.MessageBox]::Show('Pick a predefined scope value.','Missing field',
                            [System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
                        return
                    }
                    $result.RecipientRelativeWriteScope = $v
                }
                'Custom' {
                    # IsEditable="True" on CmbCustom -> .Text holds either the
                    # selected item's content or whatever the user typed.
                    $v = "$($UIDlg.CmbCustom.Text)".Trim()
                    if (-not $v -and $UIDlg.CmbCustom.SelectedItem) {
                        $v = "$($UIDlg.CmbCustom.SelectedItem.Content)".Trim()
                    }
                    if (-not $v) {
                        [System.Windows.MessageBox]::Show('Pick (or type) a scope name.','Missing field',
                            [System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
                        return
                    }
                    $result.CustomRecipientWriteScope = $v
                }
                'Ou' {
                    $v = "$($UIDlg.TxtOu.Text)".Trim()
                    if (-not $v) {
                        [System.Windows.MessageBox]::Show('Enter the OU distinguished name.','Missing field',
                            [System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
                        return
                    }
                    $result.RecipientOrganizationalUnitScope = $v
                }
            }
            $script:_FormResult = $result
            $w.DialogResult = $true; $w.Close()
        })
        $UIDlg.BtnCancel.Add_Click({ $w.DialogResult = $false; $w.Close() })
        if ($w.ShowDialog()) { return $script:_FormResult }
        return $null
    }

    function Do-EditAssignment {
        if (-not (Require-Connected)) { return }
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select an assignment to edit.' 'warn'; return }
        $form = Show-EditAssignmentForm -Assignment $sel
        if (-not $form) { return }

        # Only pass the parameters that genuinely changed. In particular,
        # Set-ManagementRoleAssignment -Enabled $true on an already-enabled
        # assignment emits a WARNING ("L'attribution ... est déjà activée").
        $callArgs = @{ Identity = $form.Identity }
        if ([bool]$form.Enabled -ne [bool]$sel.Enabled) {
            $callArgs.Enabled = [bool]$form.Enabled
        }
        switch ($form.Action) {
            'Relative' { $callArgs.RecipientRelativeWriteScope = $form.RecipientRelativeWriteScope }
            'Custom'   { $callArgs.CustomRecipientWriteScope   = $form.CustomRecipientWriteScope }
            'Ou'       { $callArgs.RecipientOrganizationalUnitScope = $form.RecipientOrganizationalUnitScope }
            'Clear'    { $callArgs.CustomRecipientWriteScope   = '' }
            # 'Keep' = nothing to add for the scope
        }
        if ($callArgs.Count -le 1) {
            Set-Status 'Nothing to update.' 'warn'
            return
        }

        $r  = Set-RBACAssignment @callArgs -DryRun
        $ok = Handle-WriteResult -Result $r -Title 'Set-ManagementRoleAssignment' `
                -SuccessMsg "Updated assignment '$($form.Identity)'." -RunBlock {
            Set-RBACAssignment @callArgs
        }
        if ($ok) { Load-ViewData -View 'Assignments' }
    }

    function Do-DeleteAssignment {
        if (-not (Require-Connected)) { return }
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select an assignment to delete.' 'warn'; return }
        $r = Remove-RBACAssignment -Identity $sel.Name -DryRun
        $ok = Handle-WriteResult -Result $r -Title 'Remove-ManagementRoleAssignment' `
                -SuccessMsg "Deleted assignment '$($sel.Name)'." -RunBlock {
            Remove-RBACAssignment -Identity $sel.Name
        }
        if ($ok) { Load-ViewData -View 'Assignments' }
    }

    # ---------------- Scope write actions ----------------
    function Do-NewScope {
        if (-not (Require-Connected)) { return }
        $form = Show-ScopeForm -Title 'New management scope'
        if (-not $form) { return }
        if (-not $form.Root -and -not $form.Filter) {
            Set-Status 'Provide a Recipient root, a Filter, or both.' 'warn'; return
        }
        $callArgs = @{ Name = $form.Name }
        if ($form.Root)   { $callArgs.RecipientRoot              = $form.Root }
        if ($form.Filter) { $callArgs.RecipientRestrictionFilter = $form.Filter }
        $r = New-RBACScope @callArgs -DryRun
        $ok = Handle-WriteResult -Result $r -Title 'New-ManagementScope' `
                -SuccessMsg "Created scope '$($form.Name)'." -RunBlock {
            New-RBACScope @callArgs
        }
        if ($ok) { Load-ViewData -View 'Scopes' }
    }

    function Do-EditScope {
        if (-not (Require-Connected)) { return }
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select a scope first.' 'warn'; return }
        if ("$($sel.ScopeRestrictionType)" -like '*Implicit*') {
            Set-Status "Implicit scopes can't be edited." 'warn'; return
        }
        $form = Show-ScopeForm `
                    -Title          "Edit scope: $($sel.Name)" `
                    -DefaultName    $sel.Name `
                    -DefaultNewName $sel.Name `
                    -DefaultRoot    "$($sel.RecipientRoot)" `
                    -DefaultFilter  "$($sel.RecipientFilter)" `
                    -NameReadOnly   $true `
                    -ShowNewName    $true
        if (-not $form) { return }
        $callArgs = @{ Identity = $sel.Name }
        if ($form.NewName -and $form.NewName -ne $sel.Name) { $callArgs.NewName = $form.NewName }
        if ($form.Root -ne "$($sel.RecipientRoot)")         { $callArgs.RecipientRoot = $form.Root }
        if ($form.Filter -ne "$($sel.RecipientFilter)")     { $callArgs.RecipientRestrictionFilter = $form.Filter }
        if ($callArgs.Count -le 1) {
            Set-Status 'Nothing to update.' 'info'; return
        }
        $r = Set-RBACScope @callArgs -DryRun
        $ok = Handle-WriteResult -Result $r -Title 'Set-ManagementScope' `
                -SuccessMsg "Updated scope '$($sel.Name)'." -RunBlock {
            Set-RBACScope @callArgs
        }
        if ($ok) { Load-ViewData -View 'Scopes' }
    }

    function Do-DeleteScope {
        if (-not (Require-Connected)) { return }
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select a scope to delete.' 'warn'; return }
        if ("$($sel.ScopeRestrictionType)" -like '*Implicit*') {
            Set-Status "Implicit scopes can't be deleted." 'warn'; return
        }
        $r = Remove-RBACScope -Identity $sel.Name -DryRun
        $ok = Handle-WriteResult -Result $r -Title 'Remove-ManagementScope' `
                -SuccessMsg "Deleted scope '$($sel.Name)'." -RunBlock {
            Remove-RBACScope -Identity $sel.Name
        }
        if ($ok) { Load-ViewData -View 'Scopes' }
    }

    function Preview-ScopeMembers {
        if (-not (Require-Connected)) { return }
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select a scope first.' 'warn'; return }
        $filter = "$($sel.RecipientFilter)".Trim()
        $root   = "$($sel.RecipientRoot)".Trim()
        if (-not $filter -and -not $root) {
            Set-Status "Scope '$($sel.Name)' has neither a RecipientFilter nor a RecipientRoot - nothing to preview." 'warn'
            return
        }

        # Cap the preview to keep the UI thread responsive on large tenants.
        # Get-Recipient with ResultSize='Unlimited' could otherwise freeze the GUI
        # and pull tens of thousands of objects.
        $previewCap = 500
        Set-Status "Resolving recipients matching scope '$($sel.Name)' (preview capped at $previewCap)…"
        try {
            $recipientArgs = @{ ResultSize = $previewCap; ErrorAction = 'Stop' }
            if ($filter) { $recipientArgs.RecipientPreviewFilter = $filter }
            if ($root)   { $recipientArgs.OrganizationalUnit     = $root }
            $recipients = @(Get-Recipient @recipientArgs |
                Select-Object Name, RecipientTypeDetails, PrimarySmtpAddress, OrganizationalUnit)
        }
        catch {
            Set-Status "Preview failed: $($_.Exception.Message)" 'error'
            return
        }

        $truncated = ($recipients.Count -ge $previewCap)
        if ($truncated) {
            Set-Status "Showing first $previewCap recipient(s) for scope '$($sel.Name)' (preview truncated; refine the filter or RecipientRoot to narrow the result)." 'warn'
        }
        else {
            Set-Status "$($recipients.Count) recipient(s) match scope '$($sel.Name)'." 'ok'
        }
        Show-ScopePreview -Scope $sel -Recipients $recipients -Truncated:$truncated -Cap $previewCap
    }

    function Show-ScopePreview {
        param(
            [Parameter(Mandatory)] $Scope,
            [Parameter(Mandatory)] [AllowEmptyCollection()] [array]$Recipients,
            [switch] $Truncated,
            [int]    $Cap
        )
        $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="" Width="820" Height="560" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" Background="White" ResizeMode="CanResize" ShowInTaskbar="False">
$($script:DlgResourcesXaml)
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,0,0,1" Padding="20,16">
      <StackPanel>
        <TextBlock x:Name="DlgTitle" FontSize="16" FontWeight="SemiBold" Foreground="#201F1E"/>
        <TextBlock x:Name="DlgSub"  FontSize="12" Foreground="#605E5C" Margin="0,2,0,0" TextWrapping="Wrap"/>
      </StackPanel>
    </Border>

    <Border Grid.Row="1" Background="#FAFAFA" BorderBrush="#E1DFDD" BorderThickness="0,0,0,1" Padding="20,12">
      <StackPanel>
        <TextBlock Text="RecipientFilter" Style="{StaticResource DlgLabel}"/>
        <TextBox x:Name="FilterText" Style="{StaticResource DlgTextBox}" IsReadOnly="True"
                 FontFamily="Consolas" TextWrapping="Wrap" AcceptsReturn="True"
                 MaxHeight="80" VerticalScrollBarVisibility="Auto"/>
      </StackPanel>
    </Border>

    <Border Grid.Row="2" Padding="20,16">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <Grid Grid.Row="0" Margin="0,0,0,8">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <TextBlock Grid.Column="0" Text="Matching recipients" Style="{StaticResource DlgLabel}" Margin="0"/>
          <Border Grid.Column="2" CornerRadius="10" Padding="10,3" Background="#EFEDEB">
            <TextBlock x:Name="CountText" FontFamily="Consolas" FontSize="11" Foreground="#605E5C"/>
          </Border>
        </Grid>
        <ListView x:Name="RecipientsList" Grid.Row="1" Background="White"
                  BorderBrush="#C8C6C4" BorderThickness="1" SelectionMode="Single">
          <ListView.View>
            <GridView>
              <GridViewColumn Header="Name"          Width="220" DisplayMemberBinding="{Binding Name}"/>
              <GridViewColumn Header="Type"          Width="160" DisplayMemberBinding="{Binding RecipientTypeDetails}"/>
              <GridViewColumn Header="Primary SMTP"  Width="220" DisplayMemberBinding="{Binding PrimarySmtpAddress}"/>
              <GridViewColumn Header="OU"            Width="180" DisplayMemberBinding="{Binding OrganizationalUnit}"/>
            </GridView>
          </ListView.View>
        </ListView>
      </Grid>
    </Border>

    <Border Grid.Row="3" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,1,0,0" Padding="20,12">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <Button x:Name="BtnExport" Grid.Column="0" Content="Export CSV" Style="{StaticResource DlgBtn}"
                HorizontalAlignment="Left"/>
        <Button x:Name="BtnClose"  Grid.Column="1" Content="Close" Style="{StaticResource DlgBtnPrimary}"
                IsDefault="True" IsCancel="True"/>
      </Grid>
    </Border>
  </Grid>
</Window>
"@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $w = [System.Windows.Markup.XamlReader]::Load($reader)
        $w.Title = "Scope preview - $($Scope.Name)"
        $w.Owner = $window
        $w.FindName('DlgTitle').Text   = "Scope preview - $($Scope.Name)"
        $w.FindName('DlgSub').Text     = if ($Scope.RecipientRoot) { "Restricted to OU: $($Scope.RecipientRoot)" } else { "Organization-wide" }
        $w.FindName('FilterText').Text = if ($Scope.RecipientFilter) { [string]$Scope.RecipientFilter } else { '(no filter)' }
        $w.FindName('CountText').Text  = if ($Truncated) {
            "$($Recipients.Count) items (truncated at $Cap)"
        } else {
            "$($Recipients.Count) items"
        }
        $list = $w.FindName('RecipientsList')
        $list.ItemsSource = $Recipients

        $w.FindName('BtnExport').Add_Click({
            $dlg = [System.Windows.Forms.SaveFileDialog]::new()
            $dlg.Filter   = 'CSV (*.csv)|*.csv'
            $dlg.FileName = "scope-preview-$($Scope.Name)-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
            if ($dlg.ShowDialog() -eq 'OK') {
                $Recipients | Export-Csv -Path $dlg.FileName -NoTypeInformation -Encoding UTF8
                Set-Status "Exported scope preview to $($dlg.FileName)." 'ok'
            }
        }.GetNewClosure())
        $w.FindName('BtnClose').Add_Click({ $w.Close() })

        $null = $w.ShowDialog()
    }

    function Visualize-Selected {
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select an assignment first.' 'warn'; return }
        $a = if ($sel._raw) { $sel._raw } else { $sel }
        if (-not $a.Role -or -not $a.RoleAssignee) {
            Set-Status 'Selected row is not an assignment.' 'warn'; return
        }
        $script:VizAssignment = $a
        Reset-VizScopeMembers   # different assignment -> drop the previous scope fan
        Switch-View -View 'Visualizer'
    }

    # Find the role assignments related to a Roles / Role Groups / Scopes row.
    # A role / role group / scope can back several assignments, so this is what
    # lets those views reach the (single-assignment) Visualizer.
    function Get-VizRelatedAssignments {
        param([string]$View, $Selected)
        if (-not $script:Cache.Assignments) {
            try { $script:Cache.Assignments = @(Get-RBACRoleAssignments) } catch { $script:Cache.Assignments = @() }
        }
        $all  = @($script:Cache.Assignments)
        $name = "$($Selected.Name)".Trim()
        if (-not $name) { return @() }

        switch ($View) {
            'Roles' {
                return @($all | Where-Object { "$($_.Role)" -eq $name })
            }
            'RoleGroups' {
                return @($all | Where-Object {
                    "$($_.RoleAssigneeType)" -eq 'RoleGroup' -and "$($_.RoleAssignee)" -eq $name
                })
            }
            'Scopes' {
                # Direct references first (custom scope name or the resolved enum).
                $related = @($all | Where-Object {
                    "$($_.CustomRecipientReadScope)"  -eq $name -or
                    "$($_.CustomRecipientWriteScope)" -eq $name -or
                    "$($_.RecipientReadScope)"        -like "*$name*" -or
                    "$($_.RecipientWriteScope)"       -like "*$name*"
                })
                # Augment with AutoManaged-style assignments that don't expose the
                # scope name, via a direct reverse lookup for THIS scope (one call,
                # cheaper than building the full scope map).
                if (Test-RBACExchangeConnection) {
                    try {
                        $governed = @(Get-ManagementRoleAssignment -CustomRecipientWriteScope $name -ErrorAction Stop |
                            ForEach-Object { "$($_.Name)" })
                        if ($governed.Count -gt 0) {
                            $have = @{}; foreach ($r in $related) { $have["$($r.Name)"] = $true }
                            foreach ($a in $all) {
                                if (($governed -contains "$($a.Name)") -and -not $have.ContainsKey("$($a.Name)")) {
                                    $related += $a
                                }
                            }
                        }
                    }
                    catch { }
                }
                return @($related)
            }
        }
        return @()
    }

    # "Visualize" from Roles / Role Groups / Scopes: resolve the related
    # assignments, then go straight to the graph (1 match) or let the user pick
    # (several matches). Pre-filtered picker reuses Pick-VizAssignment.
    function Visualize-Related {
        if (-not (Require-Connected)) { return }
        $sel = $UI.MainGrid.SelectedItem
        if (-not $sel) { Set-Status 'Select a row first.' 'warn'; return }
        $raw  = if ($sel._raw) { $sel._raw } else { $sel }
        $view = $script:CurrentView
        $label = switch ($view) { 'Roles' { 'role' } 'RoleGroups' { 'role group' } 'Scopes' { 'scope' } default { 'item' } }
        $name = "$($raw.Name)"

        $related = @(Get-VizRelatedAssignments -View $view -Selected $raw)
        if ($related.Count -eq 0) {
            Set-Status "No role assignment references $label '$name'." 'warn'
            return
        }
        if ($related.Count -eq 1) {
            $script:VizAssignment = $related[0]
            Reset-VizScopeMembers
            Switch-View -View 'Visualizer'
            Set-Status "Visualizing $($related[0].Name)." 'ok'
            return
        }
        # Several assignments back this row - let the user choose.
        Pick-VizAssignment -Assignments $related `
            -Title "Assignments using $label '$name'" `
            -Subtitle "$($related.Count) assignments reference this $label. Pick one to visualize as a hub-and-spoke graph."
    }

    function Pick-VizAssignment {
        param(
            [array]$Assignments,
            [string]$Title    = 'Pick a role assignment',
            [string]$Subtitle = 'Choose the assignment to visualize as a hub-and-spoke graph.'
        )
        # Without an explicit list, offer every assignment (the toolbar "Pick
        # assignment…" entry point). Callers from the Roles/Role Groups/Scopes
        # views pass a pre-filtered list of the assignments related to their row.
        if (-not $PSBoundParameters.ContainsKey('Assignments')) {
            if (-not $script:Cache.Assignments) { $script:Cache.Assignments = Get-RBACRoleAssignments }
            $Assignments = @($script:Cache.Assignments)
        }
        $assignments = @($Assignments)
        if ($assignments.Count -eq 0) { Set-Status 'No assignments to pick from.' 'warn'; return }

        $rows = foreach ($a in $assignments) {
            [PSCustomObject]@{
                Name     = $a.Name
                Role     = $a.Role
                Assignee = $a.RoleAssignee
                Scope    = if ($a.RecipientWriteScope) { $a.RecipientWriteScope } else { 'Organization' }
                _raw     = $a
            }
        }

        $dlgXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Pick assignment to visualize"
        Width="820" Height="560" WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI" Background="White" ShowInTaskbar="False">
$($script:DlgResourcesXaml)
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,0,0,1" Padding="20,16">
      <StackPanel>
        <TextBlock x:Name="DlgTitle" Text="Pick a role assignment" FontSize="16" FontWeight="SemiBold" Foreground="#201F1E"/>
        <TextBlock x:Name="DlgSubtitle" Text="Choose the assignment to visualize as a hub-and-spoke graph."
                   FontSize="12" Foreground="#605E5C" Margin="0,2,0,0" TextWrapping="Wrap"/>
      </StackPanel>
    </Border>

    <Border Grid.Row="1" Padding="20,16">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <Border Grid.Row="0" Margin="0,0,0,10" Padding="10,4" Background="White"
                BorderBrush="#C8C6C4" BorderThickness="1" CornerRadius="4" Height="34">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" Text="⌕" Margin="2,0,8,0" Foreground="#605E5C" VerticalAlignment="Center"/>
            <TextBox x:Name="FilterBox" Grid.Column="1" BorderThickness="0" VerticalContentAlignment="Center"
                     Background="Transparent" FontSize="13"/>
            <Border Grid.Column="2" CornerRadius="10" Padding="8,2" Background="#EFEDEB" VerticalAlignment="Center">
              <TextBlock x:Name="CountText" Foreground="#605E5C" FontFamily="Consolas" FontSize="11"/>
            </Border>
          </Grid>
        </Border>
        <ListView x:Name="List" Grid.Row="1" Background="White"
                  BorderBrush="#C8C6C4" BorderThickness="1" SelectionMode="Single" FontSize="12">
          <ListView.View>
            <GridView>
              <GridViewColumn Header="Name"     Width="240" DisplayMemberBinding="{Binding Name}"/>
              <GridViewColumn Header="Role"     Width="160" DisplayMemberBinding="{Binding Role}"/>
              <GridViewColumn Header="Assignee" Width="180" DisplayMemberBinding="{Binding Assignee}"/>
              <GridViewColumn Header="Scope"    Width="160" DisplayMemberBinding="{Binding Scope}"/>
            </GridView>
          </ListView.View>
        </ListView>
      </Grid>
    </Border>

    <Border Grid.Row="2" Background="#F8F8F8" BorderBrush="#E1DFDD" BorderThickness="0,1,0,0" Padding="20,12">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BtnCancel" Content="Cancel"    Style="{StaticResource DlgBtn}" Margin="0,0,8,0" IsCancel="True"/>
        <Button x:Name="BtnOK"     Content="Visualize" Style="{StaticResource DlgBtnPrimary}" IsDefault="True"/>
      </StackPanel>
    </Border>
  </Grid>
</Window>
"@
        $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($dlgXaml))
        $dlg    = [System.Windows.Markup.XamlReader]::Load($reader)
        $dlg.Owner = $window

        $list      = $dlg.FindName('List')
        $filterBox = $dlg.FindName('FilterBox')
        $countText = $dlg.FindName('CountText')
        $btnOK     = $dlg.FindName('BtnOK')
        $btnCancel = $dlg.FindName('BtnCancel')
        $dlgTitle  = $dlg.FindName('DlgTitle')
        $dlgSub    = $dlg.FindName('DlgSubtitle')
        if ($dlgTitle) { $dlgTitle.Text = $Title }
        if ($dlgSub)   { $dlgSub.Text   = $Subtitle }

        $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($rows)
        $list.ItemsSource = $rows
        $countText.Text   = "$($rows.Count) items"

        # Click a GridView column header to sort by that column (toggle asc/desc).
        # WPF's GridView doesn't sort on its own, so wire it up against the same
        # default view (sorting composes with the search filter above). The header
        # text equals the bound property name (Name/Role/Assignee/Scope).
        $sortState = @{ Property = $null; Ascending = $true }
        $list.AddHandler(
            [System.Windows.Controls.GridViewColumnHeader]::ClickEvent,
            [System.Windows.RoutedEventHandler]{
                param($s, $e)
                $header = $e.OriginalSource -as [System.Windows.Controls.GridViewColumnHeader]
                if (-not $header -or $null -eq $header.Column) { return }
                $prop = "$($header.Content)".Trim()
                if (-not $prop) { return }
                if ($sortState.Property -eq $prop) { $sortState.Ascending = -not $sortState.Ascending }
                else { $sortState.Property = $prop; $sortState.Ascending = $true }
                $dir = if ($sortState.Ascending) {
                    [System.ComponentModel.ListSortDirection]::Ascending
                } else {
                    [System.ComponentModel.ListSortDirection]::Descending
                }
                $view.SortDescriptions.Clear()
                $view.SortDescriptions.Add(
                    [System.ComponentModel.SortDescription]::new($prop, $dir))
                $view.Refresh()
            }
        )

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
            Reset-VizScopeMembers   # different assignment -> drop the previous scope fan
            # Re-render in place when already on the Visualizer; otherwise switch
            # to it (Switch-View paints the canvas itself).
            if ($script:CurrentView -eq 'Visualizer') { Render-Visualizer }
            else { Switch-View -View 'Visualizer' }
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

    # ---------------- Visualizer: shared helpers ----------------
    function Reset-VizScopeMembers {
        $script:VizScopeMembers   = $null
        $script:VizScopeInfo      = $null
        $script:VizScopeTruncated = $false
    }

    # Render a visualizer node's details into the shared slide-out panel (same UI
    # the grids use). $NodeInfo = @{ Title; Badge; Rows = @([pscustomobject]@{Key;Value}) }.
    function Show-VizNodeDetails {
        param($NodeInfo)
        if (-not $NodeInfo) { return }
        $UI.DetailsTitle.Text = "$($NodeInfo.Title)"
        if ($NodeInfo.Badge) {
            $UI.DetailsTypeBadgeText.Text   = "$($NodeInfo.Badge)"
            $UI.DetailsTypeBadge.Visibility = 'Visible'
        }
        else { $UI.DetailsTypeBadge.Visibility = 'Collapsed' }

        $rows = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
        foreach ($r in @($NodeInfo.Rows)) {
            $val = "$($r.Value)"; if ([string]::IsNullOrEmpty($val)) { $val = '-' }
            $rows.Add([PSCustomObject]@{ Key = "$($r.Key)"; Value = $val })
        }
        $UI.DetailsList.ItemsSource = $rows

        # "Open in <section>" navigation target for this node (e.g. role -> Roles).
        $script:DetailsNavTarget = $NodeInfo.Nav
        if ($NodeInfo.Nav -and $UI.BtnDetailsGoto) {
            $UI.BtnDetailsGoto.Content    = "↗  $($NodeInfo.Nav.Label)"
            $UI.BtnDetailsGoto.Visibility = 'Visible'
        }
        elseif ($UI.BtnDetailsGoto) { $UI.BtnDetailsGoto.Visibility = 'Collapsed' }

        $UI.DetailsCol.Width        = New-Object System.Windows.GridLength 360
        $UI.DetailsPanel.Visibility = 'Visible'
    }
    # Script-scoped handle so the (scope-detached) node drag handlers can invoke
    # it. Calls the function by name - same proven pattern as the toolbar buttons.
    $script:VizNodeDetailsAction = { param($info) Show-VizNodeDetails $info }

    # Fetch a role's cmdlets and tag each with its verb group/colour bucket,
    # sorted group -> verb -> name. Shared by the WPF render and the HTML export
    # so both colour-code identically.
    function Get-VizClassifiedEntries {
        param([string]$Role)
        $entries = @()
        try { $entries = @(Get-ManagementRoleEntry "$Role\*" -ErrorAction Stop) } catch { $entries = @() }
        foreach ($e in $entries) {
            $shortName = ("$($e.Name)" -split '\\')[-1]
            $verb      = ($shortName -split '-', 2)[0]
            $grp       = $script:VizVerbToGroup[$verb]
            if (-not $grp) { $grp = 'Other' }
            $e | Add-Member -NotePropertyName 'CmdletVerb'       -NotePropertyValue $verb                       -Force
            $e | Add-Member -NotePropertyName 'CmdletGroup'      -NotePropertyValue $grp                        -Force
            $e | Add-Member -NotePropertyName 'CmdletGroupOrder' -NotePropertyValue $script:VizGroupOrder[$grp] -Force
            $e | Add-Member -NotePropertyName 'CmdletShortName'  -NotePropertyValue $shortName                  -Force
        }
        # Sort on plain string/int properties (scriptblock sort keys can lose the
        # enclosing scope in some hosts and produce a junk ordering).
        return @($entries | Sort-Object CmdletGroupOrder, CmdletVerb, CmdletShortName)
    }

    # Best available *name* for an assignment's write/read scope. Custom scopes
    # normally expose the name via CustomRecipient*Scope, but in some tenants that
    # property comes back empty while the resolved name lives on the *ScopeDetails
    # object (same object whose .RecipientFilter is used elsewhere) - so we probe
    # both, then the pre-formatted "Custom: <name> (...)" string. Returns '' when
    # there is no resolvable custom scope name (i.e. a built-in scope type).
    function Get-VizScopeName {
        param($Assignment, [ValidateSet('Write','Read')]$Which = 'Write')
        if ($Which -eq 'Write') {
            $custom   = "$($Assignment.CustomRecipientWriteScope)".Trim()
            $details  = $Assignment.WriteScopeDetails
            $fallback = "$($Assignment.RecipientWriteScope)".Trim()
        }
        else {
            $custom   = "$($Assignment.CustomRecipientReadScope)".Trim()
            $details  = $Assignment.ReadScopeDetails
            $fallback = "$($Assignment.RecipientReadScope)".Trim()
        }
        if ($custom) { return $custom }
        if ($details) {
            foreach ($prop in 'Name','ScopeName') {
                if ($details.PSObject.Properties.Match($prop).Count -gt 0) {
                    $dn = "$($details.$prop)".Trim()
                    if ($dn) { return $dn }
                }
            }
        }
        $m = [regex]::Match($fallback, '^Custom:\s*(.+?)(?:\s*\(Filter:.*)?$')
        if ($m.Success) { return $m.Groups[1].Value.Trim() }
        return ''
    }

    # Reverse map "assignment name (lower) -> custom WRITE-scope name", built once
    # per session. This is the only reliable link for AutoManaged-* assignments,
    # whose own objects never surface the scope name: we ask Exchange which
    # assignments each management scope governs via
    # Get-ManagementRoleAssignment -CustomRecipientWriteScope <scope>.
    function Get-VizWriteScopeMap {
        if ($null -ne $script:VizScopeCatalog) { return $script:VizScopeCatalog }
        $map = @{}
        if (Test-RBACExchangeConnection) {
            try {
                $scopes = @(Get-ManagementScope -ErrorAction Stop | Where-Object { -not $_.Default })
                foreach ($s in $scopes) {
                    try {
                        $used = @(Get-ManagementRoleAssignment -CustomRecipientWriteScope $s.Name -ErrorAction Stop)
                        foreach ($u in $used) {
                            $k = "$($u.Name)".Trim().ToLowerInvariant()
                            if ($k) { $map[$k] = "$($s.Name)" }
                        }
                    }
                    catch { }
                }
            }
            catch { }
        }
        $script:VizScopeCatalog = $map
        return $map
    }

    # Resolve a custom scope's name: from the assignment object, else by
    # re-querying it by identity, else (write scope) via the reverse scope map.
    # Result (including '' for "no custom name") is cached per assignment+side so
    # a render never round-trips twice.
    function Resolve-VizScopeName {
        param($Assignment, [ValidateSet('Write','Read')]$Which = 'Write')
        $name = Get-VizScopeName -Assignment $Assignment -Which $Which
        if ($name) { return $name }

        $key = "$($Assignment.Name)|$Which"
        if ($script:VizScopeNameCache.ContainsKey($key)) { return $script:VizScopeNameCache[$key] }

        $resolved = ''
        $type = if ($Which -eq 'Write') { "$($Assignment.RecipientWriteScope)" } else { "$($Assignment.RecipientReadScope)" }
        # Only a custom scope whose name didn't come through is worth the work.
        if ($type -match 'Custom' -and $Assignment.Name -and (Test-RBACExchangeConnection)) {
            # 1) Name straight off the by-identity object (usual case).
            try {
                $full = Get-ManagementRoleAssignment -Identity $Assignment.Name -ErrorAction Stop | Select-Object -First 1
                if ($full) { $resolved = Get-VizScopeName -Assignment $full -Which $Which }
            }
            catch { $resolved = '' }
            # 2) Reverse scope map for the WRITE scope - covers AutoManaged-*
            #    assignments whose objects never carry the scope name.
            if (-not $resolved -and $Which -eq 'Write') {
                $vmap = Get-VizWriteScopeMap
                $mk   = "$($Assignment.Name)".Trim().ToLowerInvariant()
                if ($vmap.ContainsKey($mk)) { $resolved = $vmap[$mk] }
            }
        }
        $script:VizScopeNameCache[$key] = $resolved
        return $resolved
    }

    # Scope label for a node: the resolved name when there is one, otherwise the
    # scope type/enum so the node is never blank.
    function Get-VizScopeDisplay {
        param($Assignment, [ValidateSet('Write','Read')]$Which = 'Write')
        $name = Resolve-VizScopeName -Assignment $Assignment -Which $Which
        if ($name) { return $name }
        $fallback = if ($Which -eq 'Write') { "$($Assignment.RecipientWriteScope)" } else { "$($Assignment.RecipientReadScope)" }
        $fallback = "$fallback".Trim()
        if (-not $fallback) { return 'Organization' }
        return $fallback
    }

    # Flatten a (possibly multi-valued) RecipientFilter into a single valid OPATH.
    function ConvertTo-VizFilterString {
        param($RawFilter)
        if ($null -eq $RawFilter) { return '' }
        if ($RawFilter -is [string]) { return $RawFilter.Trim() }
        if ($RawFilter -is [System.Collections.IEnumerable]) {
            $parts = foreach ($p in $RawFilter) { $t = "$p".Trim(); if ($t) { "($t)" } }
            return (($parts -join ' -or ').Trim())
        }
        return ([string]$RawFilter).Trim()
    }

    # ---------------- Visualizer: scope members ----------------
    function Show-VizScopeMembers {
        if (-not (Require-Connected)) { return }
        $a = $script:VizAssignment
        if (-not $a) { Set-Status 'Pick an assignment to visualize first.' 'warn'; return }

        $scopeName = Resolve-VizScopeName -Assignment $a -Which Write
        if (-not $scopeName) {
            $builtIn = Get-VizScopeDisplay -Assignment $a -Which Write
            Set-Status "Assignment '$($a.Name)' uses the built-in write scope '$builtIn' - no custom recipient filter to resolve." 'warn'
            return
        }

        $scope = $null
        try { $scope = Get-ManagementScope -Identity $scopeName -ErrorAction Stop }
        catch { Set-Status "Could not load management scope '$scopeName': $($_.Exception.Message)" 'error'; return }

        $filter = ConvertTo-VizFilterString -RawFilter $scope.RecipientFilter
        $root   = "$($scope.RecipientRoot)".Trim()
        if (-not $filter -and -not $root) {
            Set-Status "Scope '$scopeName' has neither a RecipientFilter nor a RecipientRoot - nothing to resolve." 'warn'
            return
        }

        $cap = $script:VizScopeCap
        Set-Status "Resolving members of scope '$scopeName' (capped at $cap)…"
        try {
            $recipientArgs = @{ ResultSize = $cap; ErrorAction = 'Stop' }
            if ($filter) { $recipientArgs.RecipientPreviewFilter = $filter }
            if ($root)   { $recipientArgs.OrganizationalUnit     = $root }
            $recipients = @(Get-Recipient @recipientArgs |
                Select-Object Name, RecipientTypeDetails, PrimarySmtpAddress, OrganizationalUnit)
        }
        catch { Set-Status "Failed to resolve scope members: $($_.Exception.Message)" 'error'; return }

        $script:VizScopeInfo      = $scope
        $script:VizScopeTruncated = ($recipients.Count -ge $cap)
        $script:VizScopeMembers   = $recipients
        Render-Visualizer

        if ($recipients.Count -eq 0) {
            Set-Status "Scope '$scopeName' currently matches no recipients." 'warn'
        }
        elseif ($script:VizScopeTruncated) {
            Set-Status "Showing first $cap member(s) of scope '$scopeName' (truncated; refine the filter to narrow)." 'warn'
        }
        else {
            Set-Status "$($recipients.Count) member(s) in scope '$scopeName'." 'ok'
        }
    }

    # ---------------- Visualizer: interactive HTML export ----------------
    # Build a serialisable hub-and-spoke graph model (nodes + edges + legend)
    # from the current assignment. The HTML viewer lays it out client-side.
    function Get-VizGraphModel {
        param($Assignment)
        $a = $Assignment
        $entries = Get-VizClassifiedEntries -Role $a.Role
        $writeScopeName = Get-VizScopeDisplay -Assignment $a -Which Write
        $readScopeName  = Get-VizScopeDisplay -Assignment $a -Which Read

        $nodes = [System.Collections.Generic.List[object]]::new()
        $edges = [System.Collections.Generic.List[object]]::new()

        $null = $nodes.Add([ordered]@{ id='hub'; type='hub'; group=''; label="$($a.Name)"; sub='ASSIGNMENT';
            bg='#E6E0F8'; border='#0078D4'; fg='#3F0C57'; tooltip="Assignment: $($a.Name)" })
        $null = $nodes.Add([ordered]@{ id='role'; type='role'; group=''; label="$($a.Role)"; sub='What · Role';
            bg='#DFF6DD'; border='#558B2F'; fg='#1B3A12'; tooltip="Role: $($a.Role)" })
        $null = $nodes.Add([ordered]@{ id='assignee'; type='assignee'; group=''; label="$($a.RoleAssignee)"; sub="Who · $($a.RoleAssigneeType)";
            bg='#FFF4CE'; border='#B28704'; fg='#5C3A00'; tooltip="Assignee: $($a.RoleAssignee) ($($a.RoleAssigneeType))" })
        $null = $nodes.Add([ordered]@{ id='scope'; type='scope'; group=''; label=$writeScopeName; sub="Where · Read: $readScopeName";
            bg='#FCE4E4'; border='#A4262C'; fg='#7A1A1F'; tooltip="Write scope: $writeScopeName`nRead scope: $readScopeName" })

        $null = $edges.Add([ordered]@{ source='hub'; target='role';     kind='spoke' })
        $null = $edges.Add([ordered]@{ source='hub'; target='assignee'; kind='spoke' })
        $null = $edges.Add([ordered]@{ source='hub'; target='scope';    kind='spoke' })

        for ($i = 0; $i -lt $entries.Count; $i++) {
            $e   = $entries[$i]
            $pal = $script:VizVerbPalettes[$e.CmdletGroup]
            $id  = "cmd$i"
            $null = $nodes.Add([ordered]@{ id=$id; type='cmdlet'; group=$e.CmdletGroup; label="$($e.CmdletShortName)"; sub='';
                bg=$pal.Bg; border=$pal.Border; fg=$pal.Fg; tooltip="$($e.Name) [$($e.CmdletGroup) · $($e.CmdletVerb)]" })
            $null = $edges.Add([ordered]@{ source='role'; target=$id; kind='cmdlet'; group=$e.CmdletGroup })
        }

        $memPal  = $script:VizMemberPalette
        # Filter out nulls (@($null) is a 1-element array) so the export never
        # carries a phantom empty member node.
        $members = @($script:VizScopeMembers | Where-Object { $null -ne $_ })
        for ($i = 0; $i -lt $members.Count; $i++) {
            $m  = $members[$i]
            $id = "mem$i"
            $null = $nodes.Add([ordered]@{ id=$id; type='member'; group='Member'; label="$($m.Name)"; sub="$($m.RecipientTypeDetails)";
                bg=$memPal.Bg; border=$memPal.Border; fg=$memPal.Fg; tooltip="$($m.Name)`n$($m.PrimarySmtpAddress)`n$($m.RecipientTypeDetails)" })
            $null = $edges.Add([ordered]@{ source='scope'; target=$id; kind='member' })
        }

        $legend = [System.Collections.Generic.List[object]]::new()
        $groupCounts = @{}
        foreach ($e in $entries) {
            if (-not $groupCounts.ContainsKey($e.CmdletGroup)) { $groupCounts[$e.CmdletGroup] = 0 }
            $groupCounts[$e.CmdletGroup]++
        }
        foreach ($g in @('Read','Modify','Destructive','Create','Other')) {
            if (-not $groupCounts.ContainsKey($g)) { continue }
            $p = $script:VizVerbPalettes[$g]
            $null = $legend.Add([ordered]@{ key=$g; label="$g ($($groupCounts[$g]))"; color=$p.Bg; border=$p.Border })
        }
        if ($members.Count -gt 0) {
            $suffix = if ($script:VizScopeTruncated) { '+' } else { '' }
            $null = $legend.Add([ordered]@{ key='Member'; label="Scope members ($($members.Count)$suffix)"; color=$memPal.Bg; border=$memPal.Border })
        }

        return [ordered]@{
            meta = [ordered]@{
                title           = "$($a.Name)"
                role            = "$($a.Role)"
                assignee        = "$($a.RoleAssignee)"
                assigneeType    = "$($a.RoleAssigneeType)"
                scope           = $writeScopeName
                readScope       = $readScopeName
                cmdletCount     = $entries.Count
                memberCount     = $members.Count
                memberTruncated = [bool]$script:VizScopeTruncated
                generated       = (Get-Date -Format 'yyyy-MM-dd HH:mm')
            }
            nodes  = $nodes
            edges  = $edges
            legend = $legend
        }
    }

    function Export-VizHtml {
        $a = $script:VizAssignment
        if (-not $a) { Set-Status 'Pick an assignment to visualize first.' 'warn'; return }

        $dlg = [System.Windows.Forms.SaveFileDialog]::new()
        $dlg.Filter = 'HTML (*.html)|*.html'
        $safeName = ("$($a.Name)" -replace '[\\/:*?"<>|]+', '_')
        $dlg.FileName = "rbac-viz-$safeName-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
        if ($dlg.ShowDialog() -ne 'OK') { return }

        try {
            $model = Get-VizGraphModel -Assignment $a
            $json  = $model | ConvertTo-Json -Depth 12 -Compress
            $html  = Build-VizHtmlDocument -Json $json -Title "$($a.Name)" -Generated $model.meta.generated
            [System.IO.File]::WriteAllText($dlg.FileName, $html, [System.Text.UTF8Encoding]::new($true))
            Set-Status "Exported interactive HTML to $($dlg.FileName)." 'ok'
            try { Start-Process $dlg.FileName } catch { }
        }
        catch { Set-Status "HTML export failed: $($_.Exception.Message)" 'error' }
    }

    # Assemble the self-contained interactive HTML document. The graph model is
    # injected as JSON; the SVG/JS viewer (pan/zoom/drag/hover/details) needs no
    # external libraries so the file opens offline in any modern browser.
    function Build-VizHtmlDocument {
        param([string]$Json, [string]$Title, [string]$Generated)

        # Guard the JSON against premature </script> / comment termination.
        $safeJson = $Json.Replace('</script>', '<\/script>').Replace('<!--', '<\!--')
        $esc = {
            param([string]$s)
            ($s -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;')
        }
        $safeTitle = & $esc $Title
        $safeGen   = & $esc $Generated

        $tpl = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RBAC Visualizer - __TITLE__</title>
<style>
  * { box-sizing: border-box; }
  html, body { margin:0; height:100%; font-family:"Segoe UI",system-ui,sans-serif; color:#201F1E; }
  #topbar { position:fixed; top:0; left:0; right:0; height:52px; display:flex; align-items:center; gap:12px;
            padding:0 16px; background:#fff; border-bottom:1px solid #E1DFDD; z-index:10; }
  #topbar .title { font-weight:600; font-size:14px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:46vw; }
  #topbar .sub { color:#605E5C; font-size:12px; }
  #topbar .spacer { flex:1; }
  #topbar button { font-size:13px; padding:6px 12px; border:1px solid #C8C6C4; background:#fff; border-radius:4px; cursor:pointer; color:#201F1E; }
  #topbar button:hover { background:#F3F2F1; }
  #stage { position:fixed; top:52px; left:0; right:0; bottom:0; background:#FAFAFA; overflow:hidden; }
  svg { width:100%; height:100%; display:block; cursor:grab; }
  svg.panning { cursor:grabbing; }
  .edge { stroke:#605E5C; stroke-width:1.4; }
  .edge.cmdlet { stroke:#558B2F; stroke-width:1.1; stroke-dasharray:4 2; }
  .edge.member { stroke:#2B88D8; stroke-width:1.0; stroke-dasharray:4 2; }
  .edge.faded { opacity:0.08; }
  .node { cursor:pointer; }
  .node rect, .node circle { stroke-width:1.5; }
  .node text { pointer-events:none; }
  .node.faded { opacity:0.12; }
  .node.hl rect, .node.hl circle { stroke-width:2.6; }
  #panel { position:fixed; right:20px; top:72px; width:300px; background:#fff; border:1px solid #E1DFDD;
           border-radius:6px; box-shadow:0 8px 32px rgba(0,0,0,0.15); z-index:20; display:none; overflow:hidden; }
  #panel .ph { display:flex; align-items:center; justify-content:space-between; padding:10px 14px; border-bottom:1px solid #E1DFDD; }
  #panel .ph h4 { margin:0; font-size:14px; word-break:break-word; }
  #panel .ph button { border:none; background:transparent; cursor:pointer; font-size:18px; color:#605E5C; line-height:1; }
  #panel .pb { padding:12px 14px; font-size:13px; }
  #panel .row { margin-bottom:10px; }
  #panel .k { color:#605E5C; display:block; font-size:11px; margin-bottom:2px; text-transform:uppercase; letter-spacing:.03em; }
  #panel .v { word-break:break-word; white-space:pre-wrap; }
  #panel .badge { display:inline-block; padding:2px 8px; border-radius:9999px; font-size:11px; font-weight:600; }
  #legend { position:fixed; left:16px; bottom:16px; background:#fff; border:1px solid #E1DFDD; border-radius:6px;
            padding:8px 12px; font-size:11px; z-index:10; box-shadow:0 4px 16px rgba(0,0,0,0.08); max-width:72vw; }
  #legend .lt { font-family:Consolas,monospace; color:#605E5C; margin-right:8px; }
  #legend .li { display:inline-flex; align-items:center; gap:5px; margin:2px 10px 2px 0; }
  #legend .sw { width:11px; height:11px; border-radius:2px; display:inline-block; border:1px solid rgba(0,0,0,.25); }
  #hint { position:fixed; right:16px; bottom:14px; color:#A19F9D; font-size:11px; z-index:10; }
</style>
</head>
<body>
<div id="topbar">
  <span class="title" id="ttl">__TITLE__</span>
  <span class="sub">RBAC assignment - exported __GENERATED__</span>
  <span class="spacer"></span>
  <button id="btnFit">Fit</button>
  <button id="btnReset">Re-layout</button>
</div>
<div id="stage">
  <svg id="svg" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
        <path d="M0,0 L10,5 L0,10 z" fill="#9B9B9B"></path>
      </marker>
    </defs>
    <g id="viewport">
      <g id="edges"></g>
      <g id="nodes"></g>
    </g>
  </svg>
</div>
<div id="panel">
  <div class="ph"><h4 id="pName"></h4><button id="pClose" title="Close">&times;</button></div>
  <div class="pb" id="pBody"></div>
</div>
<div id="legend"></div>
<div id="hint">drag nodes - scroll to zoom - drag empty space to pan</div>
<script>
var GRAPH = __GRAPH_JSON__;
(function(){
  "use strict";
  var SVGNS = "http://www.w3.org/2000/svg";
  var svg = document.getElementById('svg');
  var viewport = document.getElementById('viewport');
  var gEdges = document.getElementById('edges');
  var gNodes = document.getElementById('nodes');
  var byId = {};
  GRAPH.nodes.forEach(function(n){ byId[n.id] = n; });

  var adj = {};
  GRAPH.nodes.forEach(function(n){ adj[n.id] = {}; });
  GRAPH.edges.forEach(function(e){ adj[e.source][e.target]=1; adj[e.target][e.source]=1; });

  function esc(s){ return String(s==null?'':s); }
  function truncate(s, max){ s=String(s==null?'':s); return s.length>max ? s.slice(0,max-1)+'…' : s; }

  function layout(){
    var cx=0, cy=0;
    var hub = byId['hub']; if(hub){ hub.x=cx; hub.y=cy; hub.w=140; hub.h=140; hub.shape='circle'; }
    var spokes = { role:{x:cx-300,y:cy-190}, assignee:{x:cx+300,y:cy-190}, scope:{x:cx,y:cy+250} };
    ['role','assignee','scope'].forEach(function(k){
      var n=byId[k]; if(!n) return; n.x=spokes[k].x; n.y=spokes[k].y; n.w=212; n.h=66; n.shape='rect';
    });
    fan(GRAPH.nodes.filter(function(n){return n.type==='cmdlet';}), byId['role'],  cx, cy, 156, 26, 215, 84, 12);
    fan(GRAPH.nodes.filter(function(n){return n.type==='member';}), byId['scope'], cx, cy, 168, 26, 185, 70, 11);
  }
  function fan(items, center, cx, cy, w, h, baseR, ringSpacing, perRing){
    if(!center) return;
    var vx=center.x-cx, vy=center.y-cy, vlen=Math.hypot(vx,vy)||1;
    var base=Math.atan2(vy/vlen, vx/vlen);
    items.forEach(function(n,i){
      var ring=Math.floor(i/perRing), pos=i%perRing;
      var r=baseR + ring*ringSpacing;
      var ang=base + 2*Math.PI*pos/perRing;
      n.x = center.x + r*Math.cos(ang);
      n.y = center.y + r*Math.sin(ang);
      n.w=w; n.h=h; n.shape='rect';
    });
  }

  var nodeEls = {};
  var edgeEls = [];
  function render(){
    gEdges.textContent=''; gNodes.textContent=''; nodeEls={}; edgeEls=[];
    GRAPH.edges.forEach(function(e){
      var line=document.createElementNS(SVGNS,'line');
      var cls='edge'+(e.kind==='cmdlet'?' cmdlet':(e.kind==='member'?' member':''));
      line.setAttribute('class',cls);
      line.setAttribute('marker-end','url(#arrow)');
      gEdges.appendChild(line);
      edgeEls.push({el:line, e:e});
    });
    GRAPH.nodes.forEach(function(n){
      var g=document.createElementNS(SVGNS,'g');
      g.setAttribute('class','node');
      g.setAttribute('data-id',n.id);
      var shape;
      if(n.shape==='circle'){
        shape=document.createElementNS(SVGNS,'circle');
        shape.setAttribute('r', n.w/2);
      } else {
        shape=document.createElementNS(SVGNS,'rect');
        shape.setAttribute('x', -n.w/2); shape.setAttribute('y', -n.h/2);
        shape.setAttribute('width', n.w); shape.setAttribute('height', n.h);
        shape.setAttribute('rx', 5);
      }
      shape.setAttribute('fill', n.bg||'#fff');
      shape.setAttribute('stroke', n.border||'#605E5C');
      g.appendChild(shape);
      appendLabels(g, n);
      gNodes.appendChild(g);
      nodeEls[n.id]=g;
    });
    positionAll();
  }
  function appendLabels(g, n){
    var fg=n.fg||'#201F1E';
    var lines=[];
    if(n.type==='hub'){
      lines.push({t:'ASSIGNMENT', s:9, c:'#605E5C', dy:-6, mono:true});
      lines.push({t:truncate(n.label,18), s:12, c:fg, dy:12, bold:true});
    } else if(n.type==='role'||n.type==='assignee'||n.type==='scope'){
      lines.push({t:truncate(n.sub||'', 30), s:9, c:'#605E5C', dy:-15, mono:true});
      lines.push({t:truncate(n.label, 24), s:13, c:fg, dy:5, bold:true});
    } else {
      lines.push({t:truncate(n.label, 22), s:9.5, c:fg, dy:3, bold:true});
    }
    lines.forEach(function(l){
      if(!l.t) return;
      var t=document.createElementNS(SVGNS,'text');
      t.setAttribute('text-anchor','middle');
      t.setAttribute('y', l.dy);
      t.setAttribute('font-size', l.s);
      t.setAttribute('fill', l.c);
      if(l.bold) t.setAttribute('font-weight','600');
      if(l.mono) t.setAttribute('font-family','Consolas,monospace');
      t.textContent=l.t;
      g.appendChild(t);
    });
  }
  function positionAll(){
    GRAPH.nodes.forEach(function(n){
      var g=nodeEls[n.id];
      if(g) g.setAttribute('transform','translate('+n.x+','+n.y+')');
    });
    edgeEls.forEach(function(le){
      var s=byId[le.e.source], t=byId[le.e.target];
      if(!s||!t) return;
      le.el.setAttribute('x1', s.x); le.el.setAttribute('y1', s.y);
      le.el.setAttribute('x2', t.x); le.el.setAttribute('y2', t.y);
    });
  }

  var view={x:0,y:0,k:1};
  function applyView(){ viewport.setAttribute('transform','translate('+view.x+','+view.y+') scale('+view.k+')'); }
  function fit(){
    if(!GRAPH.nodes.length) return;
    var xs=[], ys=[];
    GRAPH.nodes.forEach(function(n){ xs.push(n.x-n.w/2); xs.push(n.x+n.w/2); ys.push(n.y-n.h/2); ys.push(n.y+n.h/2); });
    var minX=Math.min.apply(null,xs), maxX=Math.max.apply(null,xs);
    var minY=Math.min.apply(null,ys), maxY=Math.max.apply(null,ys);
    var pad=60, w=svg.clientWidth, h=svg.clientHeight;
    var bw=(maxX-minX)+pad*2, bh=(maxY-minY)+pad*2;
    var k=Math.min(w/bw, h/bh, 1.6); if(!isFinite(k)||k<=0) k=1;
    view.k=k;
    view.x = w/2 - ((minX+maxX)/2)*k;
    view.y = h/2 - ((minY+maxY)/2)*k;
    applyView();
  }

  svg.addEventListener('wheel', function(ev){
    ev.preventDefault();
    var rect=svg.getBoundingClientRect();
    var mx=ev.clientX-rect.left, my=ev.clientY-rect.top;
    var factor=Math.pow(1.0015, -ev.deltaY);
    var nk=Math.min(Math.max(view.k*factor, 0.12), 5);
    var f=nk/view.k;
    view.x = mx - (mx-view.x)*f;
    view.y = my - (my-view.y)*f;
    view.k = nk;
    applyView();
  }, {passive:false});

  var drag=null, suppressClick=false;
  svg.addEventListener('mousedown', function(ev){
    var ng=ev.target.closest ? ev.target.closest('.node') : null;
    var rect=svg.getBoundingClientRect();
    var mx=ev.clientX-rect.left, my=ev.clientY-rect.top;
    if(ng){
      var id=ng.getAttribute('data-id');
      drag={type:'node', id:id, sx:mx, sy:my, ox:byId[id].x, oy:byId[id].y, moved:false};
    } else {
      svg.classList.add('panning');
      drag={type:'pan', sx:mx, sy:my, ox:view.x, oy:view.y, moved:false};
    }
  });
  window.addEventListener('mousemove', function(ev){
    if(!drag) return;
    var rect=svg.getBoundingClientRect();
    var mx=ev.clientX-rect.left, my=ev.clientY-rect.top;
    if(Math.abs(mx-drag.sx)+Math.abs(my-drag.sy) > 3) drag.moved=true;
    if(drag.type==='pan'){
      view.x=drag.ox+(mx-drag.sx); view.y=drag.oy+(my-drag.sy); applyView();
    } else {
      var n=byId[drag.id];
      n.x=drag.ox+(mx-drag.sx)/view.k;
      n.y=drag.oy+(my-drag.sy)/view.k;
      positionAll();
    }
  });
  window.addEventListener('mouseup', function(){
    if(drag && drag.moved){ suppressClick=true; setTimeout(function(){ suppressClick=false; }, 0); }
    svg.classList.remove('panning');
    drag=null;
  });

  gNodes.addEventListener('mouseover', function(ev){
    var ng=ev.target.closest('.node'); if(!ng) return;
    setHighlight(ng.getAttribute('data-id'));
  });
  gNodes.addEventListener('mouseout', function(ev){
    var ng=ev.target.closest('.node'); if(!ng) return;
    clearHighlight();
  });
  function setHighlight(id){
    GRAPH.nodes.forEach(function(n){
      var g=nodeEls[n.id]; if(!g) return;
      if(n.id===id || adj[id][n.id]){ g.classList.remove('faded'); g.classList.add('hl'); }
      else { g.classList.add('faded'); g.classList.remove('hl'); }
    });
    edgeEls.forEach(function(le){
      var on = (le.e.source===id || le.e.target===id);
      le.el.classList.toggle('faded', !on);
    });
  }
  function clearHighlight(){
    GRAPH.nodes.forEach(function(n){ var g=nodeEls[n.id]; if(g){ g.classList.remove('faded','hl'); } });
    edgeEls.forEach(function(le){ le.el.classList.remove('faded'); });
  }

  var panel=document.getElementById('panel');
  gNodes.addEventListener('click', function(ev){
    var ng=ev.target.closest('.node'); if(!ng) return;
    if(suppressClick) return;
    showPanel(byId[ng.getAttribute('data-id')]);
  });
  function typeLabel(t){
    return ({hub:'Assignment',role:'Role',assignee:'Assignee',scope:'Scope',cmdlet:'Cmdlet',member:'Scope member'})[t]||t;
  }
  function showPanel(n){
    document.getElementById('pName').textContent = n.label||'';
    var rows='';
    rows += '<div class="row"><span class="k">Type</span><span class="badge" style="background:'+n.bg+';color:'+n.fg+';border:1px solid '+n.border+';">'+esc(typeLabel(n.type))+(n.group?(' · '+esc(n.group)):'')+'</span></div>';
    if(n.sub) rows += '<div class="row"><span class="k">Detail</span><span class="v">'+esc(n.sub)+'</span></div>';
    if(n.tooltip) rows += '<div class="row"><span class="k">Info</span><span class="v">'+esc(n.tooltip)+'</span></div>';
    document.getElementById('pBody').innerHTML = rows;
    panel.style.display='block';
  }
  document.getElementById('pClose').addEventListener('click', function(){ panel.style.display='none'; });
  svg.addEventListener('click', function(ev){ if(ev.target===svg && !suppressClick) panel.style.display='none'; });

  (function(){
    var L=document.getElementById('legend');
    if(!GRAPH.legend || !GRAPH.legend.length){ L.style.display='none'; return; }
    var html='<span class="lt">LEGEND</span>';
    GRAPH.legend.forEach(function(it){
      html += '<span class="li"><span class="sw" style="background:'+it.color+';border-color:'+it.border+'"></span>'+esc(it.label)+'</span>';
    });
    L.innerHTML=html;
  })();

  document.getElementById('btnFit').addEventListener('click', fit);
  document.getElementById('btnReset').addEventListener('click', function(){ layout(); positionAll(); fit(); });
  window.addEventListener('resize', fit);

  layout(); render(); fit();
})();
</script>
</body>
</html>
'@

        return $tpl.Replace('__GRAPH_JSON__', $safeJson).Replace('__TITLE__', $safeTitle).Replace('__GENERATED__', $safeGen)
    }

    # ---------------- Connect / Disconnect ----------------
    function Do-Connect {
        try {
            $useWam = ($UI.ChkUseWAM.IsChecked -eq $true)
            $brokerLabel = if ($useWam) { 'WAM enabled' } else { 'WAM disabled' }
            Set-Status "Connecting to Exchange Online ($brokerLabel)..."

            $loadingMsg = if ($useWam) {
                'Connecting to Exchange Online (WAM)...'
            }
            else {
                "Connecting to Exchange Online...`nA browser sign-in window will open. Complete sign-in there, then return to this app.`n(The window will freeze briefly until sign-in completes.)"
            }
            Show-Loading -Message $loadingMsg

            # Force a render before Connect-ExchangeOnline takes the dispatcher.
            # Connect-ExchangeOnline can't be moved to a child runspace because
            # the module imports its proxy cmdlets into the calling runspace -
            # disposing the child runspace would lose the session and the cmdlets
            # would be invisible from the main runspace.
            $window.Dispatcher.Invoke(
                [action]{},
                [System.Windows.Threading.DispatcherPriority]::Render
            )

            $connectArgs = @{}
            if (-not $useWam) { $connectArgs['DisableWAM'] = $true }

            # MSAL.NET (used by Connect-ExchangeOnline -DisableWAM) captures the
            # WPF dispatcher's SynchronizationContext and tries to marshal the
            # post-browser auth callback back to the UI thread. Since the UI
            # thread is synchronously blocked inside Connect-ExchangeOnline,
            # that callback can never run -> deadlock right after the browser
            # shows "Authentication complete". Clear the current SyncContext
            # for the duration of the call so MSAL uses the thread pool
            # instead and the cmdlet returns normally.
            $prevSyncCtx = [System.Threading.SynchronizationContext]::Current
            try {
                [System.Threading.SynchronizationContext]::SetSynchronizationContext($null)
                $null = Connect-RBACExchangeOnline @connectArgs
            }
            finally {
                [System.Threading.SynchronizationContext]::SetSynchronizationContext($prevSyncCtx)
            }

            Update-ConnectionUI

            # Warm the Command Lookup typeahead cache now, while the loading overlay
            # is still up. Get-Command over the EXO session module is bound to this
            # runspace (it can't be backgrounded - see the note above), so building
            # it here keeps it off the keystroke path; otherwise it ran on the UI
            # thread at the 2nd character typed and froze Command Lookup.
            Show-Loading -Message 'Caching available cmdlets…'
            Ensure-CommandSuggestions

            Set-Status 'Connected. Click Refresh or pick a section in the sidebar to load data.' 'ok'
        }
        catch { Set-Status "Connect failed: $($_.Exception.Message)" 'error' }
        finally {
            Hide-Loading
            $window.Dispatcher.Invoke(
                [action]{},
                [System.Windows.Threading.DispatcherPriority]::Render
            )
        }
    }
    function Do-Disconnect {
        try {
            $null = Disconnect-RBACExchange
            $script:Cache.Clear()
            # Session-scoped caches live outside $script:Cache - clear them so a
            # reconnect (possibly to another tenant) rebuilds from scratch.
            $script:CommandSuggestions       = $null
            $script:CommandSuggestionsLoaded = $false
            $script:VizScopeNameCache        = @{}
            $script:VizScopeCatalog          = $null
            $UI.MainGrid.ItemsSource = $null
            $UI.ItemCount.Text = '0 items'
            Update-ConnectionUI
            Set-Status 'Disconnected.' 'ok'
        }
        catch { Set-Status "Disconnect failed: $($_.Exception.Message)" 'error' }
    }

    # ---------------- Wire events ----------------
    $UI.BtnConnect.Add_Click({ Do-Connect })
    $UI.BtnWamInfo.Add_Click({
            $msg = @'
WAM (Web Account Manager) is the Windows authentication broker used by ExchangeOnlineManagement 3.7.0+ by default.

It can pop a native Windows account picker and silently reuse Microsoft Entra ID accounts already signed in on the machine.

Why you might want to disable it:
  - Connecting from a non-domain or non-Entra-joined machine
  - WAM fails to launch its window (some RDP / Citrix sessions)
  - You want to force a clean browser-based sign-in
  - Authenticating with a guest / external account

When the box is unchecked, the module passes -DisableWAM to Connect-ExchangeOnline, falling back to the classic device-code / browser flow.
'@
            [System.Windows.MessageBox]::Show($msg, 'About WAM (Web Account Manager)',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information) | Out-Null
        })
    $UI.BtnDisconnect.Add_Click({ Do-Disconnect })
    $UI.BtnFilterRow.Add_Click({ Toggle-FilterRow })
    $UI.BtnWrap.Add_Click({ Toggle-Wrap })
    $UI.BtnAutoFit.Add_Click({ Auto-FitColumns })

    # Activity log drawer controls.
    if ($UI.BtnLogClear) {
        $UI.BtnLogClear.Add_Click({
            $UI.TxtLog.Clear()
            $script:GuiLogCount = 0
            if ($UI.LogCount) { $UI.LogCount.Text = '' }
        })
    }
    if ($UI.BtnLogExport) {
        $UI.BtnLogExport.Add_Click({
            if ([string]::IsNullOrEmpty($UI.TxtLog.Text)) { Set-Status 'Activity log is empty.' 'warn'; return }
            $dlg = [System.Windows.Forms.SaveFileDialog]::new()
            $dlg.Filter   = 'Log file (*.log)|*.log|Text file (*.txt)|*.txt'
            $dlg.FileName = "ExchangeRBACManager-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
            if ($dlg.ShowDialog() -eq 'OK') {
                try {
                    [System.IO.File]::WriteAllText($dlg.FileName, $UI.TxtLog.Text, [System.Text.UTF8Encoding]::new($true))
                    Set-Status "Exported activity log to $($dlg.FileName)." 'ok'
                }
                catch { Set-Status "Log export failed: $($_.Exception.Message)" 'error' }
            }
        })
    }

    # External links in the sidebar footer - open in the user's default browser.
    $openLink = {
        param($url)
        try { Start-Process $url } catch { Set-Status "Could not open link: $($_.Exception.Message)" 'error' }
    }
    $UI.LinkLinkedIn.Add_MouseLeftButtonDown({ & $openLink 'https://www.linkedin.com/in/perez-bastien/' })
    $UI.LinkGitHub.Add_MouseLeftButtonDown(  { & $openLink 'https://github.com/bastienperez/exchange-rbac-manager' })
    $UI.LinkClidsys.Add_MouseLeftButtonDown( { & $openLink 'https://clidsys.com' })

    # Make ToggleButton click-only-go-on (prevent uncheck of active)
    $navBtns = @($UI.NavRoleGroups,$UI.NavRoles,$UI.NavAssignments,$UI.NavScopes,
                 $UI.NavUserRights,$UI.NavCommands,$UI.NavMyCmdlets,$UI.NavVisualizer,$UI.NavAudit)
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
    $UI.NavMyCmdlets.Add_Click({   Switch-View -View 'MyCmdlets' })
    $UI.NavVisualizer.Add_Click({  Switch-View -View 'Visualizer' })
    $UI.NavAudit.Add_Click({
            [System.Windows.MessageBox]::Show(
                'The Audit Log section is not available yet. It will be enabled in a future release.',
                'Coming soon',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information) | Out-Null
            $UI.NavAudit.IsChecked = $false
        })

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
        # Build once per session. The "Loaded" flag (not the list count) gates the
        # retry so an empty/unresolved module result is NOT re-fetched on every
        # keystroke - that repeated Get-Command would re-freeze the UI.
        if ($script:CommandSuggestionsLoaded) { return }
        if (-not (Test-RBACExchangeConnection)) { return }   # retry once connected
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
            # Pre-compute the lowercase form once so the per-keystroke match loop
            # never re-lowercases the whole list.
            $script:CommandSuggestions = @($list | ForEach-Object {
                [pscustomobject]@{ Name = $_; Lower = $_.ToLowerInvariant() }
            })
        }
        catch { $script:CommandSuggestions = @() }
        $script:CommandSuggestionsLoaded = $true
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
        $starts   = [System.Collections.Generic.List[string]]::new()
        $contains = [System.Collections.Generic.List[string]]::new()
        foreach ($item in $script:CommandSuggestions) {
            $low = $item.Lower
            if ($low.StartsWith($needle))    { $null = $starts.Add($item.Name) }
            elseif ($low.Contains($needle))  { $null = $contains.Add($item.Name) }
            if (($starts.Count + $contains.Count) -ge 50) { break }
        }
        $matches = @($starts) + @($contains) | Select-Object -First 30
        if ($matches.Count -eq 0) { $UI.SuggestPopup.IsOpen = $false; return }
        $UI.SuggestList.ItemsSource = $matches
        $UI.SuggestList.SelectedIndex = 0
        $UI.SuggestPopup.IsOpen = $true
    }

    $UI.SearchBox.Add_TextChanged({
        # Typeahead only exists in Command Lookup - debounce its (lazy) build there
        # and do NOTHING on every other view's keystrokes (User Rights included), so
        # typing can never trigger a process before the explicit Lookup/Enter.
        if ($script:CurrentView -eq 'Commands') {
            Schedule-SuggestUpdate
        }
        elseif ($UI.SuggestPopup -and $UI.SuggestPopup.IsOpen) {
            $UI.SuggestPopup.IsOpen = $false
        }
        # Real-time filtering for cache-backed views. Lookup views (UserRights, Commands)
        # need an explicit submit because the query hits Exchange Online.
        $lookupViews = @('UserRights','Commands')
        if ($script:CurrentView -and ($lookupViews -notcontains $script:CurrentView)) {
            Schedule-FilterApply
        }
    })
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
        $UI.FloatingCount.Text = "$n"
        $UI.FloatingActions.Visibility = if ($n -gt 0) { 'Visible' } else { 'Collapsed' }
        if ($n -eq 1) { Show-Details -Item $UI.MainGrid.SelectedItem } else { Hide-Details }
    })
    $UI.BtnDetailsClose.Add_Click({ Hide-Details })
    $UI.BtnDetailsCopy.Add_Click({
        $name = "$($UI.DetailsTitle.Text)"
        if ([string]::IsNullOrEmpty($name)) { return }
        try {
            [System.Windows.Clipboard]::SetText($name)
            Set-Status "Copied '$name' to clipboard." 'ok'
        }
        catch { Set-Status "Copy failed: $($_.Exception.Message)" 'error' }
    })
    $UI.BtnDetailsGoto.Add_Click({
        if ($script:DetailsNavTarget) {
            Navigate-ToEntity -View $script:DetailsNavTarget.View -Name $script:DetailsNavTarget.Name
        }
    })

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
