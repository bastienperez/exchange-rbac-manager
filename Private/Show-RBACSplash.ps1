function Show-RBACSplash {
    <#
    .SYNOPSIS
        Displays a small splash window with an indeterminate progress bar.
    .DESCRIPTION
        The splash runs in its own STA runspace so its UI keeps animating while
        the caller's thread is busy building the main window or importing modules.

        Returns an object exposing:
            .Update($message)  - update the status line (thread-safe)
            .Close()           - dismiss the splash and dispose the runspace
    #>
    [CmdletBinding()]
    param(
        [string]$InitialMessage = 'Loading…',
        [string]$Title          = 'Exchange RBAC Manager',
        [string]$Subtitle       = '',
        [string]$Version        = ''
    )

    Add-Type -AssemblyName PresentationFramework

    $sync = [hashtable]::Synchronized(@{
        Window  = $null
        Status  = $null
        Ready   = $false
        Closed  = $false
    })

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = 'STA'
    $runspace.ThreadOptions  = 'ReuseThread'
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('sync',           $sync)
    $runspace.SessionStateProxy.SetVariable('initialMessage', $InitialMessage)
    $runspace.SessionStateProxy.SetVariable('titleText',      $Title)
    $runspace.SessionStateProxy.SetVariable('subtitleText',   $Subtitle)
    $runspace.SessionStateProxy.SetVariable('versionText',    $Version)

    $ps = [powershell]::Create()
    $ps.Runspace = $runspace
    [void]$ps.AddScript({
        Add-Type -AssemblyName PresentationFramework

        $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        WindowStartupLocation="CenterScreen" Width="440" Height="210"
        ShowInTaskbar="False" Topmost="True" SizeToContent="Manual">
  <Border Background="#0078D4" CornerRadius="8" Padding="24">
    <Border.Effect>
      <DropShadowEffect BlurRadius="20" ShadowDepth="2" Opacity="0.35" Color="Black"/>
    </Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <StackPanel Grid.Row="0">
        <TextBlock x:Name="TitleText" Foreground="White" FontFamily="Segoe UI"
                   FontSize="20" FontWeight="SemiBold"/>
        <TextBlock x:Name="SubtitleText" Foreground="#DEECF9" FontFamily="Segoe UI"
                   FontSize="12" Margin="0,2,0,0"/>
      </StackPanel>
      <TextBlock x:Name="StatusText" Grid.Row="2" Foreground="White" FontFamily="Segoe UI"
                 FontSize="12" Margin="0,0,0,8" TextWrapping="Wrap"/>
      <ProgressBar Grid.Row="3" IsIndeterminate="True" Height="6" Foreground="White"
                   Background="#106EBE" BorderThickness="0"/>
      <TextBlock x:Name="VersionText" Grid.Row="0" Foreground="White" Opacity="0.65"
                 FontFamily="Consolas" FontSize="11"
                 HorizontalAlignment="Right" VerticalAlignment="Top"/>
      <TextBlock Grid.Row="2" Text="by Clidsys - Bastien Perez" Foreground="White" Opacity="0.65"
                 FontFamily="Segoe UI" FontSize="10"
                 HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,0,8"/>
    </Grid>
  </Border>
</Window>
'@

        $reader  = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
        $window  = [System.Windows.Markup.XamlReader]::Load($reader)
        $window.FindName('TitleText').Text = $titleText
        $subtitleBlock = $window.FindName('SubtitleText')
        if ([string]::IsNullOrWhiteSpace($subtitleText)) {
            $subtitleBlock.Visibility = 'Collapsed'
        }
        else {
            $subtitleBlock.Text = $subtitleText
        }
        $window.FindName('VersionText').Text = $versionText
        $status = $window.FindName('StatusText')
        $status.Text = $initialMessage

        $sync.Window = $window
        $sync.Status = $status
        $sync.Ready  = $true

        [void]$window.ShowDialog()
        $sync.Closed = $true
    })

    $async = $ps.BeginInvoke()

    # Wait until the splash window has been built (avoid race on first .Update call).
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $sync.Ready -and $sw.ElapsedMilliseconds -lt 3000) {
        Start-Sleep -Milliseconds 25
    }

    $handle = [pscustomobject]@{
        _Sync       = $sync
        _Powershell = $ps
        _Async      = $async
        _Runspace   = $runspace
    }

    $handle | Add-Member -MemberType ScriptMethod -Name Update -Value {
        param([string]$Message)
        if (-not $this._Sync.Status -or $this._Sync.Closed) { return }
        $status = $this._Sync.Status
        $msg    = $Message
        try {
            $status.Dispatcher.Invoke([action]{ $status.Text = $msg })
        }
        catch { }
    }

    $handle | Add-Member -MemberType ScriptMethod -Name Close -Value {
        if ($this._Sync.Closed) { return }
        if ($this._Sync.Window) {
            try {
                $win = $this._Sync.Window
                $win.Dispatcher.Invoke([action]{ $win.Close() })
            }
            catch { }
        }
        try { [void]$this._Powershell.EndInvoke($this._Async) } catch { }
        try { $this._Powershell.Dispose() } catch { }
        try { $this._Runspace.Close(); $this._Runspace.Dispose() } catch { }
    }

    return $handle
}
