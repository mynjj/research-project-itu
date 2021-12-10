# Before running:
# .\eng\extensions\helpers\importdme.ps1
# import-module ./eng/core/scripts/infrastructure/azure/azurelogs.psm1

# Downloads all failing test tasks from the past 5 days
# safe to re-run ocasionally

# When manually processing I'm renaming the folders
# to track progress with the convention o-jobXXXX for 
# ok x-jobXXXX for unprocessable (closed PR's, or timeouts, or stability jobs)
# or d-jobXXXX when evaluation data has been obtained
# ... could be (partially) automated by querying vsts...

$outputFolder="candidate-test-jobs"
if (-not(Test-Path -Path $outputFolder -PathType Container)) {
    New-Item -Path $outputFolder -ItemType Directory
}
$sinceNDaysAgo = -5
$dmecontext | Get-DMEJob -Status Failed -QueueName NAV.master_BuddyBuild -StartTime (Get-Date).AddDays($sinceNDaysAgo) -EndTime (Get-Date).AddHours(-1) | Where-Object {
    $testTasks = $_ | Get-DMEJobTask -TaskStatus Failed | Where-Object {
        $_.TaskName -like '*runaltests*'
    } | Measure-Object
    $testTasks.Count -ne 0
} | ForEach-Object {
    $jobId = $_.Id
    $jobFolder = "$outputFolder\job$jobId"
    $previouslyExisting = 
        (Test-Path -Path $jobFolder -PathType Container) -or
        (Test-Path -Path "$outputFolder\o-job$jobId" -PathType Container) -or  # see note on manual processing at the top...
        (Test-Path -Path "$outputFolder\d-job$jobId" -PathType Container) -or
        (Test-Path -Path "$outputFolder\x-job$jobId" -PathType Container)

    if(-not($previouslyExisting)){
        New-Item -Path $jobFolder -ItemType Directory
        $infoContents = @"
For identification on DME
----------------------------
JobId: $jobId

For identification on vsts
----------------------------
Description: $($_.Description)
"@
        $infoContents | New-Item -Path "$jobFolder\info.txt" -ItemType File
        $_ | Get-DMEJobTask -TaskStatus Failed | ForEach-Object {
            $logFilename = (($_.LogFile -split '/') | select-object -Last 1)
            AzureLogs_DownloadFileSet -FileFilter $logFilename -LogFolder https://dmejoblogs.blob.core.windows.net/job$($jobId) -Destination "$outputFolder\job$jobId" 
        }
    }
    else {
        Write-Host "Job $jobId skipped."
    }
}