# Clear-Host  # Konsole leeren für sauberen Start
# Erklärung: Diese Zeile löscht den Bildschirm in der PowerShell-Konsole, damit alles sauber und übersichtlich ist, wie das Leeren eines Tisches vor dem Arbeiten.

# ===================== Parameter für Konfigurationsdatei =====================
param (    [Parameter(Mandatory = $false)][string]$config = "config.json")
# Erklärung: Hier definieren wir einen "Parameter" namens $config. Das ist wie eine Eingangstür für das Skript. Wenn jemand das Skript startet, kann er einen Dateinamen angeben (z. B. -config meineconfig.json). Wenn nichts angegeben wird, nimmt es automatisch "config.json". Das macht das Skript flexibel.

# ===================== Einfache Logging-Funktionen =====================
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Green }
# Erklärung: Das ist eine "Funktion" – ein kleiner Baustein, den wir später mehrmals verwenden können. Diese Funktion druckt eine Nachricht auf den Bildschirm mit "[INFO]" davor und in grüner Farbe, um positive Infos zu markieren. "$args" ist ein Platzhalter für die Nachricht, die wir später reinschicken.

function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
# Erklärung: Ähnlich wie oben, aber für Warnungen. Druckt "[WARN]" in gelb, um auf mögliche Probleme aufmerksam zu machen.

function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }
# Erklärung: Für Fehler. Druckt "[ERROR]" in rot, damit man sofort sieht, dass etwas schiefgelaufen ist.

# ===================== Ausführungsrichtlinie früh prüfen und setzen =====================
$currentPolicy = Get-ExecutionPolicy -Scope Process
# Erklärung: Hier fragen wir PowerShell nach der aktuellen "Execution Policy" (Sicherheitsregel, die sagt, welche Skripte ausgeführt werden dürfen). Wir speichern das in einer Variablen namens $currentPolicy. "Scope Process" bedeutet, nur für diese laufende Sitzung.

if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "AllSigned") {    
    try {        
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force        
        Write-Info "ExecutionPolicy auf RemoteSigned für aktuelle Sitzung gesetzt."    
    } catch {        
        Write-Err "Konnte ExecutionPolicy nicht setzen: $_"        
        Write-Err "Führen Sie das Skript mit 'powershell -ExecutionPolicy Bypass -File .\SupportSetup.ps1 -config .\config.json' aus."        
        exit 1    
    }
} elseif ($currentPolicy -eq "Bypass") {    
    Write-Info "ExecutionPolicy ist bereits Bypass, keine Änderung nötig."
}
# Erklärung: Das ist eine "if-Bedingung" – wie ein Entscheidungsbaum. Wenn die Policy "Restricted" (sehr streng, nichts erlaubt) oder "AllSigned" (nur signierte Skripte erlaubt) ist, versuchen wir, sie auf "RemoteSigned" zu setzen (erlaubt lokale Skripte ohne Signatur). "try-catch" fängt Fehler ab: Wenn es klappt, zeigen wir eine Info; wenn nicht, zeigen wir einen Fehler und beenden das Skript ("exit 1" bedeutet "mit Fehler beenden"). Wenn die Policy bereits "Bypass" (alles erlaubt) ist, sagen wir nur, dass nichts zu tun ist.

# ===================== Adminrechte prüfen =====================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {    
    Write-Err "Bitte führen Sie dieses Skript mit administrativen Rechten aus."    
    exit 1
}
# Erklärung: Hier überprüfen wir, ob das Skript mit Admin-Rechten läuft. Das ist wie ein Türsteher: Wir schauen, ob der aktuelle Benutzer Administrator ist. Wenn nicht (-not bedeutet "nicht"), zeigen wir einen Fehler und beenden es. Das verhindert, dass es ohne die nötigen Rechte läuft und scheitert.

# ===================== Konfiguration laden =====================
$ConfigPath = Join-Path $PSScriptRoot $config
# Erklärung: Wir bauen den vollständigen Pfad zur Config-Datei zusammen. $PSScriptRoot ist der Ordner, in dem das Skript liegt, und $config ist der Dateiname (z. B. "config.json"). Das ergibt z. B. "C:\SupportSetup\config.json".

if (-not (Test-Path $ConfigPath)) {    
    Write-Err "Konfigurationsdatei nicht gefunden: $ConfigPath"    
    exit 1
}
# Erklärung: Prüfen, ob die Config-Datei existiert. Wenn nicht, Fehler anzeigen und beenden.

$cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
# Erklärung: Laden der Config-Datei: Lies den Inhalt als Text (-Raw bedeutet alles auf einmal), mit UTF8-Encoding (für Umlaute), und konvertiere es zu einem JSON-Objekt. Speichere es in $cfg, das ist wie ein Wörterbuch mit allen Einstellungen.

$root = $cfg.root -replace "\\", ""  # Korrigiert doppelte Backslashes
# Erklärung: Hole den Root-Wert aus der Config (z. B. "C:\\") und entferne doppelte Backslashes. Achtung: Dein Code hat hier einen Bug – es sollte -replace "\\\\", "\\" sein, um nur doppelte zu korrigieren, nicht alle zu entfernen!

Write-Info "Root-Verzeichnis: $root"
# Erklärung: Zeige den Root an.

