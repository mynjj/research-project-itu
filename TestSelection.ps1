using namespace System.Collections.Generic
using namespace System


function Coalesce($a, $b) { if ($null -ne $a) { $a } else { $b } }
New-Alias -Force "??" Coalesce
function SafeListCoalesce($l){?? $l @()}
New-Alias -Force "?!" SafeListCoalesce

###### Revision Explorer
class RevisionExplorer {
    RevisionExplorer(){ 
    }
    [string[]] GetDiffLines(){
        throw "Not implemented"
    }
    [string] GetContentsBefore([string] $relativeFilePath){
        throw "Not implemented"
    }
    [string] GetContentsAfter([string] $relativeFilePath){
        throw "Not implemented"
    }
}

class FSRevisionExplorer: RevisionExplorer {
    [string] $beforeFilePath
    [string] $afterFilePath
    FSRevisionExplorer([string] $beforeFilePath, [string] $afterFilePath): base(){
        $this.beforeFilePath = $beforeFilePath
        $this.afterFilePath = $afterFilePath
        if(-not(Test-Path $beforeFilePath -PathType Container)) {
            throw "Error initializing FSRevisionExplorer: $beforeFilePath doesn't exist."
        }
        if(-not(Test-Path $afterFilePath -PathType Container)) {
            throw "Error initializing FSRevisionExplorer: $afterFilePath doesn't exist."
        }
    }
    [string[]] GetDiffLines(){
        $diffText = git diff $this.beforeFilePath $this.afterFilePath -U0 --no-renames
        return ($diffText -split '\n')
    }
    [string] GetContentsBefore([string] $relativeFilePath){
        $fullPath = $relativeFilePath # Git diffs on file sources have the full path on the headers
        if(-not(Test-Path $fullPath -PathType Leaf)){
            throw "Can't find file in previous revision: $fullPath"
        }
        return Get-Content -Path $fullPath
    }
    [string] GetContentsAfter([string] $relativeFilePath){
        $fullPath = $relativeFilePath # Git diffs on file sources have the full path on the headers
        if(-not(Test-Path $fullPath -PathType Leaf)){
            throw "Can't find file in revision: $fullPath"
        }
        return Get-Content -Path $fullPath
    }
}
##################
###### ALRevisionChange

# Representation of changes between revisions in terms of AL code.

# Parsing AL may aid to add meaning and other heuristics to the
# selection methods. However, for now only the basic required
# information is used and extracted, i. e. the object id,
# affected lines, and whether or not is a test object.

class ALRevisionChange {
    ALRevisionChange(){
        if($this.GetType() -eq [ALRevisionChange]){
            throw "Abstract class instantiated"
        }
    }
}

class AddObject: ALRevisionChange {}
class DeleteObject: ALRevisionChange {
    [int32] $removedObjectId
    DeleteObject([int32]$removedObjectId){
        $this.removedObjectId = $removedObjectId
    }
    [string]ToString(){
        return "Object #$($this.removedObjectId) deleted."
    }
}
class AddLinesObject: ALRevisionChange {
    # Lines are added after a given line number on the previous revision
    [int32] $objectId
    [int32] $afterLine
    AddLinesObject($objectId, $afterLine){
        $this.objectId = $objectId
        $this.afterLine = $afterLine
    }
    [string]ToString(){
        return "Object #$($this.objectId) had lines added after line $($this.afterLine)."
    }
}
class RemoveLinesObject: ALRevisionChange {
    [int32] $objectId
    [int32] $firstLineRemoved
    [int32] $nLinesRemoved
    RemoveLinesObject($objectId, $firstLineRemoved, $nLinesRemoved){
        $this.objectId = $objectId
        $this.firstLineRemoved = $firstLineRemoved
        $this.nLinesRemoved = $nLinesRemoved
    }
    [string]ToString(){
        return "Object #$($this.objectId) had $($this.nLinesRemoved) lines removed, starting with $($this.firstLineRemoved)."
    }
}

class AddTestObject: ALRevisionChange {
    [int32] $testCodeunitId
    AddTestObject($testCodeunitId){
        $this.testCodeunitId = $testCodeunitId
    }
    [string]ToString(){
        return "Test object #$($this.testCodeunitId) added."
    }
}
class DeleteTestObject: ALRevisionChange {
    [int32] $testCodeunitId
    DeleteTestObject($testCodeunitId){
        $this.testCodeunitId = $testCodeunitId
    }
    [string]ToString(){
        return "Test object #$($this.testCodeunitId) deleted."
    }
}
class AddLinesTestObject: ALRevisionChange {
    [int32] $testCodeunitId
    AddLinesTestObject($testCodeunitId){
        $this.testCodeunitId = $testCodeunitId
    }
    [string]ToString(){
        return "Test object #$($this.testCodeunitId) had lines added."
    }
}
class RemoveLinesTestObject: ALRevisionChange {
    [int32] $testCodeunitId
    RemoveLinesTestObject($testCodeunitId){
        $this.testCodeunitId = $testCodeunitId
    }
    [string]ToString(){
        return "Test object #$($this.testCodeunitId) had lines removed."
    }
}

