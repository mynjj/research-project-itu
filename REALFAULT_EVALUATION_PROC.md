
*Make sure you're on right enlistment eval_NAV*

# Determine if job should be dismissed
- Description on info.txt shows no PR
- Check logs for:
  - publishable tests by me
- go to vsts, and PR is closed

# vsts get branch name & checkout
# get failing commit hash
ctrl+f for job, find commit, visit, copy hash
# get passing commit hash
PR > commits > scroll to bottom, parent commit
# get pathS of extensions changed w/ country
PR > files > INSPECTION ... could eventually diff and traverse up in look for app.json...
# checkout failing commit hash
# reset enlistment for failing extension on eval_NAV
Clean-NavEnlistment
.\init.ps1
Reset-NavBinaries
Download-LatestApplicationDeveloperDatabaseFromCheckInGate -CountryCode XX
New-GDLView -CountryCode XX
# publish relevant extension
code PATHTOEXTENSION
Download symbols > publish w/o debugging
.... not ideal, but PULL from master if it's too behind from latestappdeveloperdb..........

# get path of relevant test extensions & extension IDS
- see failing tests > look codeunit id on  vsts > INSPECTION
- see app.json of it
# publish test extension
# copy modified testrunner
# publish testrunner
# Import testrunner cmdlets
.\Eng\Core\Scripts\BuildALTestFramework.ps1 -SkipBuildingTestFramework
import-module .\BuildArtifacts\w1Development\ALTestRunner\ALTestRunner.psm1
# Run tests
# Go to before commit
# edit
code PATH
Remove-GDLView -CountryCode CH
New-GDLView -CountryCode CH
# Load results into sqlite

