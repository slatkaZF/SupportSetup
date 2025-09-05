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
# ===================== GUI-ProgressBar initialisieren =====================
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
$label.Text = "ZF Setup in Bearbeitung"
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
$progressBar.BackColor = [System.Drawing.Color]::White
$progressBar.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 255) # Neon-Blau (#00FFFF)
$form.Controls.Add($progressBar)

# Prozentanzeige
$percentLabel = New-Object System.Windows.Forms.Label
$percentLabel.Text = "0%"
$percentLabel.AutoSize = $true
$percentLabel.Location = New-Object System.Drawing.Point(230, 130)
$percentLabel.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Regular)
$percentLabel.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($percentLabel)

# Animation (Platzhalter für GIF)
$animation = New-Object System.Windows.Forms.PictureBox
$animation.Size = New-Object System.Drawing.Size(50, 50)
$animation.Location = New-Object System.Drawing.Point(200, 50) # Zentriert über dem Balken für bessere Sichtbarkeit
$animation.SizeMode = "StretchImage"
# Versuche lokale GIF, fallback auf Platzhalter-URL
$gifPath = Join-Path $PSScriptRoot "coffee_animation.gif"
try {
    if (Test-Path $gifPath) {
        $animation.Image = [System.Drawing.Image]::FromFile($gifPath)
        Write-Info "Lokale GIF geladen: $gifPath"
    } else {
        # Verbesserte Platzhalter-URL (animierte Kaffeetasse mit Rauch und Person-ähnlicher Darstellung; ersetze durch deine eigene)
        $animation.Load("https://media.giphy.com/media/l2JhrYY3S51V7N71S/giphy.gif") # Beispiel: Person mit Kaffeetasse
        Write-Warn "Lokale GIF nicht gefunden: $gifPath. Verwende Platzhalter-URL. Stelle sicher, dass Internet verfügbar ist."
    }
} catch {
    Write-Err "Fehler beim Laden der GIF: $_. Überprüfe den Pfad oder die URL."
}
$form.Controls.Add($animation)

$form.Show()
# ===================== Fortschritt berechnen =====================
$totalTasks = 0
if ($cfg.features.createFolders -and $cfg.folderProvisioning.projectDirectories) {
    $totalTasks += $cfg.folderProvisioning.projectDirectories.Count
}
if ($cfg.jobs) {
    $totalTasks += $cfg.jobs.Count
}
$currentTask = 0
# ===================== Ordner erstellen =====================
if ($cfg.features.createFolders -and $cfg.folderProvisioning.projectDirectories) {
    Write-Info "Erstelle Projektordner..."
    foreach ($dir in $cfg.folderProvisioning.projectDirectories) {
        $currentTask++
        $percentComplete = [int](($currentTask / $totalTasks) * 100)
        $progressBar.Value = $percentComplete
        $percentLabel.Text = "$percentComplete%"
        $form.Refresh()
        $path = $dir.Replace("{root}", $root)
        $path = [Environment]::ExpandEnvironmentVariables($path)
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Info "Verzeichnis erstellt: $path"
        }
    }
    Write-Info "Alle Ordner erstellt."
}
# ===================== Sicherheitsrichtlinien setzen =====================
# (Dieser Abschnitt bleibt unverändert, da er auskommentiert ist)
# ===================== Lokales Supportkonto anlegen =====================
# Variables for the registry change
$registryPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
$registryName = "LocalAccountTokenFilterPolicy"
$registryValue = 1
# Params for the new user
$password = ConvertTo-SecureString 'Adm_Supp0rt' -AsPlainText -Force
$params = @{
    Name        = 'Support'
    Password    = $password
    Description = 'Support User for administration'
}
# Add new local "Support" user
New-LocalUser @params -UserMayNotChangePassword -PasswordNeverExpires -AccountNeverExpires
# Add the "Support" user to the "Administrators" group
Add-LocalGroupMember -Group "Administratoren" -Member "Support"
# ===================== Dateien kopieren und entsperren =====================
if ($cfg.jobs) {
    foreach ($job in $cfg.jobs) {
        $currentTask++
        $percentComplete = [int](($currentTask / $totalTasks) * 100)
        $progressBar.Value = $percentComplete
        $percentLabel.Text = "$percentComplete%"
        $form.Refresh()
        $source = $job.Source.Replace("{root}", $root)
        $destination = $job.Target.Replace("{root}", $root)
        $splitArray = $source.split("\\")
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
$form.Close()
# ===================== Cleanup =====================
if ($cfg.features.enableTranscriptLogging) {
    Stop-Transcript | Out-Null
}
Write-Info "Skript abgeschlossen."