function Parse-ALHeader {
    param([string] $contents)
    #$alHeaderRegex = "^(\s|\n)*(?<alObjectType>\w+)(\s|\n)+(?<alObjectId>\d+)(\s|\n)+\w+(\s|\n)*{"
    $alHeaderRegex = "^(\s|\n)*(?<alObjectType>\w+)(\s|\n)+(?<alObjectId>\d+)(\s|\n)+.+{"
    $alHeader = [regex]::Matches($alFile, $alHeaderRegex)
    if($alHeader.Count -ne 1){
        throw "Failed parsing AL file"
    }
    $objectType = $alHeader[0].Groups['alObjectType'].Value.ToLower()
    [int32]$objectId = $alHeader[0].Groups['alObjectId'].Value
    return $alHeader, $objectId
}

function Check-ALObjectIsTest {
    param(
        [string] $objectType,
        [string] $alFile
    )
    if($objectType -ne 'codeunit'){
        return $false
    }
    # If it's a codeunit, we check if it's a test
    $isTestRegex = "Subtype\s*=\s*Test;"
    $isTest = [regex]::Matches($alFile, $isTestRegex)
    if($isTest.Count -eq 0){
        return $false
    }
    return $true
}

function Get-ALRemovalChange {
    [OutputType([ALRevisionChange])]
    param(
        [RevisionExplorer] $revisionExplorer,
        [string] $path
    )
    $alFile = $revisionExplorer.GetContentsBefore($path)
    $objectType, $objectId = Parse-ALHeader $alFile
    if(Check-ALObjectIsTest $objectType $alFile){
        return [DeleteTestObject]::new($objectId)
    }
    return [DeleteObject]::new($objectId)
}

function Get-ALAdditionChange {
    [OutputType([ALRevisionChange])]
    param (
        [RevisionExplorer] $revisionExplorer,
        [string] $path
    )
    $alFile = $revisionExplorer.GetContentsAfter($path)
    $objectType, $objectId = Parse-ALHeader $alFile
    if(Check-ALObjectIsTest $objectType $alFile){
        return [AddTestObject]::new($objectId)
    }
    return [AddObject]::new()
}

function Get-ALModificationChanges {
    [OutputType([List[ALRevisionChange]])]
    param(
        [RevisionExplorer] $revisionExplorer,
        [string]$chunkHeader,
        [string] $path
    )
    $changes = [List[ALRevisionChange]]::new()
    $alFile = $revisionExplorer.GetContentsAfter($path)
    $objectType, $objectId = Parse-ALHeader $alFile
    $chunkHeaderRegex = "\s*@@\s+\-(?<before>(\d|,)+)\s+\+(?<after>(\d|,)+)\s*@@"
    $chunkData = [regex]::Matches($chunkHeader, $chunkHeaderRegex)
    if($chunkData.Count -ne 1){
        throw "Invalid chunk on diff: $chunkHeader"
    }
    $before = $chunkData[0].Groups['before'].Value
    $beforeLineData = $before -split ','
    [int] $beforeLine = $beforeLineData[0]
    $beforeNLines = 1
    if($beforeLineData.Count -ne 1){
        [int] $beforeNLines = $beforeLineData[1]
    }

    $after = $chunkData[0].Groups['after'].Value
    $afterLineData = $after -split ','
    [int] $afterLine = $afterLineData[0]
    $afterNLines = 1
    if($afterLineData.Count -ne 1){
        [int] $afterNLines = $afterLineData[1]
    }

    if($beforeNLines -ne 0){
        # Removed lines
        if(Check-ALObjectIsTest $objectType $alFile){
            $changes.Add([RemoveLinesTestObject]::new($objectId))
        }
        else {
            $changes.Add([RemoveLinesObject]::new($objectId, $beforeLine, $beforeNLines))
        }
    }
    if($afterNLines -ne 0){
        # Added lines
        if(Check-ALObjectIsTest $objectType $alFile){
            $changes.Add([AddLinesTestObject]::new($objectId))
        }
        else {
            $addedAfter = $beforeLine
            if($beforeNLines -ne 0){
                $addedAfter -= 1
            }
            $changes.Add([AddLinesObject]::new($objectId, $addedAfter))
        }
    }
    return $changes
}

