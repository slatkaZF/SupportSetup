Clear-Host # Clear console for clean start
# Entsperre das aktuelle Skript, falls es blockiert ist
$scriptPath = $PSCommandPath
if (Test-Path $scriptPath) {
    Unblock-File -Path $scriptPath -ErrorAction SilentlyContinue
}
# ===================== Simple logging functions =====================
function Write-Info { Write-Host "[INFO] $args" }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }
# ===================== Path to configuration file =====================
$ConfigPath = Join-Path $PSScriptRoot "config.json"
# ===================== Function to get localized group names =====================
function Get-LocalGroupName {
    param ([string]$GroupType)
    $culture = Get-Culture
    if ($culture.Name -like "de-*") {
        if ($GroupType -eq "Users") { return "Benutzer" }
        if ($GroupType -eq "Administrators") { return "Administratoren" }
    }
    else {
        if ($GroupType -eq "Users") { return "Users" }
        if ($GroupType -eq "Administrators") { return "Administrators" }
    }
}
# ===================== Cache group names =====================
$UsersGroup = Get-LocalGroupName -GroupType "Users"
$AdminsGroup = Get-LocalGroupName -GroupType "Administrators"
# ===================== Check for admin rights =====================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Err "Please run this script with administrative privileges."
    exit 1
}
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
# ===================== Load configuration =====================
if (-not (Test-Path $ConfigPath)) {
    Write-Err "Configuration file not found: $ConfigPath"
    exit 1
}
$cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$root = $cfg.root
Write-Info "Root directory: $root"
# ===================== Transcript logging (if enabled) =====================
if ($cfg.features.enableTranscriptLogging) {
    $logDir = $PSScriptRoot
    $logFile = $cfg.logging.fileNamePattern -replace "\{timestamp\}", (Get-Date -Format "yyyyMMdd_HHmmss")
    $transcriptPath = Join-Path $logDir $logFile
    Start-Transcript -Path $transcriptPath -Force | Out-Null
    Write-Info "Transcript started: $transcriptPath"
}
# ===================== Centralized function to create local user =====================
function Create-LocalUserAccount {
    param (
        [string]$Username,
        [SecureString]$Password,
        [bool]$IsAdmin = $false
    )
    try {
        New-LocalUser -Name $Username -Password $Password -UserMayNotChangePassword -PasswordNeverExpires -AccountNeverExpires -ErrorAction Stop
        Write-Info "User $Username successfully created"
        Add-LocalGroupMember -Group $UsersGroup -Member $Username -ErrorAction Stop
        Write-Info "User $Username added to $UsersGroup"
        if ($IsAdmin) {
            Add-LocalGroupMember -Group $AdminsGroup -Member $Username -ErrorAction Stop
            Write-Info "User $Username added to $AdminsGroup"
        }
    }
    catch {
        Write-Err "Failed to create user $Username - $_"
        throw
    }
}
# ===================== Function to create user with GUI =====================
function New-UserWithGUI {
    param ([PSCustomObject]$Config)
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    do {
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Create User"
        $form.Size = New-Object System.Drawing.Size(480, 400)
        $form.StartPosition = "WindowsDefaultLocation"
        $form.Font = New-Object System.Drawing.Font("Segoe UI", 11)
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
        $form.Icon = New-Object System.Drawing.Icon((Join-Path $PSScriptRoot "zf.ico"))
        $form.BackColor = [System.Drawing.Color]::FromArgb(0, 87, 183) # ZF Blau as fallback
        # Smooth gradient background
        $form.Add_Paint({
            $rect = $form.ClientRectangle
            $gradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                $rect,
                [System.Drawing.Color]::FromArgb(0, 87, 183), # ZF Blau
                [System.Drawing.Color]::FromArgb(0, 15, 50), # Softer ZF Schwarzblau
                90 # Vertical gradient
            )
            $_.Graphics.FillRectangle($gradientBrush, $rect)
            $gradientBrush.Dispose()
        })
        # Smooth fade-in effect
        $form.Opacity = 0
        $form.Add_Shown({
            $opacity = 0
            while ($opacity -lt 1) {
                $form.Opacity = $opacity
                $opacity += 0.05
                Start-Sleep -Milliseconds 50
            }
            $form.Opacity = 1
        })
        $labelUsername = New-Object System.Windows.Forms.Label
        $labelUsername.Text = "Username:"
        $labelUsername.BackColor = [System.Drawing.Color]::Transparent
        $labelUsername.Location = New-Object System.Drawing.Point(20, 50)
        $labelUsername.Size = New-Object System.Drawing.Size(130, 30)
        $labelUsername.ForeColor = [System.Drawing.Color]::WhiteSmoke
        $labelUsername.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $form.Controls.Add($labelUsername)
        $textBoxUsername = New-Object System.Windows.Forms.TextBox
        $textBoxUsername.Location = New-Object System.Drawing.Point(160, 50)
        $textBoxUsername.Size = New-Object System.Drawing.Size(200, 25)
        $textBoxUsername.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
        $textBoxUsername.BackColor = [System.Drawing.Color]::White
        $textBoxUsername.ForeColor = [System.Drawing.Color]::Black
        $textBoxUsername.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
        $textBoxUsername.Padding = New-Object System.Windows.Forms.Padding(5, 2, 5, 2)
        $textBoxUsername.MaxLength = 21
        $form.Controls.Add($textBoxUsername)
        $labelPassword = New-Object System.Windows.Forms.Label
        $labelPassword.Text = "Password:"
        $labelPassword.BackColor = [System.Drawing.Color]::Transparent
        $labelPassword.Location = New-Object System.Drawing.Point(20, 110)
        $labelPassword.Size = New-Object System.Drawing.Size(130, 30)
        $labelPassword.ForeColor = [System.Drawing.Color]::WhiteSmoke
        $labelPassword.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $form.Controls.Add($labelPassword)
        $textBoxPassword = New-Object System.Windows.Forms.TextBox
        $textBoxPassword.Location = New-Object System.Drawing.Point(160, 110)
        $textBoxPassword.Size = New-Object System.Drawing.Size(200, 25)
        $textBoxPassword.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
        $textBoxPassword.UseSystemPasswordChar = $true
        $textBoxPassword.BackColor = [System.Drawing.Color]::White
        $textBoxPassword.ForeColor = [System.Drawing.Color]::Black
        $textBoxPassword.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
        $textBoxPassword.Padding = New-Object System.Windows.Forms.Padding(5, 2, 5, 2)
        $textBoxPassword.MaxLength = 50
        $form.Controls.Add($textBoxPassword)
        $buttonShowPassword = New-Object System.Windows.Forms.Button
        $buttonShowPassword.Text = "show"
        $buttonShowPassword.Location = New-Object System.Drawing.Point(360, 110)
        $buttonShowPassword.Size = New-Object System.Drawing.Size(50, 20)
        $buttonShowPassword.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        $buttonShowPassword.BackColor = [System.Drawing.Color]::FromArgb(0, 87, 183)
        $buttonShowPassword.ForeColor = [System.Drawing.Color]::Black
        $buttonShowPassword.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $buttonShowPassword.FlatAppearance.BorderSize = 0
        $form.Controls.Add($buttonShowPassword)
        $buttonShowPassword.Add_Click({
            if ($textBoxPassword.UseSystemPasswordChar) {
                $textBoxPassword.UseSystemPasswordChar = $false
                $buttonShowPassword.Text = "hide"
            }
            else {
                $textBoxPassword.UseSystemPasswordChar = $true
                $buttonShowPassword.Text = "show"
            }
        })
        $labelLocation = New-Object System.Windows.Forms.Label
        $labelLocation.Text = "Location:"
        $labelLocation.BackColor = [System.Drawing.Color]::Transparent
        $labelLocation.Location = New-Object System.Drawing.Point(20, 170)
        $labelLocation.Size = New-Object System.Drawing.Size(130, 30)
        $labelLocation.ForeColor = [System.Drawing.Color]::WhiteSmoke
        $labelLocation.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $form.Controls.Add($labelLocation)
        $textBoxLocation = New-Object System.Windows.Forms.TextBox
        $textBoxLocation.Location = New-Object System.Drawing.Point(160, 170)
        $textBoxLocation.Size = New-Object System.Drawing.Size(200, 25)
        $textBoxLocation.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
        $textBoxLocation.BackColor = [System.Drawing.Color]::White
        $textBoxLocation.ForeColor = [System.Drawing.Color]::Black
        $textBoxLocation.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
        $textBoxLocation.Padding = New-Object System.Windows.Forms.Padding(0, 2, 2, 2)
        $textBoxLocation.MaxLength = 21
        $form.Controls.Add($textBoxLocation)
        $checkBoxAdmin = New-Object System.Windows.Forms.CheckBox
        $checkBoxAdmin.Text = "Admin"
        $checkBoxAdmin.BackColor = [System.Drawing.Color]::Transparent
        $checkBoxAdmin.Location = New-Object System.Drawing.Point(140, 230)
        $checkBoxAdmin.Size = New-Object System.Drawing.Size(170, 40)
        $checkBoxAdmin.ForeColor = [System.Drawing.Color]::WhiteSmoke
        $checkBoxAdmin.Font = New-Object System.Drawing.Font("Segoe UI", 12)
        $form.Controls.Add($checkBoxAdmin)
        $buttonOK = New-Object System.Windows.Forms.Button
        $buttonOK.Text = "OK"
        $buttonOK.Location = New-Object System.Drawing.Point(140, 290)
        $buttonOK.Size = New-Object System.Drawing.Size(100, 35)
        $buttonOK.BackColor = [System.Drawing.Color]::FromArgb(0, 87, 183)
        $buttonOK.ForeColor = [System.Drawing.Color]::White
        $buttonOK.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $buttonOK.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $buttonOK.FlatAppearance.BorderSize = 0
        $buttonOK.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(30, 107, 203)
        $form.Controls.Add($buttonOK)
        $buttonOK.Add_MouseEnter({
            $buttonOK.BackColor = [System.Drawing.Color]::FromArgb(30, 107, 203)
            $buttonOK.Padding = New-Object System.Windows.Forms.Padding(3)
        })
        $buttonOK.Add_MouseLeave({
            $buttonOK.BackColor = [System.Drawing.Color]::FromArgb(0, 87, 183)
            $buttonOK.Padding = New-Object System.Windows.Forms.Padding(0)
        })
        $buttonCancel = New-Object System.Windows.Forms.Button
        $buttonCancel.Text = "Cancel"
        $buttonCancel.Location = New-Object System.Drawing.Point(280, 290)
        $buttonCancel.Size = New-Object System.Drawing.Size(100, 35)
        $buttonCancel.BackColor = [System.Drawing.Color]::FromArgb(105, 105, 105)
        $buttonCancel.ForeColor = [System.Drawing.Color]::White
        $buttonCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $buttonCancel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $buttonCancel.FlatAppearance.BorderSize = 0
        $buttonCancel.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(125, 125, 125)
        $form.Controls.Add($buttonCancel)
        $buttonCancel.Add_MouseEnter({
            $buttonCancel.BackColor = [System.Drawing.Color]::FromArgb(125, 125, 125)
            $buttonCancel.Padding = New-Object System.Windows.Forms.Padding(3)
        })
        $buttonCancel.Add_MouseLeave({
            $buttonCancel.BackColor = [System.Drawing.Color]::FromArgb(105, 105, 105)
            $buttonCancel.Padding = New-Object System.Windows.Forms.Padding(0)
        })
        $buttonOK.Add_Click({
            if ($textBoxUsername.Text -eq "" -or $textBoxPassword.Text -eq "") {
                [System.Windows.Forms.MessageBox]::Show("Enter username and password!", "Error")
            }
            else {
                try {
                    $password = ConvertTo-SecureString $textBoxPassword.Text -AsPlainText -Force
                    Create-LocalUserAccount -Username $textBoxUsername.Text -Password $password -IsAdmin $checkBoxAdmin.Checked
                    # === KONFIGURATION ===
                    $Username = $textBoxUsername.Text
                    $Password = $textBoxPassword.Text
                    $Domain = "."
                    # === REGISTRY-PFAD ===
                    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
                    # === EINTRÄGE SETZEN ===
                    Set-ItemProperty -Path $RegPath -Name "AutoAdminLogon" -Value "1" -Type String
                    Set-ItemProperty -Path $RegPath -Name "DefaultUsername" -Value $Username -Type String
                    Set-ItemProperty -Path $RegPath -Name "DefaultPassword" -Value $Password -Type String
                    Set-ItemProperty -Path $RegPath -Name "DefaultDomainName" -Value $Domain -Type String
                    Write-Host "Automatische Anmeldung für Benutzer '$Username' wurde eingerichtet."
                    Set-SnmpSettings -location $textBoxLocation.Text
                    $form.Close()
                }
                catch {
                    [System.Windows.Forms.MessageBox]::Show("Failed to create user: $_", "Error")
                }
            }
        })
        $buttonCancel.Add_Click({ $form.Close() })
        $form.ShowDialog() | Out-Null
    } while ([System.Windows.Forms.MessageBox]::Show("Create another user?", "Question", [System.Windows.Forms.MessageBoxButtons]::YesNo) -eq "Yes")
}
# ===================== Function to unblock files =====================
function Unblock-Files {
    param ([string]$Path)
    Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Unblock-File
}
# ===================== Function to set SNMP settings =====================
function Set-SnmpSettings {
    param (
        [string]$location
    )
    #variables
    $mails_snmp = @("andreas.fuerst@zf.com")
    $communitystr = "public"
    $OMaddress = "SCWV0005"

    #Check If SNMP Services are already installed
    $check = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq "SNMP" }
    if ($check.State -ne "Enabled") {
        #Install/Enable SNMP Services
        Write-Host "SNMP not installed - trying to install SNMP..."
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName "SNMP"
        }
        catch {
            Add-WindowsCapability -Online -Name "SNMP.Client~~~~0.0.1.0"
        }
    }

    #Select all agent services for SNMP
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\RFC1156Agent\' 
    Set-ItemProperty -Path $path -Name "sysServices" -Value 79

    #Set agent contact
    $path = 'HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\RFC1156Agent'
    Set-ItemProperty -Path $path -Name "sysContact" -Value $mails_snmp

    #Set agent location
    $path = 'HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\RFC1156Agent'
    Set-ItemProperty -Path $path -Name "sysLocation" -Value $location

    #Set to accept packets from IP-Address of OM
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers' -Name "2" -Value $OMaddress

    #Set public key
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities' -Name $communitystr -Value 4

    #Restart SNMP
    Restart-Service -Name SNMP
}
# ===================== Create users =====================
$registryPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
$registryName = "LocalAccountTokenFilterPolicy"
$registryValue = 1
try {
    Set-ItemProperty -Path $registryPath -Name $registryName -Value $registryValue -Force -ErrorAction Stop
    Write-Info "Registry set: $registryName"
}
catch {
    Write-Err "Failed to set registry $registryName - $_"
}
try {
    $password = ConvertTo-SecureString 'Adm_Supp0rt' -AsPlainText -Force
    Create-LocalUserAccount -Username 'Support' -Password $password -IsAdmin $true
}
catch {
    Write-Err "Failed to create Support user - $_"
}
# Optional additional users via GUI
if ($cfg.features.createNormalUser) {
    New-UserWithGUI -Config $cfg
}
# ===================== Ordner erstellen =====================
if ($cfg.features.createFolders -and $cfg.folderProvisioning.projectDirectories) {
    Write-Info "Erstelle Projektordner..."
    foreach ($dir in $cfg.folderProvisioning.projectDirectories) {
        $path = $dir.Replace("{root}", $root)
        $path = [Environment]::ExpandEnvironmentVariables($path)
        try {
            New-Item -ItemType Directory -Path $path -Force -ErrorAction Stop | Out-Null
            Write-Info "Verzeichnis erstellt: $path"
        }
        catch {
            Write-Err "Failed to create directory $path - $_"
        }
    }
    Write-Info "Alle Ordner erstellt."
}
# ===================== Dateien kopieren und entsperren =====================
if ($cfg.jobs) {
    $totalJobs = $cfg.jobs.Count  # Gesamtzahl der Jobs
    $currentJob = 0  # Zähler für aktuelle Jobs

    foreach ($job in $cfg.jobs) {
        # Fortschrittsberechnung
        $currentJob++
        $percentComplete = ($currentJob / $totalJobs) * 100

        # Progressbalken anzeigen
        Write-Progress -Activity "Dateien werden kopiert" -Status "Verarbeite Job $currentJob von $totalJobs" -PercentComplete $percentComplete

        $source = $job.Source.Replace("{root}", $root)
        $destination = $job.Target.Replace("{root}", $root)
        $splitArray = $source.Split("\")
        $fileName = $splitArray[-1]
        $destinationFile = Join-Path $destination $fileName  # Korrekter Pfad für die Zieldatei

        Write-Info "Kopiere $fileName nach $destination"
        try {
            Copy-Item -Path $source -Destination $destination -Force -ErrorAction Stop
            Write-Info "Erfolg: $fileName kopiert."
        } catch {
            Write-Err "Fehler beim Kopieren von $fileName : $_"
        }

        # Datei entsperren
        try {
            Unblock-File -Path $destinationFile -ErrorAction Stop
            Write-Info "Datei entsperrt: $destinationFile"
        } catch {
            Write-Err "Fehler beim Entsperren von $destinationFile : $_"
        }

        # Optional: Kleine Pause für sichtbaren Fortschritt (entfernen in Produktion, wenn nicht nötig)
        #Start-Sleep -Milliseconds 100
    }

    # Progressbalken schließen
    Write-Progress -Activity "Dateien werden kopiert" -Status "Abgeschlossen" -Completed
    # Windows 10 Eigenschaftsfenster 
    reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve
}
# ===================== Cleanup =====================
if ($cfg.features.enableTranscriptLogging) {
    Stop-Transcript | Out-Null
}
Write-Info "Skript abgeschlossen."

#NEUSTART
shutdown /r /t 5
