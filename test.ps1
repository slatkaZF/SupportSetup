Clear-Host # Clear console for clean start
# ===================== Path to configuration file =====================
$ConfigPath = Join-Path $PSScriptRoot "config.json"
# ===================== Simple logging functions =====================
function Write-Info { Write-Host "[INFO] $args" }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }
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
# ===================== Function to create user with GUI =====================
function New-UserWithGUI {
    param ([PSCustomObject]$Config)
    Add-Type -AssemblyName System.Windows.Forms
    do {
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Create User"
        $form.Size = New-Object System.Drawing.Size(350, 250)
        $form.StartPosition = "CenterScreen"
        $form.BackColor = [System.Drawing.Color]::LightGray
        $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

        $labelUsername = New-Object System.Windows.Forms.Label
        $labelUsername.Text = "Username:"
        $labelUsername.Location = New-Object System.Drawing.Point(20, 20)
        $labelUsername.Size = New-Object System.Drawing.Size(80, 20)
        $form.Controls.Add($labelUsername)

        $textBoxUsername = New-Object System.Windows.Forms.TextBox
        $textBoxUsername.Location = New-Object System.Drawing.Point(100, 20)
        $textBoxUsername.Size = New-Object System.Drawing.Size(200, 25)
        $textBoxUsername.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
        $textBoxUsername.BackColor = [System.Drawing.Color]::White
        $form.Controls.Add($textBoxUsername)

        $labelPassword = New-Object System.Windows.Forms.Label
        $labelPassword.Text = "Password:"
        $labelPassword.Location = New-Object System.Drawing.Point(20, 50)
        $labelPassword.Size = New-Object System.Drawing.Size(80, 20)
        $form.Controls.Add($labelPassword)

        $textBoxPassword = New-Object System.Windows.Forms.TextBox
        $textBoxPassword.Location = New-Object System.Drawing.Point(100, 50)
        $textBoxPassword.Size = New-Object System.Drawing.Size(200, 25)
        $textBoxPassword.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
        $textBoxPassword.UseSystemPasswordChar = $true
        $textBoxPassword.BackColor = [System.Drawing.Color]::White
        $form.Controls.Add($textBoxPassword)

        $labelDescription = New-Object System.Windows.Forms.Label
        $labelDescription.Text = "Description:"
        $labelDescription.Location = New-Object System.Drawing.Point(20, 80)
        $labelDescription.Size = New-Object System.Drawing.Size(80, 20)
        $form.Controls.Add($labelDescription)

        $textBoxDescription = New-Object System.Windows.Forms.TextBox
        $textBoxDescription.Location = New-Object System.Drawing.Point(100, 80)
        $textBoxDescription.Size = New-Object System.Drawing.Size(200, 25)
        $textBoxDescription.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
        $textBoxDescription.BackColor = [System.Drawing.Color]::White
        $form.Controls.Add($textBoxDescription)

        $checkBoxAdmin = New-Object System.Windows.Forms.CheckBox
        $checkBoxAdmin.Text = "Admin"
        $checkBoxAdmin.Location = New-Object System.Drawing.Point(100, 110)
        $checkBoxAdmin.Size = New-Object System.Drawing.Size(100, 25)
        $form.Controls.Add($checkBoxAdmin)

        $buttonOK = New-Object System.Windows.Forms.Button
        $buttonOK.Text = "OK"
        $buttonOK.Location = New-Object System.Drawing.Point(100, 150)
        $buttonOK.Size = New-Object System.Drawing.Size(80, 30)
        $buttonOK.BackColor = [System.Drawing.Color]::LightBlue
        $buttonOK.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $form.Controls.Add($buttonOK)

        $buttonCancel = New-Object System.Windows.Forms.Button
        $buttonCancel.Text = "Cancel"
        $buttonCancel.Location = New-Object System.Drawing.Point(200, 150)
        $buttonCancel.Size = New-Object System.Drawing.Size(80, 30)
        $buttonCancel.BackColor = [System.Drawing.Color]::LightCoral
        $buttonCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $form.Controls.Add($buttonCancel)

        $buttonOK.Add_Click({
                if ($textBoxUsername.Text -eq "" -or $textBoxPassword.Text -eq "") {
                    [System.Windows.Forms.MessageBox]::Show("Enter username and password!", "Error")
                }
                else {
                    try {
                        $password = ConvertTo-SecureString $textBoxPassword.Text -AsPlainText -Force
                        New-LocalUser -Name $textBoxUsername.Text -Password $password -Description $textBoxDescription.Text -UserMayNotChangePassword -PasswordNeverExpires -AccountNeverExpires -ErrorAction Stop
                        # Prüfen, ob der Benutzer existiert
                        if (Get-LocalUser -Name $textBoxUsername.Text -ErrorAction SilentlyContinue) {
                            Write-Info "User $($textBoxUsername.Text) successfully created"
                            if ($checkBoxAdmin.Checked) {
                                try {
                                    Add-LocalGroupMember -Group "Administratoren" -Member $textBoxUsername.Text -ErrorAction Stop
                                    Write-Info "User $($textBoxUsername.Text) added to Administrators"
                                }
                                catch {
                                    Write-Err "Failed to add user $($textBoxUsername.Text) to Administrators - $_"
                                }
                            }
                        }
                        else {
                            Write-Err "User $($textBoxUsername.Text) was not created"
                        }
                        $form.Close()
                    }
                    catch {
                        Write-Err "Failed to create user $($textBoxUsername.Text) - $_"
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
    $params = @{
        Name        = 'Support'
        Password    = $password
        Description = 'Support User for administration'
    }
    New-LocalUser @params -UserMayNotChangePassword -PasswordNeverExpires -AccountNeverExpires -ErrorAction Stop
    # Prüfen, ob der Benutzer existiert
    if (Get-LocalUser -Name 'Support' -ErrorAction SilentlyContinue) {
        Write-Info "Support user Support successfully created"
        try {
            Add-LocalGroupMember -Group "Administratoren" -Member "Support" -ErrorAction Stop
            Write-Info "Support user Support added to Administrators"
        }
        catch {
            Write-Err "Failed to add support user Support to Administrators - $_"
        }
    }
    else {
        Write-Err "Support user Support was not created"
    }
}
catch {
    Write-Err "Failed to create support user Support - $_"
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
        if (-not (Test-Path $path)) {
            try {
                New-Item -ItemType Directory -Path $path -Force -ErrorAction Stop | Out-Null
                Write-Info "Verzeichnis erstellt: $path"
            }
            catch {
                Write-Err "Failed to create directory $path - $_"
            }
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
        Write-Info "Kopiere $fileName nach $destination"
        try {
            Copy-Item -Path $source -Destination $destination -Force -ErrorAction Stop
            Write-Info "Erfolg: $fileName kopiert."
            # Ladeleiste kurz schließen, um Fehlermeldungen sichtbar zu machen
            Write-Progress -Activity "Dateien werden kopiert" -Status "Abgeschlossen" -Completed
            try {
                Unblock-File -Path $destinationFile -ErrorAction Stop
                Write-Info "Datei entsperrt: $destinationFile"
            }
            catch {
                Write-Err "Failed to unblock file $destinationFile - $_"
            }
        }
        catch {
            Write-Progress -Activity "Dateien werden kopiert" -Status "Abgeschlossen" -Completed
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