function DiffParseInitial {
    param ([string] $line)
    $parsingState = 1
    $parsedHeader = [regex]::Matches($line, "a\/(?<before>.+)\sb\/(?<after>.+)$")
    if($parsedHeader.Count -ne 1){
        throw "Invalid header retrieved: $line"
    }
    $beforePath = $parsedHeader[0].Groups['before'].Value
    $afterPath = $parsedHeader[0].Groups['after'].Value
    return $parsingState, $beforePath, $afterPath
}

# Given a git diff and a way to explore files between revisions,
# it returns a list of ALRevisionChange
function Get-ALRevisionChanges {
    [OutputType([List[ALRevisionChange]])]
    param (
        [RevisionExplorer] $RevisionExplorer
    )
    [List[ALRevisionChange]] $changes = [List[ALRevisionChange]]::new()
    $parsingState, $beforePath, $afterPath = 0, '', ''
    ?! $RevisionExplorer.GetDiffLines() | ForEach-Object {
        $line = $_
        switch($parsingState){
            0  { # Initial state
                if($line -like 'diff*' ){
                    $parsingState, $beforePath, $afterPath = DiffParseInitial $line
                }
                break
            }
            1 { # Header parsed, getting change type
                if($line -like 'index*'){
                    if($beforePath.Substring($beforePath.Length-3, 3) -ne '.al'){
                        $parsingState = 0
                        break
                    }
                    if($afterPath.Substring($afterPath.Length-3, 3) -ne '.al'){
                        $parsingState = 0
                        break
                    }
                    # index line read, without previous "new file" or "deleted file"
                    # this is modification change, we move to parsing the individual lines
                    $parsingState = 2
                }
                elseif($line -like 'new*') {
                    if($afterPath.Substring($afterPath.Length-3, 3) -ne '.al'){
                        $parsingState = 0
                        break
                    }
                    # "new file" found, add the type of change and reset parsing state
                    $change = Get-ALAdditionChange $revisionExplorer $afterPath
                    $changes.Add($change)
                    $parsingState = 0
                }
                elseif($line -like 'deleted*'){
                    if($beforePath.Substring($beforePath.Length-3, 3) -ne '.al'){
                        $parsingState = 0
                        break
                    }
                    # "deleted file" found, add the type of change and reset parsing state
                    $change = Get-ALRemovalChange $revisionExplorer $beforePath 
                    $changes.Add($change)
                    $parsingState = 0
                }
                break
            }
            2 { # Now we get the specific lines for modification changes
                if($line -like '@@*'){
                    [List[ALRevisionChange]] $chunkChanges = Get-ALModificationChanges $revisionExplorer $line $beforePath
                    $changes.AddRange($chunkChanges)
                }
                if($line -like 'diff*'){ 
                    # Reset to initial transition
                    $parsingState, $beforePath, $afterPath = DiffParseInitial $line
                }
                break
            }
        }
    }
    return $changes
}

##################
###### CodeCoverage

function Get-TestQueryRecord {
    [OutputType([Tuple[int32, string]])]
    param ([string] $result)
    [int32]$id, $value = $result -split '\|'
    return [Tuple[int32, string]]::new($id, $value)
}

class CodeCoverage {
    [string] $DBFilePath
    CodeCoverage([string] $DBFilePath){
        $this.DBFilePath = $DBFilePath
    }

    [string[]] query([string] $q){
        return  $q | sqlite3 $this.DBFilePath
    }

    [int32] Create($q){
        [string]$result = $this.query("$q; select last_insert_rowid()")
        if($result -match "^\d+$"){
            return [int32]$result
        }
        throw "Insert failed: $q - $result"
    }

    [int32] CreateTest($codeunitId, $codeunitName){
        return $this.Create("insert into tests(codeunit_id, name) values ($codeunitId, '$codeunitName')")
    }

    [int32] GetOrCreateTest($codeunitId, $codeunitName){
        [string]$maybeId = $this.query("select id from tests where codeunit_id = $codeunitId")
        if ([string]::IsNullOrEmpty($maybeId)) {
            return $this.CreateTest($codeunitId, $codeunitName)
        }
        return [int32]$maybeId
    }

    [int32] CreateTestProcedure($testId, $procedureName){
        return $this.Create("insert into test_procedures(test_id, procedure_name) values ($testId, '$procedureName')")
    }

