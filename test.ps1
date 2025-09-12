if ($cfg.jobs) {
    $totalJobs = $cfg.jobs.Count # Gesamtzahl der Jobs
    $currentJob = 0 # Zähler für aktuelle Jobs
    foreach ($job in $cfg.jobs) {
        $currentJob++
        $percentComplete = ($currentJob / $totalJobs) * 100
        Write-Progress -Activity "Dateien werden kopiert" -Status "Verarbeite Job $currentJob von $totalJobs" -PercentComplete $percentComplete
        
        $source = $job.Source -ireplace '\{root\}', $root
        $destination = $job.Target -ireplace '\{root\}', $root
        $fileName = [System.IO.Path]::GetFileName($source)
        $targetPath = Join-Path $destination $fileName
        
        Write-Info "Kopiere von $source nach $destination"
        Copy-Item -Path $source -Destination $destination -Recurse -Force
        Write-Info "Entsperre $targetPath"
        Get-ChildItem -Path $targetPath -Recurse -File | Unblock-File
    }
    Write-Progress -Activity "Dateien werden kopiert" -Status "Abgeschlossen" -Completed
}
# ===================== Cleanup =====================
if ($cfg.features.enableTranscriptLogging) {
