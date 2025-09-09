# ===================== Dateien kopieren und entsperren =====================
if ($cfg.jobs) {
    $totalJobs = $cfg.jobs.Count  # Gesamtzahl der Jobs
    $currentJob = 0  # Zähler für aktuelle Jobs

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
        $destinationFile = Join-Path $destination $fileName  # Korrekter Pfad für die Zieldatei

        Write-Info "Kopiere $fileName nach $destination"
        try {
            Copy-Item -Path $source -Destination $destination -Force -ErrorAction Stop
            Write-Info "Erfolg: $fileName kopiert."
        } catch {
            Write-Err "Fehler beim Kopieren von $fileName : $_"
        }

        # Datei entsperren
        try {
            Unblock-File -Path $destinationFile -ErrorAction Stop
            Write-Info "Datei entsperrt: $destinationFile"
        } catch {
            Write-Err "Fehler beim Entsperren von $destinationFile : $_"
        }

        # Optional: Kleine Pause für sichtbaren Fortschritt (entfernen in Produktion, wenn nicht nötig)
        Start-Sleep -Milliseconds 100
    }

    # Progressbalken schließen
    Write-Progress -Activity "Dateien werden kopiert" -Status "Abgeschlossen" -Completed
}