    [int32] GetOrCreateTestProcedure($testId, $procedureName){
        [string]$maybeId = $this.query("select id from test_procedures where test_id = $testId and procedure_name = '$procedureName'")
        if ([string]::IsNullOrEmpty($maybeId)) {
            return $this.CreateTestProcedure($testId, $procedureName)
        }
        return [int32]$maybeId
    }

    [int32] CreateTestRun($testProcedureId, $duration, $result){
        return $this.Create("insert into test_runs(test_procedure_id, duration, result) values ($testProcedureId, $duration, '$result')")
    }

    [List[int32]] CreateTestRunAndDeps($codeunitId, $codeunitName, $procedureName, $duration, $result){
        $testId = $this.GetOrCreateTest($codeunitId, $codeunitName)
        $testProcedureId = $this.GetOrCreateTestProcedure($testId, $procedureName)
        $testRunId = $this.CreateTestRun($testProcedureId, $duration, $result)
        return $testId, $testProcedureId, $testRunId
    }

    [int32] CreateALObject($objectType, $objectId){
        return $this.Create("insert into al_objects(object_type, object_id) values ('$objectType', $objectId)")
    }

    [int32] GetOrCreateALObject($objectType, $objectId){
        [string]$maybeId = $this.query("select id from al_objects where object_type = '$objectType' and object_id = $objectId")
        if ([string]::IsNullOrEmpty($maybeId)) {
            return $this.CreateALObject($objectType, $objectId)
        }
        return [int32]$maybeId
    }

    [int32] CreateALLine($alObjectId, $lineNumber, $lineType, $content){
        return $this.Create("insert into al_lines(al_object_id, line_number, line_type, hash) values ($alObjectId, $lineNumber, '$lineType', 'NA')") # Removed $content for now to avoid scaping issues, not really needed
    }

    [int32] GetOrCreateALLine($alObjectId, $lineNumber, $lineType, $lineContent){
        [string]$maybeId = $this.query("select id from al_lines where al_object_id = $alObjectId and line_number = $lineNumber")
        if ([string]::IsNullOrEmpty($maybeId)) {
            return $this.CreateALLine($alObjectId, $lineNumber, $lineType, $lineContent)
        }
        return [int32]$maybeId
    }

    [int32] CreateCoverageData($testProcedureId, $alLineId, $coverageType, $hits){
        return $this.Create("insert into coverage_data(test_procedure_id, al_line_id, coverage_type, hits) values ($testProcedureId, $alLineId, '$coverageType', $hits)")
    }

    [int32] CreateCoverageDataAndDeps($testProcedureId, $objectType, $objectId, $lineNumber, $lineType, $lineContent, $coverageType, $hits){
        $alObjectId = $this.GetOrCreateALObject($objectType, $objectId)
        $alLineId = $this.GetOrCreateALLine($alObjectId, $lineNumber, $lineType, $lineContent)
        return $this.CreateCoverageData($testProcedureId, $alLineId, $coverageType, $hits)
    }

    [List[string]] SelectQuery($q){
        # List of records as strings, caller should parse
        [List[string]]$rows = $this.query($q)
        $nonEmptyRows = $rows| Where-Object { [string]::IsNullOrEmpty($_) -eq $false }
        if($null -eq $nonEmptyRows){
            return [List[string]]::new()
        }
        return $nonEmptyRows 
    }

    [Tuple[float, string]] TestRunResults([int32]$testCodeunitId, [string]$testProcedureName){
        $q = @"
        select
            tr.duration,
            tr.result
        from
            test_runs as tr
            inner join
                test_procedures as tp
                on tp.id = tr.test_procedure_id
            inner join
                tests as ts
                on ts.id = tp.test_id
        where
            ts.codeunit_id = $testCodeunitId
            and
            tp.procedure_name = '$testProcedureName'
        limit 1
"@
        $rs = $this.SelectQuery($q)
        if($rs.Count -eq 0){
            return [Tuple[float, string]]::new(0, 'Pass')
        }
        [float]$duration, [string]$result = $rs[0] -split '\|'
        return [Tuple[float, string]]::new($duration, $result)
    }

    [List[Tuple[int32, string]]] TestsProceduresForObject([int32]$objectId){
        $q = @"
        select 
            t.codeunit_id,
            tp.procedure_name
        from 
            coverage_data as cd
            inner join
                al_lines as l
                on l.id = cd.al_line_id
            inner join
                al_objects as o
                on o.id = l.al_object_id
            inner join
                test_procedures as tp
                on tp.id = cd.test_procedure_id
            inner join 
                tests as t
                on t.id = tp.test_id
        where
            o.object_id = $objectId
        group by
            t.codeunit_id, tp.procedure_name
"@
        return ?! $this.SelectQuery($q) | ForEach-Object{ Get-TestQueryRecord $_ }
    }