# ===================== Transcript-Logging (falls aktiviert) =====================
if ($cfg.features.enableTranscriptLogging) {    
    $logDir = $PSScriptRoot  # Logs immer im Skriptverzeichnis    
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }    
    $logFile = ($cfg.logging.fileNamePattern ?? "SupportSetup_{timestamp}.log") -replace "{timestamp}", (Get-Date -Format "yyyyMMdd_HHmmss")    
    $transcriptPath = Join-Path $logDir $logFile    
    Start-Transcript -Path $transcriptPath -Force | Out-Null    
    Write-Info "Transcript gestartet: $transcriptPath"
}
# Erklärung: Wenn Transcript-Logging in der Config aktiviert ist, erstelle ein detailliertes Log aller Ausgaben. Setze den Log-Ordner auf das Skriptverzeichnis. Wenn es nicht existiert, erstelle es. Ersetze {timestamp} durch das aktuelle Datum/Uhrzeit. Starte das Logging mit Start-Transcript und zeige den Pfad an.

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
# Erklärung: Wenn Ordnererstellung aktiviert ist, gehe durch die Liste der Ordner in der Config. Ersetze {root} durch den Root-Pfad, erweitere Umgebungsvariablen. Wenn der Ordner nicht existiert, erstelle ihn und zeige es an. "foreach" ist eine Schleife, wie das Wiederholen eines Schrittes für jedes Item in einer Liste.

# ===================== Sicherheitsrichtlinien setzen =====================
if ($cfg.features.setSecurityPolicies -and $cfg.systemSecuritySettings) {    
    if ($cfg.systemSecuritySettings.enableLocalAccountTokenFilterPolicy) {        
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"        
        Set-ItemProperty -Path $regPath -Name "LocalAccountTokenFilterPolicy" -Value 1 -Type DWord -Force        
        Write-Info "LocalAccountTokenFilterPolicy auf 1 gesetzt."    
    }
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
# Erklärung: Wenn Sicherheitsrichtlinien aktiviert sind, setze den Registry-Wert für LocalAccountTokenFilterPolicy auf 1 (erlaubt Fernzugriff für lokale Admins). Dann prüfe und setze die Execution Policy auf den Wert aus der Config (z. B. RemoteSigned), aber nur wenn nötig. "try-catch" fängt Fehler ab.

# ===================== Lokales Supportkonto anlegen =====================
if ($cfg.features.createSupportUser -and $cfg.localSupportAccount.username -and $cfg.localSupportAccount.password) {    
    $password = ConvertTo-SecureString $cfg.localSupportAccount.password -AsPlainText -Force    
    $params = @{        
        Name                  = $cfg.localSupportAccount.username        
        Password              = $password        
        Description           = $cfg.localSupportAccount.description        
        UserMayNotChangePassword = $true        
        PasswordNeverExpires  = $true        
        AccountNeverExpires   = $true    
    }    
    if (-not (Get-LocalUser -Name $cfg.localSupportAccount.username -ErrorAction SilentlyContinue)) {        
        New-LocalUser @params        
        Write-Info "Support-Benutzer erstellt: $($cfg.localSupportAccount.username)"    
    } else {        
        Write-Info "Benutzer existiert bereits: $($cfg.localSupportAccount.username)"    
    }
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
# Erklärung: Wenn Benutzererstellung aktiviert ist, konvertiere das Passwort zu einem sicheren Format. Erstelle einen Hash mit Parametern (wie ein Einkaufszettel). Prüfe, ob der Benutzer existiert; wenn nicht, erstelle ihn und zeige es an. Hole den den Namen der Admin-Gruppe (sprachunabhängig). Füge den Benutzer zur Gruppe hinzu, oder zeige, wenn er bereits drin ist. "try-catch" fängt Fehler ab.

# ===================== Dateien kopieren =====================
if ($cfg.jobs) {    
    foreach ($job in $cfg.jobs) {        
        try {            
            $source = $job.Source.Replace("{root}", $root)            
            $source = [Environment]::ExpandEnvironmentVariables($source)            
            $destination = $job.Target.Replace("{root}", $root)            
            $destination = [Environment]::ExpandEnvironmentVariables($destination)            
            $logFileName = ($job.LogFile ?? "log_$($job.FilePattern)_{timestamp}.txt") -replace "{timestamp}", (Get-Date -Format "yyyyMMdd_HHmmss")            
            $logFile = Join-Path $PSScriptRoot $logFileName  # Logs immer im Skriptverzeichnis            
            $logFile = [Environment]::ExpandEnvironmentVariables($logFile)
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
# Erklärung: Wenn Jobs in der Config definiert sind, gehe durch jeden Job (Schleife). Ersetze {root} und Variablen in Quell- und Zielpfad. Erstelle den Zielordner, wenn nicht vorhanden. Kopiere die Datei. Schreibe Erfolg in Log. Bei Fehler: Zeige und logge ihn.

# ===================== Cleanup =====================
if ($cfg.features.enableTranscriptLogging) {    
    Stop-Transcript | Out-Null
}
Write-Info "Skript abgeschlossen."
# Erklärung: Wenn Logging aktiviert war, stoppe es. Zeige am Ende "Skript abgeschlossen" an. Das ist wie das Aufräumen nach dem Kochen.
