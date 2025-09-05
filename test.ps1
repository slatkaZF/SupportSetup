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
    #if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $logFile = $cfg.logging.fileNamePattern -replace "\{timestamp\}", (Get-Date -Format "yyyyMMdd_HHmmss")
    $transcriptPath = Join-Path $logDir $logFile
    Start-Transcript -Path $transcriptPath -Force | Out-Null
    Write-Info "Transcript gestartet: $transcriptPath"
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
    }
    Write-Info "Alle Ordner erstellt."
}
# ===================== Sicherheitsrichtlinien setzen =====================
#if ($cfg.features.setSecurityPolicies -and $cfg.systemSecuritySettings) {
#if ($cfg.systemSecuritySettings.executionPolicyForScripts) {
#try {
# Set-ExecutionPolicy -ExecutionPolicy $cfg.systemSecuritySettings.executionPolicyForScripts -Scope LocalMachine -Force
#Write-Info "ExecutionPolicy auf $($cfg.systemSecuritySettings.executionPolicyForScripts) gesetzt."
# } catch {
#  Write-Warn "ExecutionPolicy konnte nicht gesetzt werden: $_"
# }
# }
#}
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
    $totalJobs = $cfg.jobs.Count
    $currentJob = 0

    foreach ($job in $cfg.jobs) {
        $currentJob++
        $percentComplete = ($currentJob / $totalJobs) * 100
        $barLength = 50
        $filledLength = [math]::Round($percentComplete / 2)
        $bar = "#" * $filledLength + "-" * ($barLength - $filledLength)

        Write-Host -NoNewline "["
        Write-Host -NoNewline $bar -ForegroundColor Green
        Write-Host -NoNewline "] "
        Write-Host "$percentComplete% ($currentJob von $totalJobs)" -ForegroundColor Cyan

        $source = $job.Source.Replace("{root}", $root)
        $destination = $job.Target.Replace("{root}", $root)
        $splitArray = $source.Split("\\")
        $fileName = $splitArray[-1]
        $destinationFile = "$destination\$fileName"

        Write-Info "Kopiere $fileName nach $destination"
        Copy-Item -Path $source -Destination $destination -Force
        Write-Info "Erfolg: $fileName kopiert."

        Unblock-File -Path $destinationFile
        Write-Info "Datei entsperrt: $destinationFile"
    }
    Write-Host "Fertig!" -ForegroundColor Green
}
# ===================== Cleanup =====================
if ($cfg.features.enableTranscriptLogging) {
    Stop-Transcript | Out-Null
}
Write-Info "Skript abgeschlossen."