    [List[Tuple[int32, string]]] TestsProceduresForLines([int32]$objectId, [List[int32]]$lineNumbers){
        # perhaps a condition for selecting lines could be given as argument instead of explicitly the line numbers...
        $lineCondition = "in ($($lineNumbers -join ','))"
        $q = @"
        select 
            t.codeunit_id,
            tp.procedure_name
        from 
            coverage_data as cd
            inner join
                al_lines as l
                on l.id = cd.al_line_id
            inner join
                al_objects as o
                on o.id = l.al_object_id
            inner join
                test_procedures as tp
                on tp.id = cd.test_procedure_id
            inner join 
                tests as t
                on t.id = tp.test_id
        where
            o.object_id = $objectId
            and l.line_number $lineCondition
        group by
            t.codeunit_id, tp.procedure_name
"@
        return ?! $this.SelectQuery($q) | ForEach-Object {
            Get-TestQueryRecord $_
        }
    }

    [List[string]] TestProceduresForTest([int32]$testCodeunitId){
        $q = @"
        select
            tp.procedure_name
        from
            test_procedures as tp
            inner join
                tests as t
                on t.id = tp.test_id
        where
            t.codeunit_id = $testCodeunitId
"@
        return $this.SelectQuery($q)
    }
}

class TestSelectionMethod {
    [List[ALRevisionChange]] $revisionChanges
    [CodeCoverage] $codeCoverage
    TestSelectionMethod([List[ALRevisionChange]] $revisionChanges, [CodeCoverage] $codeCoverage){
        if($this.GetType() -eq [TestSelectionMethod]){
            throw "Abstract class instantiated"
        }
        $this.revisionChanges = $revisionChanges
        $this.codeCoverage = $codeCoverage
    }

    [List[Tuple[int32, string]]] Predict() {
        throw "Not implemented."
    }
}

class SelectAllHittingTestSelectionMethod: TestSelectionMethod {
    SelectAllHittingTestSelectionMethod([List[ALRevisionChange]] $revisionChanges, [CodeCoverage] $codeCoverage) : base($revisionChanges, $codeCoverage){}
    [List[Tuple[int32, string]]] Predict() {
        $collectedTests = @{}
        ?! $this.revisionChanges | ForEach-Object {
            if($_.GetType() -eq [AddObject]){
                # When adding a new AL object, we have no coverage information for it
                # we don't infer any tests to run from this change
            }
            elseif($_.GetType() -eq [DeleteObject]){
                # All the tests associated to the removed object
                ?! $this.codeCoverage.TestsProceduresForObject($_.removedObjectId) | ForEach-Object {
                    if(-not $collectedTests.ContainsKey($_)){
                        $collectedTests.Add($_, $true)
                    }
                }
            }
            elseif($_.GetType() -eq [AddLinesObject]){
                # Tests hitting the line before and after where the lines where added
                ?! $this.codeCoverage.TestsProceduresForLines($_.objectId, @($_.afterLine, $_.afterLine+1)) | ForEach-Object {
                    if(-not $collectedTests.ContainsKey($_)){
                        $collectedTests.Add($_, $true)
                    }
                }
            }
            elseif($_.GetType() -eq [RemoveLinesObject]){
                # Tests that were hitting those lines
                [List[int32]]$lines = @()
                for($i = 0; $i -lt $_.nLinesRemoved; $i++){
                    $lines.Add($_.firstLineRemoved+$i)
                }
                ?! $this.codeCoverage.TestsProceduresForLines($_.objectId, $lines) | ForEach-Object {
                    if(-not $collectedTests.ContainsKey($_)){
                        $collectedTests.Add($_, $true)
                    }
                }
            }
            elseif($_.GetType() -eq [AddTestObject]) {
                # We select the new test
                # how should we represent all procedures if they're not known?? for now '*'
                [Tuple[int32, string]] $test = [Tuple[int32, string]]::new($_.testCodeunitId, "*")
                if(-not $collectedTests.ContainsKey($test)){
                    $collectedTests.Add($test, $true)
                }
            }
            elseif($_.GetType() -eq [DeleteTestObject]){
                # No test to run is inferred from this
                # however the id can be used as filter of the selected tests...
            }
            elseif($_.GetType() -eq [AddLinesTestObject]){
                # We select all the tests of this codeunit since we have no information
                # on structure now
                $testCodeunitId = $_.testCodeunitId
                #maybe we could do with adding '*' if the test runner supports it?
                ?! $this.codeCoverage.TestProceduresForTest($testCodeunitId) | ForEach-Object {
                    $t = [Tuple[int32, string]]::new($testCodeunitId, $_)
                    if(-not $collectedTests.ContainsKey($t)){
                        $collectedTests.Add($t, $true)
                    }
                }
            }
            elseif($_.GetType() -eq [RemoveLinesTestObject]){
                # We select all the tests of this codeunit since we have no information
                # on structure now
                $testCodeunitId = $_.testCodeunitId
                #maybe we could do with adding '*' if the test runner supports it?
                ?! $this.codeCoverage.TestProceduresForTest($testCodeunitId) | ForEach-Object {
                    $t = [Tuple[int32, string]]::new($testCodeunitId, $_)
                    if(-not $collectedTests.ContainsKey($t)){
                        $collectedTests.Add($t, $true)
                    }
                }
            }
            else {
                throw "changeType not recognized"
            }
        }
        # maybe prioritization here?
        [List[Tuple[int32, string]]]$result = @()
        ?! $collectedTests.Keys | ForEach-Object {
            $result.Add($_)
        }
        return $result
    }
}

