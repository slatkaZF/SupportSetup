Clear-Host # Konsole leeren für sauberen Start
# ===================== Pfad zur Konfigurationsdatei =====================
$ConfigPath = Join-Path $PSScriptRoot "config.json"
# ===================== Einfache Logging-Funktionen =====================
function Write-Info { Write-Host "[INFO] $args" }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }
# ===================== Adminrechte prüfen =====================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Err "Bitte führen Sie dieses Skript mit administrativen Rechten aus."
    exit 1
}
# ===================== Fortschrittsbalken initialisieren =====================
Write-Info "Lade Konfiguration für Fortschrittsberechnung..."
$cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$totalTasks = 1 + # Konfigurationsladen
              $cfg.folderProvisioning.projectDirectories.Count + # Ordnererstellung
              2 + # Benutzererstellung (Benutzer anlegen + Gruppe hinzufügen)
              (2 * $cfg.jobs.Count) + # Dateikopieren + Entsperren pro Job
              2 # Transcript Start/Stop
$currentTask = 0
$barLength = 20
$cat = "^.^>"
$catPosition = 0

# Funktion zum Aktualisieren des Fortschrittsbalkens
function Update-Progress {
    param($Status)
    $script:currentTask++
    $percent = [math]::Round(($currentTask / $totalTasks) * 100, 2)
    $script:catPosition = [math]::Round($percent / 100 * ($barLength - 1))  # Position der Katze (0 bis 19)
    $bar = "-" * $barLength  # Virtueller Balken (z. B. "-----------------")
    $display = $bar.ToCharArray()
    $display[$catPosition] = $cat  # Setze die Katze an die Position
    $animatedStatus = "$([string]::Join("", $display)) $Status ($percent% abgeschlossen)"
    Write-Progress -Activity "Lade Skript..." -Status $animatedStatus -PercentComplete $percent
    Start-Sleep -Milliseconds 200  # Verzögerung für sichtbare Animation
}
# ===================== Konfiguration laden =====================
if (-not (Test-Path $ConfigPath)) {
    Write-Err "Konfigurationsdatei nicht gefunden: $ConfigPath"
    exit 1
}
$root = $cfg.root
Update-Progress -Status "Konfiguration geladen"
Write-Info "Root-Verzeichnis: $root"
# ===================== Transcript-Logging (falls aktiviert) =====================
if ($cfg.features.enableTranscriptLogging) {
    $logDir = $PSScriptRoot
    $logFile = $cfg.logging.fileNamePattern -replace "\{timestamp\}", (Get-Date -Format "yyyyMMdd_HHmmss")
    $transcriptPath = Join-Path $logDir $logFile
    Start-Transcript -Path $transcriptPath -Force | Out-Null
    Write-Info "Transcript gestartet: $transcriptPath"
    Update-Progress -Status "Transcript gestartet"
}
# ===================== Ordner erstellen =====================
if ($cfg.features.createFolders -and $cfg.folderProvisioning.projectDirectories) {
    Write-Info "Erstelle Projektordner..."
    foreach ($dir in $cfg.folderProvisioning.projectDirectories) {
        $path = $dir.Replace("{root}", $root)
        $path = [Environment]::ExpandEnvironmentVariables($path)
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Info "Verzeichnis erstellt: $path"
        }
        Update-Progress -Status "Verzeichnis erstellt: $path"
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
Update-Progress -Status "Support-Benutzer erstellt"
Add-LocalGroupMember -Group "Administratoren" -Member "Support"
Update-Progress -Status "Support-Benutzer zur Administratorgruppe hinzugefügt"
# ===================== Dateien kopieren und entsperren =====================
if ($cfg.jobs) {
    foreach ($job in $cfg.jobs) {
        $source = $job.Source.Replace("{root}", $root)
        $destination = $job.Target.Replace("{root}", $root)
        $splitArray = $source.split("\\")
        $fileName = $splitArray[-1]
        $destinationFile = "$destination\$fileName"
        Write-Info "Kopiere $fileName nach $destination"
        Copy-Item -Path $source -Destination $destination -Force
        Write-Info "Erfolg: $fileName kopiert."
        Update-Progress -Status "Datei kopiert: $fileName"
        
        Unblock-File -Path $destinationFile
        Write-Info "Datei entsperrt: $destinationFile"
        Update-Progress -Status "Datei entsperrt: $destinationFile"
    }
}
# ===================== Cleanup =====================
if ($cfg.features.enableTranscriptLogging) {
    Stop-Transcript | Out-Null
    Update-Progress -Status "Transcript gestoppt"
}
Write-Info "Skript abgeschlossen."
Update-Progress -Status "Skript abgeschlossen"
[Console]::Beep(1000, 500)  # Piepton am Ende
