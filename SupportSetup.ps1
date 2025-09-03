Clear-Host  # Konsole leeren für sauberen Start
===================== Parameter für Konfigurationsdatei =====================
param (    [Parameter(Mandatory = $false)][string]$config = "config.json")
===================== Einfache Logging-Funktionen =====================
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Green }function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }
===================== Ausführungsrichtlinie früh prüfen und setzen =====================
$currentPolicy = Get-ExecutionPolicy -Scope Processif ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "AllSigned") {    try {        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force        Write-Info "ExecutionPolicy auf RemoteSigned für aktuelle Sitzung gesetzt."    } catch {        Write-Err "Konnte ExecutionPolicy nicht setzen: $_"        Write-Err "Führen Sie das Skript mit 'powershell -ExecutionPolicy Bypass -File .\SupportSetup.ps1 -config .\config.json' aus."        exit 1    }} elseif ($currentPolicy -eq "Bypass") {    Write-Info "ExecutionPolicy ist bereits Bypass, keine Änderung nötig."}
===================== Adminrechte prüfen =====================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {    Write-Err "Bitte führen Sie dieses Skript mit administrativen Rechten aus."    exit 1}
===================== Konfiguration laden =====================
$ConfigPath = Join-Path $PSScriptRoot $configif (-not (Test-Path $ConfigPath)) {    Write-Err "Konfigurationsdatei nicht gefunden: $ConfigPath"    exit 1}$cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json$root = $cfg.root -replace "\\", ""  # Korrigiert doppelte BackslashesWrite-Info "Root-Verzeichnis: $root"
===================== Transcript-Logging (falls aktiviert) =====================
if ($cfg.features.enableTranscriptLogging) {    $logDir = $PSScriptRoot  # Logs immer im Skriptverzeichnis    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }    $logFile = ($cfg.logging.fileNamePattern ?? "SupportSetup_{timestamp}.log") -replace "{timestamp}", (Get-Date -Format "yyyyMMdd_HHmmss")    $transcriptPath = Join-Path $logDir $logFile    Start-Transcript -Path $transcriptPath -Force | Out-Null    Write-Info "Transcript gestartet: $transcriptPath"}
===================== Ordner erstellen =====================
if ($cfg.features.createFolders -and $cfg.folderProvisioning.projectDirectories) {    Write-Info "Erstelle Projektordner..."    foreach ($dir in $cfg.folderProvisioning.projectDirectories) {        $path = $dir.Replace("{root}", $root)        $path = [Environment]::ExpandEnvironmentVariables($path)        if (-not (Test-Path $path)) {            New-Item -ItemType Directory -Path $path -Force | Out-Null            Write-Info "Verzeichnis erstellt: $path"        }    }    Write-Info "Alle Ordner erstellt."}
===================== Sicherheitsrichtlinien setzen =====================
if ($cfg.features.setSecurityPolicies -and $cfg.systemSecuritySettings) {    if ($cfg.systemSecuritySettings.enableLocalAccountTokenFilterPolicy) {        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"        Set-ItemProperty -Path $regPath -Name "LocalAccountTokenFilterPolicy" -Value 1 -Type DWord -Force        Write-Info "LocalAccountTokenFilterPolicy auf 1 gesetzt."    }
if ($cfg.systemSecuritySettings.executionPolicyForScripts) {
    $currentPolicy = Get-ExecutionPolicy -Scope LocalMachine
    if ($currentPolicy -ne $cfg.systemSecuritySettings.executionPolicyForScripts -and $currentPolicy -ne "Bypass") {
        try {
            Set-ExecutionPolicy -ExecutionPolicy $cfg.systemSecuritySettings.executionPolicyForScripts -Scope LocalMachine -Force
            Write-Info "ExecutionPolicy auf $($cfg.systemSecuritySettings.executionPolicyForScripts) gesetzt."
        } catch {
            Write-Warn "ExecutionPolicy konnte nicht gesetzt werden: $_"
        }
    } else {
        Write-Info "ExecutionPolicy ist bereits $($cfg.systemSecuritySettings.executionPolicyForScripts) oder Bypass."
    }
}

}
===================== Lokales Supportkonto anlegen =====================
if ($cfg.features.createSupportUser -and $cfg.localSupportAccount.username -and $cfg.localSupportAccount.password) {    $password = ConvertTo-SecureString $cfg.localSupportAccount.password -AsPlainText -Force    $params = @{        Name                  = $cfg.localSupportAccount.username        Password              = $password        Description           = $cfg.localSupportAccount.description        UserMayNotChangePassword = $true        PasswordNeverExpires  = $true        AccountNeverExpires   = $true    }    if (-not (Get-LocalUser -Name $cfg.localSupportAccount.username -ErrorAction SilentlyContinue)) {        New-LocalUser @params        Write-Info "Support-Benutzer erstellt: $($cfg.localSupportAccount.username)"    } else {        Write-Info "Benutzer existiert bereits: $($cfg.localSupportAccount.username)"    }
$adminGroup = (New-Object System.Security.Principal.SecurityIdentifier "S-1-5-32-544").Translate([System.Security.Principal.NTAccount]).Value.Split('\')[-1]
if ($cfg.localSupportAccount.addToAdministratorsGroup) {
    try {
        Add-LocalGroupMember -Group $adminGroup -Member $cfg.localSupportAccount.username -ErrorAction Stop
        Write-Info "Benutzer zur Admin-Gruppe hinzugefügt: $adminGroup"
    } catch {
        if ($_.Exception.Message -match "already a member" -or $_.Exception.Message -match "bereits ein Mitglied") {
            Write-Info "Benutzer ist bereits Mitglied der Gruppe: $adminGroup"
        } else {
            Write-Err "Fehler beim Hinzufügen zur Admin-Gruppe: $_"
        }
    }
}

}
===================== Dateien kopieren =====================
if ($cfg.jobs) {    foreach ($job in $cfg.jobs) {        try {            $source = $job.Source.Replace("{root}", $root)            $source = [Environment]::ExpandEnvironmentVariables($source)            $destination = $job.Target.Replace("{root}", $root)            $destination = [Environment]::ExpandEnvironmentVariables($destination)            $logFileName = ($job.LogFile ?? "log_$($job.FilePattern)_{timestamp}.txt") -replace "{timestamp}", (Get-Date -Format "yyyyMMdd_HHmmss")            $logFile = Join-Path $PSScriptRoot $logFileName  # Logs immer im Skriptverzeichnis            $logFile = [Environment]::ExpandEnvironmentVariables($logFile)
        if (-not (Test-Path $destination)) {
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
        }

        Write-Info "Kopiere $($job.FilePattern) von $source nach $destination"
        Copy-Item -Path $source -Destination $destination -Force

        Write-Info "Erfolg: $($job.FilePattern) kopiert."
        if ($logFile) {
            Add-Content -Path $logFile -Value "$(Get-Date) ERFOLG: $source nach $destination kopiert" -Encoding UTF8
        }
    } catch {
        Write-Err "Fehler beim Kopieren von $($job.FilePattern): $_"
        if ($logFile) {
            Add-Content -Path $logFile -Value "$(Get-Date) FEHLER: $_" -Encoding UTF8
        }
    }
}

}
===================== Cleanup =====================
if ($cfg.features.enableTranscriptLogging) {    Stop-Transcript | Out-Null}Write-Info "Skript abgeschlossen."