#=====================================================
function Run-TestSelection{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $CoverageDBFilePath,
        [Parameter(Mandatory=$true)]
        [string] $RevisionBeforePath,
        [Parameter(Mandatory=$true)]
        [string] $RevisionAfterPath
    )

    [CodeCoverage] $codeCoverage = [CodeCoverage]::new($CoverageDBFilePath)
    [RevisionExplorer] $revisionExplorer = [FSRevisionExplorer]::new($RevisionBeforePath, $RevisionAfterPath)
    [List[ALRevisionChange]] $revisionChanges = Get-ALRevisionChanges $revisionExplorer
    [TestSelectionMethod] $selectionMethod = [SelectAllHittingTestSelectionMethod]::new($revisionChanges, $codeCoverage)
    [List[Tuple[int32, string]]]$testPlan = $selectionMethod.Predict()

    return $testPlan
}

function Evaluate-TestSelection{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string] $CodeCoverageDBBefore,
        [Parameter(Mandatory=$true)]
        [string] $CodeCoverageDBAfter
    )
    [List[Tuple[int32, string]]] $tests = Run-TestSelection -CoverageDBFilePath $CodeCoverageDBBefore
    [CodeCoverage] $codeCoverage = [CodeCoverage]::new($CodeCoverageDBAfter)

    Write-Host $tests

    # Test execution time
    $totalTime = 0
    $firstFailureTime = 0
    $nFailuresIncluded = 0
    $firstFailure = $true
    $testRank = 1
    $ranksSum = 0
    $tests | ForEach-Object {
        $rs = $codeCoverage.TestRunResults($_.Item1, $_.Item2)
        $duration = $rs.Item1
        $result = $rs.Item2
        $totalTime += $duration
        if($result -eq 'Fail'){
            if($firstFailure){
                $firstFailure = $false
                $firstFailureTime = $totalTime
            }
            $ranksSum += $testRank
            $nFailuresIncluded++
        }
        $testRank++
    }
    $q = "select sum(duration) from test_runs"
    [string]$fullDurationStr = $codeCoverage.SelectQuery($q)
    [float] $fullDuration = $fullDurationStr

    $q = "select count(*) from test_runs where result='Fail'"
    [string]$totalFailuresStr = $codeCoverage.SelectQuery($q)
    [int32]$totalFailures = $totalFailuresStr

    $q = "select count(*) from test_procedures"
    [string]$totalTestsStr = $codeCoverage.SelectQuery($q)
    [int32]$totalTests = $totalTestsStr

    $execTimeFull = 100*$totalTime/$fullDuration
    $execTimeFFail = 100*$firstFailureTime/$fullDuration
    $inclusiveness = 100*$nFailuresIncluded/$totalFailures
    $selectionSize = 100*$tests.Count/$totalTests
    $napfd = $inclusiveness - 100*$ranksSum/($totalTests*$totalFailures) + $inclusiveness/(2*$totalTests)

    Write-Host "Execution time % full selection: $execTimeFull"
    Write-Host "Execution time % first failure: $execTimeFFail"
    Write-Host "Inclusiveness: $inclusiveness"
    Write-Host "Selection size: $selectionSize"
    Write-Host "nAPFD: $napfd"

}

