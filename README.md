# SupportSetup
SupportSetup.ps1 - Automatisiertes Setup-Skript für TIA-PCs
Dieses Repository enthält ein PowerShell-Skript (SupportSetup.ps1) und eine Konfigurationsdatei (config.json), das die Einrichtung eines neuen TIA-PCs (z. B. für Testing Technology) automatisiert. Es erstellt Ordnerstrukturen, setzt Sicherheitsrichtlinien, legt ein lokales Support-Benutzerkonto an und kopiert Tools von einem Netzlaufwerk.
Das Skript ist für Windows-Umgebungen optimiert und erfordert Administratorrechte. Es ist portabel: Logs werden immer im Verzeichnis des Skripts gespeichert, egal wohin es verschoben wird.
Funktionen

Ordnererstellung: Erstellt eine vordefinierte Ordnerstruktur (z. B. C:\00_TestingTechnology, C:\02_Tools).
Sicherheitsrichtlinien: Setzt LocalAccountTokenFilterPolicy auf 1 und die PowerShell Execution Policy auf RemoteSigned.
Support-Benutzer: Legt einen lokalen Admin-Benutzer (Support) mit festem Passwort an.
Dateikopien: Kopiert Dateien/Tools von einem Netzlaufwerk (z. B. \\emea.zf-world.com\...) in das Zielverzeichnis.
Logging: Erzeugt Transcript-Logs und Job-spezifische Logs im Skriptverzeichnis (portabel, wandern mit dem Skript).
Execution Policy-Check: Prüft und setzt die Policy automatisch, mit Fallback auf Bypass-Empfehlung.

Voraussetzungen

Betriebssystem: Windows (getestet auf Windows 10/11).
PowerShell: Version 5.1 oder höher (standardmäßig installiert).
Netzwerkzugriff: Zugriff auf das Netzlaufwerk (z. B. \\emea.zf-world.com) für Dateikopien.
Rechte: Das Skript muss mit Administratorrechten ausgeführt werden (rechtsklicken > "Als Administrator ausführen").
Execution Policy: Setze auf RemoteSigned (siehe unten). Wenn blockiert (z. B. durch Group Policy), verwende Bypass.

Installation

Klone oder downloade das Repository.
Kopiere SupportSetup.ps1 und config.json in ein Verzeichnis (z. B. C:\SupportSetup).
Passe config.json bei Bedarf an (z. B. root-Pfad, Jobs).

Nutzung

Öffne PowerShell als Administrator.
Wechsle in das Skriptverzeichnis:
textcd C:\SupportSetup

Entferne ggf. den "Block" der Datei (falls aus dem Internet heruntergeladen):
textUnblock-File -Path ".\SupportSetup.ps1"

Setze die Execution Policy (falls nötig):
textSet-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

Führe das Skript aus:
text.\SupportSetup.ps1 -config .\config.json

Wenn ein Signierungsfehler auftritt (z. B. durch Group Policy):
textpowershell -ExecutionPolicy Bypass -File .\SupportSetup.ps1 -config .\config.json




Das Skript protokolliert alle Aktionen und erstellt Logs im aktuellen Verzeichnis.
Konfiguration (config.json)
Die Datei steuert das Verhalten des Skripts. Wichtige Felder:

"root": Basisverzeichnis für Ordner (z. B. "C:\\").
"features": Aktiviere/Deaktiviere Funktionen (z. B. "createFolders": true).
"folderProvisioning": Liste der zu erstellenden Ordner.
"localSupportAccount": Benutzerdetails (Username, Password, Description).
"systemSecuritySettings": Policies (z. B. Execution Policy).
"jobs": Dateikopien (Source, Target, FilePattern).

Beispielauszug:
json{
  "root": "C:\\",
  "features": {
    "createFolders": true,
    "createSupportUser": true
  },
  // ...
}
Logs

Transcript-Log: Vollständiges Protokoll (z. B. SupportSetup_20250903_104500.log).
Job-Logs: Pro Dateikopie (z. B. log_chrome_20250903_104500.txt).
Portabilität: Alle Logs werden im Verzeichnis der .ps1-Datei erstellt. Verschiebe das Skript – die Logs wandern mit!

Hinweise und Warnungen

Irreversible Aktionen: Das Skript erstellt Benutzer und ändert Registry-Einträge – teste in einer VM!
Netzwerk: Stelle sicher, dass der PC Zugriff auf \\emea.zf-world.com hat.
Execution Policy: Wenn Group Policies blockieren, verwende Bypass. Konsultiere deine IT.
Sicherheit: Das Passwort im Skript ist hardcodiert – in Produktion verschlüsseln oder ändern.
Fehlerbehandlung: Das Skript hat Try-Catch-Blöcke und Warnungen – überprüfe Logs bei Fehlern.

Lizenz
