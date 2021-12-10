# Test Selection

## Dummy "Movies" extension
- Path: `F:\repos\sample-AL-extension\app`

## AL Test Runner

- Branch: `408278-AddCodeCoverageModule`
- Path: `F:\repos\NAV\App\Modules\DevTools\TestFramework\TestRunner`
- Load the PS cmdlet:
  -  `F:\repos\NAV\Eng\Core\Scripts\BuildALTestFramework.ps1 -SkipBuildingTestFramework`
  - `Import-Module F:\repos\NAV\BuildArtifacts\w1Development\ALTestRunner\ALTestRunner.psm1`
  - After AL Test Runner app published; CLI TestRunner available
### CLI TestRunner
- Examples
`Run-ALTests -TestCodeunitsRange '50150|50151' -AutorizationType Windows -ServiceUrl 'http://localhost:48900' -CodeCoverageTracking PerTestMethod -CodeCoverageOutputPath F:\cc\workspace\testrunner-output -ResultsFilePath F:\cc\workspace\testrunner-output\TestResults.xml`

`Run-AlTests -ExtensionId '503c80fa-5e48-4222-847e-738dab25c9cf' -AutorizationType Windows -ServiceUrl 'http://localhost:48900' -CodeCoverageTracking PerTestMethod -CodeCoverageOutputPath F:\cc\workspace\testrunner-output -ResultsFilePath F:\cc\workspace\testrunner-output\TestResults.xml`

- Manually running Command Line Test Tool from webcli
130451 - Codeunit id of runner

Codecov tracking: 
- 0: Disabled
- 1: PerTestCodeunit
- 2: PerTestMethod

- Run Next Test

> runs tests on codeunit, returns testresultjson w/ an array of methodS with results
> creates entry on "AL Code Coverage Result"

- Get Code Coverage (repetedly until "Al CC Results Collected")

> Reads from db, into "code coverage result text" text control deletes it
> "code coverage info" has from which codeunit AND method it belongs (if tracking is 2)

- Loop
 
## Exploration of DME failed jobs

### Querying the information from the build system

- Required PS modules:
- `.\eng\extensions\helpers\importdme.ps1`
- `import-module ./eng/core/scripts/infrastructure/azure/azurelogs.psm1`

- Getting failed Jobs/Job Tasks
`$dmecontext | Get-DMEJob -Status Failed -QueueName NAV.master_BuddyBuild -StartTime (Get-date).AddDays(-2) -EndTime (Get-date).AddHours(-1)| Get-DMEJobTask -TaskStatus Failed | select -First 5 `

- Getting logs for job task
For `$_` a `JobTask` object:
```
$filename = (($_.LogFile -split '/') | select -Last 1)
AzureLogs_DownloadFileSet -FileFilter $filename -LogFolder https://dmejoblogs.blob.core.windows.net/job$($_.JobId) -Destination F:\wherever
```

### Running & modifying tasks as build
(In `SnapWrapper.ps1` comment CleanupEnvironment)