function ProcessCoverageResults{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [CodeCoverage] $codeCoverage,
        [Parameter(Mandatory=$true)]
        [string] $coverageCSVFilename,
        [Parameter(Mandatory=$true)]
        [int32] $testProcedureId
    )
    $first = $true
    foreach($line in [System.IO.File]::ReadLines($coverageCSVFilename)){
        if($first){
            $first = $false
            continue
        }
        $objectType, [int]$objectId, [int]$lineNumber, $coverageType, [int]$hits, $lineType, $lineContent = $line -split [char]0x00BB
        # should PREVIOUS coverage data of this test procedure be removed before?
        $codeCoverage.CreateCoverageDataAndDeps($testProcedureId, $objectType, $objectId, $lineNumber, $lineType, $lineContent, $coverageType, $hits)
    }
}

$testResultsFilename = 'TestResults.xml'
function Create-CoverageDB{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $TestRunnerOutputFolder,
        [Parameter(Mandatory=$true)]
        [string] $CoverageDBFilePath,
        [switch] $OnlyResults
    )
    # Should be called with output of test runner of BEFORE revision
    if(-not(Test-Path $TestRunnerOutputFolder -PathType Container)){
        throw "Can't find test runner output folder"
    }
    if(-not(Test-Path $CoverageDBFilePath -PathType Leaf)){
        Get-Content .\create-codecoveragedb.sql | sqlite3 $CoverageDBFilePath
    }
    [CodeCoverage] $codeCoverage = [CodeCoverage]::new($CoverageDBFilePath)
    $testResultsPath = Join-Path -Path $TestRunnerOutputFolder -ChildPath $testResultsFilename
    if(-not(Test-Path $testResultsPath -PathType Leaf)){
        throw "Can't find $testResultsPath"
    }
    [xml] $testResults = Get-Content -Path $testResultsPath
    $testResults.assemblies.assembly | ForEach-Object {
        $codeunitId = [int]$_."x-code-unit"
        $codeunitName = $_.name
        $_.collection.test | ForEach-Object {
            $procedureName = $_.method
            $duration = $_.time
            $result = $_.result

            $testId, $testProcedureId, $testRunId = $codeCoverage.CreateTestRunAndDeps($codeunitId, $codeunitName, $procedureName, $duration, $result)
            if(-not ($OnlyResults.IsPresent)){
                $coverageCSVFilename = Join-Path -Path $TestRunnerOutputFolder -ChildPath "$codeunitId-$codeunitName-$procedureName.csv"
                Write-Host "Processing file: $coverageCSVFilename"
                ProcessCoverageResults $codeCoverage $coverageCSVFilename $testProcedureId
            }
        }
    }
}

