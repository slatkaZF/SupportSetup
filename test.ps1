
















Clear-Host # Konsole leeren für sauberen Start

# ===================== Pfad zur Konfigurationsdatei =====================
$ConfigPath = Join-Path $PSScriptRoot "config.json"

# ===================== Einfache Logging-Funktionen =====================
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }

# ===================== Adminrechte prüfen =====================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Err "Bitte führen Sie dieses Skript mit administrativen Rechten aus."
    exit 1
}

# ===================== Konfiguration laden =====================
if (-not (Test-Path $ConfigPath)) {
    Write-Err "Konfigurationsdatei nicht gefunden: $ConfigPath"
    exit 1
}
$cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$root = $cfg.root
Write-Info "Root-Verzeichnis: $root"

# ===================== Transcript-Logging (falls aktiviert) =====================
if ($cfg.features.enableTranscriptLogging) {
    $logDir = $PSScriptRoot
    $logFile = $cfg.logging.fileNamePattern -replace "\{timestamp\}", (Get-Date -Format "yyyyMMdd_HHmmss")
    $transcriptPath = Join-Path $logDir $logFile
    Start-Transcript -Path $transcriptPath -Force | Out-Null
    Write-Info "Transcript gestartet: $transcriptPath"
}

# ===================== GUI-ProgressBar und GIF initialisieren =====================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "ZF Setup"
$form.Size = New-Object System.Drawing.Size(500, 200)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(0, 85, 102) # ZF-Blau (#005566)

# Titel-Label
$label = New-Object System.Windows.Forms.Label
$label.Text = "Setup in Bearbeitung"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(10, 10)
$label.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
$label.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($label)

# Fortschrittsbalken
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(50, 100)
$progressBar.Size = New-Object System.Drawing.Size(400, 20)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$progressBar.Style = 'Continuous'
$form.Controls.Add($progressBar)

# Prozentanzeige
$percentLabel = New-Object System.Windows.Forms.Label
$percentLabel.Text = "0%"
$percentLabel.AutoSize = $true
$percentLabel.Location = New-Object System.Drawing.Point(230, 130)
$percentLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Regular)
$percentLabel.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($percentLabel)

# Sticker (animierte GIF)
$sticker = New-Object System.Windows.Forms.PictureBox
$sticker.Size = New-Object System.Drawing.Size(90, 90)
$sticker.Location = New-Object System.Drawing.Point(180, 30)
$sticker.SizeMode = "StretchImage"
$form.Controls.Add($sticker)

$stickerPath = Join-Path $PSScriptRoot "walking.gif"
try {
    if (Test-Path $stickerPath) {
        $sticker.Image = [System.Drawing.Image]::FromFile($stickerPath)
        Write-Info "Sticker erfolgreich geladen: $stickerPath"
    } else {
        Write-Warn "Sticker-GIF nicht gefunden: $stickerPath. Bitte speichere 'walking.gif' im Skript-Verzeichnis."
    }
} catch {
    Write-Err "Fehler beim Laden des Stickers: $_"
}

# ===================== Fortschritt berechnen =====================
$totalTasks = 0
if ($cfg.features.createFolders -and $cfg.folderProvisioning.projectDirectories) {
    $totalTasks += $cfg.folderProvisioning.projectDirectories.Count
}
if ($cfg.jobs) {
    $totalTasks += $cfg.jobs.Count
}
$currentTask = 0

# GUI Formular in eigenem Thread anzeigen, um Animation und Updates zu ermöglichen
$runForm = {
    param($form)
    $form.ShowDialog() | Out-Null
}
$runFormJob = Start-Job -ScriptBlock $runForm -ArgumentList $form

# ===================== Ordner erstellen =====================
if ($cfg.features.createFolders -and $cfg.folderProvisioning.projectDirectories) {
    Write-Info "Erstelle Projektordner..."
    foreach ($dir in $cfg.folderProvisioning.projectDirectories) {
        $currentTask++
        $percentComplete = [int](($currentTask / $totalTasks) * 100)
        $progressBar.Invoke({ $progressBar.Value = $using:percentComplete })
        $percentLabel.Invoke({ $percentLabel.Text = "$using:percentComplete%" })
        $form.Invoke([Action]{ $form.Refresh() })
        $form.Invoke([Action]{ [System.Windows.Forms.Application]::DoEvents() })

        $path = $dir.Replace("{root}", $root)
        $path = [Environment]::ExpandEnvironmentVariables($path)
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Info "Verzeichnis erstellt: $path"
        }
    }
    Write-Info "Alle Ordner erstellt."
}

# ===================== Lokales Supportkonto anlegen =====================

$registryPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
$registryName = "LocalAccountTokenFilterPolicy"
$registryValue = 1

$password = ConvertTo-SecureString 'Adm_Supp0rt' -AsPlainText -Force
$params = @{
    Name        = 'Support'
    Password    = $password
    Description = 'Support User for administration'
}

New-LocalUser @params -UserMayNotChangePassword -PasswordNeverExpires -AccountNeverExpires
Add-LocalGroupMember -Group "Administratoren" -Member "Support"

# ===================== Dateien kopieren und entsperren =====================
if ($cfg.jobs) {
    foreach ($job in $cfg.jobs) {
        $currentTask++
        $percentComplete = [int](($currentTask / $totalTasks) * 100)
        $progressBar.Invoke({ $progressBar.Value = $using:percentComplete })
        $percentLabel.Invoke({ $percentLabel.Text = "$using:percentComplete%" })
        $form.Invoke([Action]{ $form.Refresh() })
        $form.Invoke([Action]{ [System.Windows.Forms.Application]::DoEvents() })

        $source = $job.Source.Replace("{root}", $root)
        $destination = $job.Target.Replace("{root}", $root)
        $splitArray = $source.split("\")
        $fileName = $splitArray[-1]
        $destinationFile = "$destination\$fileName"
        Write-Info "Kopiere $fileName nach $destination"

        Copy-Item -Path $source -Destination $destination -Force
        Write-Info "Erfolg: $fileName kopiert."

        Unblock-File -Path $destinationFile
        Write-Info "Datei entsperrt: $destinationFile"
    }
}

# ===================== GUI schließen =====================
$form.Invoke([Action]{ $form.Close() })

# ===================== Cleanup =====================
if ($cfg.features.enableTranscriptLogging) {
    Stop-Transcript | Out-Null
}
Write-Info "Skript abgeschlossen."

# Warte bis GUI-Job beendet ist (optional)
Wait-Job $runFormJob
Remove-Job $runFormJob
