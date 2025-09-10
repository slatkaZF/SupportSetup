Clear-Host # Clear console for clean start
# ===================== Path to configuration file =====================
$ConfigPath = Join-Path $PSScriptRoot "config.json"
# ===================== Simple logging functions =====================
function Write-Info { Write-Host "[INFO] $args" }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }
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
        [string]$Description,
        [bool]$IsAdmin = $false
    )
    try {
        New-LocalUser -Name $Username -Password $Password -Description $Description -UserMayNotChangePassword -PasswordNeverExpires -AccountNeverExpires -ErrorAction Stop
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
        $form.StartPosition = "CenterScreen"
        $form.Font = New-Object System.Drawing.Font("Segoe UI", 11)
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
        $form.BackColor = [System.Drawing.Color]::FromArgb(0, 87, 183) # ZF Blau as fallback
        # Smooth gradient background
        $form.Add_Paint({
                $rect = $form.ClientRectangle
                $gradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                    $rect,
                    [System.Drawing.Color]::FromArgb(0, 87, 183), # ZF Blau
                    [System.Drawing.Color]::FromArgb(0, 15, 50),  # Softer ZF Schwarzblau
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
        $labelTitle = New-Object System.Windows.Forms.Label
        $labelTitle.Text = "User Creation"
        $labelTitle.Location = New-Object System.Drawing.Point(20, 20)
        $labelTitle.Size = New-Object System.Drawing.Size(440, 30)
        $labelTitle.ForeColor = [System.Drawing.Color]::DarkBlue
        $labelTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
        $labelTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $form.Controls.Add($labelTitle)
        $labelUsername = New-Object System.Windows.Forms.Label
        $labelUsername.Text = "Username:"
        $labelUsername.Location = New-Object System.Drawing.Point(20, 50)
        $labelUsername.Size = New-Object System.Drawing.Size(130, 30)
        $labelUsername.ForeColor = [System.Drawing.Color]::DarkBlue
        $labelUsername.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
        $form.Controls.Add($labelUsername)
        $textBoxUsername = New-Object System.Windows.Forms.TextBox
        $textBoxUsername.Location = New-Object System.Drawing.Point(140, 50)
        $textBoxUsername.Size = New-Object System.Drawing.Size(250, 45)
        $textBoxUsername.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
        $textBoxUsername.BackColor = [System.Drawing.Color]::FromArgb(0, 171, 231) # ZF Cyan
        $textBoxUsername.ForeColor = [System.Drawing.Color]::Black
        $textBoxUsername.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $textBoxUsername.Padding = New-Object System.Windows.Forms.Padding(5, 2, 5, 2) # Fix text visibility
        $form.Controls.Add($textBoxUsername)
        $labelPassword = New-Object System.Windows.Forms.Label
        $labelPassword.Text = "Password:"
        $labelPassword.Location = New-Object System.Drawing.Point(20, 110)
        $labelPassword.Size = New-Object System.Drawing.Size(130, 30)
        $labelPassword.ForeColor = [System.Drawing.Color]::DarkBlue
        $labelPassword.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
        $form.Controls.Add($labelPassword)
        $textBoxPassword = New-Object System.Windows.Forms.TextBox
        $textBoxPassword.Location = New-Object System.Drawing.Point(140, 110)
        $textBoxPassword.Size = New-Object System.Drawing.Size(250, 45)
        $textBoxPassword.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
        $textBoxPassword.UseSystemPasswordChar = $true
        $textBoxPassword.BackColor = [System.Drawing.Color]::FromArgb(0, 171, 231) # ZF Cyan
        $textBoxPassword.ForeColor = [System.Drawing.Color]::Black
        $textBoxPassword.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $textBoxPassword.Padding = New-Object System.Windows.Forms.Padding(5, 2, 5, 2) # Fix text visibility
        $form.Controls.Add($textBoxPassword)
        $labelDescription = New-Object System.Windows.Forms.Label
        $labelDescription.Text = "Description:"
        $labelDescription.Location = New-Object System.Drawing.Point(20, 170)
        $labelDescription.Size = New-Object System.Drawing.Size(130, 30)
        $labelDescription.ForeColor = [System.Drawing.Color]::DarkBlue
        $labelDescription.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
        $form.Controls.Add($labelDescription)
        $textBoxDescription = New-Object System.Windows.Forms.TextBox
        $textBoxDescription.Location = New-Object System.Drawing.Point(140, 170)
        $textBoxDescription.Size = New-Object System.Drawing.Size(250, 45)
        $textBoxDescription.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
        $textBoxDescription.BackColor = [System.Drawing.Color]::FromArgb(0, 171, 231) # ZF Cyan
        $textBoxDescription.ForeColor = [System.Drawing.Color]::Black
        $textBoxDescription.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $textBoxDescription.Padding = New-Object System.Windows.Forms.Padding(5, 2, 5, 2) # Fix text visibility
        $form.Controls.Add($textBoxDescription)
        $checkBoxAdmin = New-Object System.Windows.Forms.CheckBox
        $checkBoxAdmin.Text = "Admin"
        $checkBoxAdmin.Location = New-Object System.Drawing.Point(140, 230)
        $checkBoxAdmin.Size = New-Object System.Drawing.Size(170, 40)
        $checkBoxAdmin.ForeColor = [System.Drawing.Color]::DarkBlue
        $checkBoxAdmin.Font = New-Object System.Drawing.Font("Segoe UI", 14)
        $form.Controls.Add($checkBoxAdmin)
        $buttonOK = New-Object System.Windows.Forms.Button
        $buttonOK.Text = "OK"
        $buttonOK.Location = New-Object System.Drawing.Point(140, 290)
        $buttonOK.Size = New-Object System.Drawing.Size(130, 55)
        $buttonOK.BackColor = [System.Drawing.Color]::FromArgb(0, 87, 183) # ZF Blau
        $buttonOK.ForeColor = [System.Drawing.Color]::White # Changed to White for contrast
        $buttonOK.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $buttonOK.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
        $buttonOK.FlatAppearance.BorderSize = 0
        $buttonOK.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(30, 107, 203) # Lighter ZF Blau
        $form.Controls.Add($buttonOK)
        # Enhanced hover effect with scale
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
        $buttonCancel.Size = New-Object System.Drawing.Size(130, 55)
        $buttonCancel.BackColor = [System.Drawing.Color]::FromArgb(105, 105, 105) # DimGray
        $buttonCancel.ForeColor = [System.Drawing.Color]::White
        $buttonCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $buttonCancel.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
        $buttonCancel.FlatAppearance.BorderSize = 0
        $buttonCancel.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(125, 125, 125)
        $form.Controls.Add($buttonCancel)
        # Enhanced hover effect with scale
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
                        Create-LocalUserAccount -Username $textBoxUsername.Text -Password $password -Description $textBoxDescription.Text -IsAdmin $checkBoxAdmin.Checked
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
# ===================== Create users =====================
# Support user always created
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
    Create-LocalUserAccount -Username 'Support' -Password $password -Description 'Support User for administration' -IsAdmin $true
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
    $totalJobs = $cfg.jobs.Count # Gesamtzahl der Jobs
    $currentJob = 0 # Zähler für aktuelle Jobs
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
        $destinationFile = Join-Path $destination $fileName # Korrekter Pfad für die Zieldatei
        # Prüfen, ob Quelldatei und Zielverzeichnis existieren
        $destinationDir = Split-Path $destinationFile -Parent
        if (-not (Test-Path $source)) {
            Write-Err "Source file does not exist: $source"
            continue
        }
        if (-not (Test-Path $destinationDir)) {
            Write-Err "Destination directory does not exist: $destinationDir"
            continue
        }
        Write-Info "Kopiere $fileName nach $destination"
        try {
            Copy-Item -Path $source -Destination $destination -Force -ErrorAction Stop
            Write-Info "Erfolg: $fileName kopiert."
            try {
                Unblock-File -Path $destinationFile -ErrorAction Stop
                Write-Info "Datei entsperrt: $destinationFile"
            }
            catch {
                Write-Err "Failed to unblock file $destinationFile - $_"
            }
        }
        catch {
            Write-Err "Failed to copy file $fileName - $_"
        }
        # Optional: Kleine Pause für sichtbaren Fortschritt (entfernen in Produktion, wenn nicht nötig)
        Start-Sleep -Milliseconds 100
    }
    # Progressbalken endgültig schließen
    Write-Progress -Activity "Dateien werden kopiert" -Status "Abgeschlossen" -Completed
}
# ===================== Cleanup =====================
if ($cfg.features.enableTranscriptLogging) {
    Stop-Transcript | Out-Null
}
Write-Info "Skript abgeschlossen."