# relies on dir structure
$BeforeFaultPath = "evaluation/injected-faults/before-faults"
function InjectedFaultsCCDBPath{
    param ([string] $TestSuite)
    return "$BeforeFaultPath/testrunner-outputs/$TestSuite"
}
function InjectedFaultPath{
    param ([int32] $NFault)
    $nString = ([string]$NFault).PadLeft(2, '0')
    return "evaluation/injected-faults/fault-$nString"
}
function InjectedFaultResultsXMLPath{
    param ([int32] $NFault)
    $faultPath = InjectedFaultPath -NFault $NFault
    return "$faultPath/testrunner-output/TestResults.xml"
}
function Evaluate-InjectedFaults{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $TestSuite,
        [Parameter(Mandatory=$true)]
        [int32] $NFault,
        [switch] $JustDiff
    )
    # Takes the coverage db for that test suite
    $beforeCodebasePath = "$BeforeFaultPath/codebase"
    $beforePath = InjectedFaultsCCDBPath -TestSuite $TestSuite
    $coverageDBPath = "$beforePath/coveragedb.sqlite3"
    [CodeCoverage] $coverageDB = [CodeCoverage]::new($coverageDBPath)


    $faultPath = InjectedFaultPath -NFault $NFault
    $afterCodebasePath = "$faultPath/codebase"

    if($JustDiff.IsPresent){ # For diagnosis
        git diff $beforeCodebasePath $afterCodebasePath -U0 --no-renames
        return
    }
    [List[Tuple[int32, string]]] $selection = Run-TestSelection -RevisionBeforePath $beforeCodebasePath -RevisionAfterPath $afterCodebasePath -CoverageDBFilePath $coverageDBPath

    # We create a DB with only the results of the run afterwards
    $resultsDBPath = "$faultPath/testresultsdb.sqlite3"
    Create-CoverageDB -TestRunnerOutputFolder "$faultPath/testrunner-output" -CoverageDBFilePath $resultsDBPath -OnlyResults
    [CodeCoverage] $resultsDB = [CodeCoverage]::new($resultsDBPath)

    # Evaluation
    $totalTime = 0
    $firstFailureTime = 0
    $nFailuresIncluded = 0
    $firstFailure = $true
    $testRank = 1
    $ranksSum = 0
    #$omittedTests = @{}
    $selection | ForEach-Object {
        $testCodeunitId = $_.Item1
        $testProcedureName = $_.Item2
        $rs = $resultsDB.TestRunResults($testCodeunitId, $testProcedureName)
        $duration = $rs.Item1
        $result = $rs.Item2

        if($result -eq 'Fail'){
            # To ensure validity, we first check that it was not failing previously
            Write-Host "Failure afterwards: $testCodeunitId-$testProcedureName"
            $ps = $coverageDB.TestRunResults($testCodeunitId, $testProcedureName)
            if($ps.Item2 -eq 'Fail'){
                Write-Host "> but it previously failed, ignoring"
                # we store it, to omit it on posterior queries
                #[string]$testProcedureIdOmmitedStr = $resultsDB.query("select tps.id from test_procedures as tps inner join tests as ts on tps.test_id=ts.id where tps.procedure_name='$testProcedureName' ts.codeunit_id=$testCodeunitId")
                #[int32] $testProcedureIdOmmited= $testProcedureIdOmmitedStr
                #Write-Host ">> $testProcedureIdOmmited"
                #$omittedTests.Add($testProcedureIdOmmited, $true)
                return
            }
        }

        $totalTime += $duration
        if($result -eq 'Fail'){
            if($firstFailure){
                $firstFailure = $false
                $firstFailureTime = $totalTime
            }
            $ranksSum += $testRank
            $nFailuresIncluded++
        }
        $testRank++
    }

    # We get the codeunit ids and procedures from failing tests on the original revision 
    $q = "select ts.codeunit_id, tps.procedure_name from test_runs as trs inner join test_procedures as tps on trs.test_procedure_id=tps.id inner join tests as ts on tps.test_id = ts.id where trs.result='Fail'"
    $previouslyFailing = $coverageDB.SelectQuery($q)
    $omitTRString = 'true'
    $omitTPString = 'true'
    if($previouslyFailing.Count -ne 0){
        # We get the corresponding ids in the new revision
        $toOmit = ($previouslyFailing | ForEach-Object {"'"+$_.Replace('|','')+"'"}) -Join ','
        $q = "select tr.id, tp.id, (ts.codeunit_id||tp.procedure_name) as testcase_id from test_runs as tr inner join test_procedures as tp on tr.test_procedure_id=tp.id inner join tests as ts on ts.id=tp.test_id where testcase_id in ($toOmit)"
        $result = $resultsDB.SelectQuery($q)
        $testRunsToOmitStr = ($result | ForEach-Object {($_ -split '\|')[0]}) -Join ','
        $testPrcsToOmitStr = ($result | ForEach-Object {($_ -split '\|')[1]}) -Join ','
        $omitTRString = "tr.id not in ($testRunsToOmitStr)"
        $omitTPString = "tp.id not in ($testPrcsToOmitStr)"
    }

    $q = "select sum(duration) from test_runs as tr where $omitTRString "
    [string]$fullDurationStr = $resultsDB.SelectQuery($q)
    [float] $fullDuration = $fullDurationStr

    $q = "select count(*) from test_runs as tr where result='Fail' and $omitTRString"
    [string]$totalFailuresStr = $resultsDB.SelectQuery($q)
    [int32]$totalFailures = $totalFailuresStr

    $q = "select count(*) from test_procedures as tp where $omitTPString"
    [string]$totalTestsStr = $resultsDB.SelectQuery($q)
    [int32]$totalTests = $totalTestsStr

    $execTimeFull = 100*$totalTime/$fullDuration
    $execTimeFFail = 100*$firstFailureTime/$fullDuration
    $inclusiveness = 100*$nFailuresIncluded/$totalFailures
    $selectionSize = 100*$selection.Count/$totalTests
    $napfd = $inclusiveness - 100*$ranksSum/($totalTests*$totalFailures) + $inclusiveness/(2*$totalTests)

    "execTimeFull,$execTimeFull`nexecTimeFFail,$execTimeFFail`ninclusiveness,$inclusiveness`nselectionSize,$selectionSize`nnapfd,$napfd" | New-Item -Path "$faultPath/evaluation.csv" -ItemType File
}