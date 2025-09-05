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
$form = New-Object System.Windows.Forms.Form
$form.Text = "Skript-Fortschritt"
$form.Size = New-Object System.Drawing.Size(300, 100)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 20)
$progressBar.Size = New-Object System.Drawing.Size(260, 20)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0

$form.Controls.Add($progressBar)
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
