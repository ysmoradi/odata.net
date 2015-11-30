if (($args.Count -eq 0) -or ($args[0] -match 'Nightly')) 
{
    $TestType = 'Nightly'
    $CONFIGURATION = 'Release'
}
elseif ($args[0] -match 'Rolling')
{
    $TestType = "Rolling"
    $CONFIGURATION = 'Debug'
}
elseif ($args[0] -match 'DisableSkipStrongName')
{
    $TestType = "DisableSkipStrongName"
    $CONFIGURATION = 'Debug'
}
elseif ($args[0] -match 'SkipStrongName')
{
    $TestType = "SkipStrongName"
    $CONFIGURATION = 'Debug'
}
else 
{
    Write-Host 'Please choose Nightly Test or Rolling Test!' -ForegroundColor Red
    exit
}

$PROGRAMFILESX86 = [Environment]::GetFolderPath("ProgramFilesX86")
$env:ENLISTMENT_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ENLISTMENT_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LOGDIR = $ENLISTMENT_ROOT + "\bin"

# Default to use Visual Studio 2013.
$MSBUILD = $PROGRAMFILESX86 + "\MSBuild\12.0\Bin\MSBuild.exe"
$MSTEST = $PROGRAMFILESX86 + "\Microsoft Visual Studio 12.0\Common7\IDE\MSTest.exe"
$FXCOPDIR = $PROGRAMFILESX86 + "\Microsoft Visual Studio 12.0\Team Tools\Static Analysis Tools\FxCop"
$SN = $PROGRAMFILESX86 + "\Microsoft SDKs\Windows\v8.1A\bin\NETFX 4.5.1 Tools\sn.exe"
$SNx64 = $PROGRAMFILESX86 + "\Microsoft SDKs\Windows\v8.1A\bin\NETFX 4.5.1 Tools\x64\sn.exe"

# Fall back to Visual Studio 2015.
if (!(Test-Path $MSBUILD))
{
    $MSBUILD = $PROGRAMFILESX86 + "\MSBuild\14.0\Bin\MSBuild.exe"
}

if (!(Test-Path $MSTEST))
{
    $MSTEST = $PROGRAMFILESX86 + "\Microsoft Visual Studio 14.0\Common7\IDE\MSTest.exe"
}

if (!(Test-Path $FXCOPDIR))
{
    $FXCOPDIR = $PROGRAMFILESX86 + "\Microsoft Visual Studio 14.0\Team Tools\Static Analysis Tools\FxCop"
}

$FXCOP = $FXCOPDIR + "\FxCopCmd.exe"
$BUILDLOG = $LOGDIR + "\msbuild.log"
$TESTLOG = $LOGDIR + "\mstest.log"
$TESTDIR = $ENLISTMENT_ROOT + "\bin\AnyCPU\$CONFIGURATION\Test\Desktop"
$PRODUCTDIR = $ENLISTMENT_ROOT + "\bin\AnyCPU\$Configuration\Product\Desktop"
$NUGETPACK = $ENLISTMENT_ROOT + "\sln\packages"

$ProductDlls = "Microsoft.OData.Client.dll",
    "Microsoft.OData.Core.dll",
    "Microsoft.OData.Edm.dll",
    "Microsoft.OData.Service.Design.T4.dll",
    "Microsoft.Spatial.dll"

$TestDlls = "Microsoft.OData.Service.Design.T4.dll",
    "Microsoft.OData.Service.dll",
    "Microsoft.OData.Service.Test.Common.dll"

$RollingTestDlls = "Microsoft.Test.Data.Services.DDBasics.dll", 
    "Microsoft.OData.Client.Design.T4.UnitTests.dll", 
    "AstoriaUnitTests.TDDUnitTests.dll", 
    "EdmLibTests.dll", 
    "Microsoft.OData.Client.TDDUnitTests.dll", 
    "Microsoft.Spatial.TDDUnitTests.dll", 
    "Microsoft.Test.Edm.TDD.Tests.dll", 
    "Microsoft.Test.OData.TDD.Tests.dll", 
    "Microsoft.Test.OData.Query.TDD.Tests.dll", 
    "Microsoft.Test.Taupo.OData.Common.Tests.dll", 
    "Microsoft.Test.Taupo.OData.Query.Tests.dll", 
    "Microsoft.Test.Taupo.OData.Reader.Tests.dll", 
    "Microsoft.Test.Taupo.OData.Writer.Tests.dll", 
    "Microsoft.Test.Taupo.OData.Scenario.Tests.dll", 
    "AstoriaUnitTests.ClientCSharp.dll", 
    "Microsoft.Data.NamedStream.UnitTests.dll", 
    "Microsoft.Data.ServerUnitTests1.UnitTests.dll", 
    "Microsoft.Data.ServerUnitTests2.UnitTests.dll", 
    "RegressionUnitTests.dll", 
    "Microsoft.Test.OData.PluggableFormat.Tests.dll"

$RollingTestSuite = @()
ForEach($dll in $RollingTestDlls)
{
    $RollingTestSuite += "/testcontainer:" + $dll
}

$AdditionalNightlyTestDlls = "Microsoft.Data.MetadataObjectModel.UnitTests.dll", 
        "AstoriaUnitTests.dll", 
        "AstoriaClientUnitTests.dll", 
        "Microsoft.Test.OData.User.Tests.dll", 
        "TestCategoryAttributeCheck.dll"

ForEach($dll in $AdditionalNightlyTestDlls)
{
    $AdditionalNightlyTestSuite += "/testcontainer:" + $dll
}

$NightlyTestSuite = $RollingTestSuite
ForEach ($test in $AddtionalNightlyTestSuite)
{
    $NightlyTestSuite += $test
}

$E2eTestDlls = ,"Microsoft.Test.OData.Tests.Client.dll"

ForEach ($dll in $E2eTestDlls)
{
    $E2eTestSuite += " /testcontainer:" + $dll
}

$FxCopRulesOptions = "/rule:$FxCopDir\Rules\DesignRules.dll",
        "/rule:$FxCopDir\Rules\NamingRules.dll",
        "/rule:$FxCopDir\Rules\PerformanceRules.dll",
        "/rule:$FxCopDir\Rules\SecurityRules.dll",
        "/rule:$FxCopDir\Rules\GlobalizationRules.dll",
        "/dictionary:$ENLISTMENT_ROOT\src\CustomDictionary.xml",
        "/ruleid:-Microsoft.Design#CA1006", 
        "/ruleid:-Microsoft.Design#CA1016", 
        "/ruleid:-Microsoft.Design#CA1020", 
        "/ruleid:-Microsoft.Design#CA1021", 
        "/ruleid:-Microsoft.Design#CA1045", 
        "/ruleid:-Microsoft.Design#CA2210", 
        "/ruleid:-Microsoft.Performance#CA1814"
$DataWebRulesOption = "/rule:$TESTDIR\DataWebRules.dll"

Function GetDlls
{
    $dlls = @()

    ForEach($dll in $ProductDlls)
    {
        $dlls += $PRODUCTDIR + "\" + $dll
    }

    ForEach($dll in $TestDlls)
    {
        $dlls += $TESTDIR + "\" + $dll
    }
    
    ForEach($dll in $RollingTestDlls)
    {
        $dlls += $TESTDIR + "\" + $dll
    }

    ForEach($dll in $AdditionalNightlyTestDlls)
    {
        $dlls += $TESTDIR + "\" + $dll
    }

    ForEach($dll in $E2eTestDlls)
    {
        $dlls += $TESTDIR + "\" + $dll
    }

    return $dlls
}

Function SkipStrongName
{
    $SnLog = $LOGDIR + "\SkipStrongName.log"
    Out-File $SnLog

    Write-Host 'Skip strong name validations for ODataLib assemblies...'

    $dlls = GetDlls
    ForEach ($dll in $dlls)
    {
        & $SN /Vr $dll | Out-File $SnLog -Append
    }

    ForEach ($dll in $dlls)
    {
        & $SNx64 /Vr $dll | Out-File $SnLog -Append
    }

    Write-Host "SkipStrongName Done" -ForegroundColor Green
}

Function DisableSkipStrongName
{
    $SnLog = $LOGDIR + "\DisableSkipStrongName.log"
    Out-File $SnLog

    Write-Host 'Disable skip strong name validations for ODataLib assemblies...'

    $dlls = GetDlls
    ForEach ($dll in $dlls)
    {
        & $SN /Vu $dll | Out-File $SnLog -Append
    }

    ForEach ($dll in $dlls)
    {
        & $SNx64 /Vu $dll | Out-File $SnLog -Append
    }

    Write-Host "DisableSkipStrongName Done" -ForegroundColor Green
}

Function Cleanup 
{    
    cd $ENLISTMENT_ROOT\tools\Scripts
    Write-Host "Dropping stale databases..."
    cscript "$ENLISTMENT_ROOT\tools\Scripts\artdbclean.js" //Nologo
    cd $ENLISTMENT_ROOT
    Write-Host "Clean Done" -ForegroundColor Yellow
}

Function CleanBeforeScorch
{
    Write-Host 'killing TaupoAstoriaRunner as it should no longer be running'
    taskkill /F /IM "TaupoAstoriaRunner.exe" 1>$null 2>$null

    Write-Host 'killing TaupoConsoleRunner as it should no longer be running'
    taskkill /F /IM "TaupoConsoleRunner.exe" 1>$null 2>$null

    Write-Host 'killing MSTest as it should no longer be running'
    taskkill /F /IM "MsTest.exe" 1>$null 2>$null

    Write-Host 'killing MSbuild as it should no longer be running'
    taskkill /F /IM "MSbuild.exe" 1>$null 2>$null

    Write-Host 'Stopping code coverage gathering...'
    taskkill /f /im VSPerfMon.exe 1>$null 2>$null

    Write-Host 'Killing WinHttpAutoProxySvc as it overflows due to large amount of web calls'
    taskkill /F /FI "SERVICES eq WinHttpAutoProxySvc" >$null

    net stop w3svc 1>$null 2>$null

    Write-Host 'Minimize SQLExpress memory footprint'
    net stop "SQL Server (SQLEXPRESS)"  2>$null
    net start "SQL Server (SQLEXPRESS)" 2>$null
    
    Write-Host "Clean Done" -ForegroundColor Yellow
}

# Incremental build
Function RunBuild ($sln)
{
    Write-Host "*** Building $sln ***"
    $slnpath = $ENLISTMENT_ROOT + "\sln\$sln"
    if ($TestType -eq 'Nightly')
    {
        $Conf = "/p:Configuration=Release"
    }
    else
    {
        $Conf = "/p:Configuration=Debug"
    }
    & $MSBUILD $slnpath /t:build /m /nr:false /fl "/p:Platform=Any CPU" $Conf /p:Desktop=true `
        /flp:LogFile=$LOGDIR/msbuild.log /flp:Verbosity=Normal 1>$null 2>$null
    if($LASTEXITCODE -eq 0)
    {
        Write-Host "Build $sln SUCCESS" -ForegroundColor Green
    }
    else
    {
        Write-Host "Build $sln FAILED" -ForegroundColor Red
        Write-Host "For more information, please open the following test result files:"
        Write-Host "$LOGDIR\msbuild.log"
        Cleanup
        exit
    }
}

# Rebuild
Function RunRebuild ($sln)
{
    Write-Host "*** Building $sln ***"
    $slnpath = $ENLISTMENT_ROOT + "\sln\$sln"
    if ($TestType -eq 'Nightly')
    {
        $Conf = "/p:Configuration=Release"
    }
    else
    {
        $Conf = "/p:Configuration=Debug"
    }
    & $MSBUILD $slnpath /t:rebuild /m /nr:false /fl "/p:Platform=Any CPU" $Conf /p:Desktop=true `
        /flp:LogFile=$LOGDIR/msbuild.log /flp:Verbosity=Normal 1>$null 2>$null
    if($LASTEXITCODE -eq 0)
    {
        Write-Host "Build $sln SUCCESS" -ForegroundColor Green
    }
    else
    {
        Write-Host "Build $sln FAILED" -ForegroundColor Red
        Write-Host "For more information, please open the following test result files:"
        Write-Host "$LOGDIR\msbuild.log"
        Cleanup
        exit
    }
}
Function RestoringFile ($file , $target)
{
    Write-Host "Restoring $file"
    Copy-Item -Path $file -Destination $target -Force
}

Function FailedTestLog ($playlist , $reruncmd , $failedtest1 ,$failedtest2)
{    
    Write-Output "<Playlist Version=`"1.0`">" | Out-File $playlist
    Write-Output "@echo off" | Out-File -Encoding ascii $reruncmd
    Write-Output "cd $TESTDIR" | Out-File -Append -Encoding ascii $reruncmd
    $rerun = "`"$MSTEST`""
    if ($TestType -eq 'Nightly')
    {
        foreach ($dll in $NightlyTestSuite) 
        {
            $rerun += " $dll" 
        }
    }
    else
    {
        foreach ($dll in $RollingTestSuite) 
        {
            $rerun += " $dll" 
        }
    }
    foreach($case in $failedtest1)
    {
        $name = $case.split('.')[-1]
        $rerun += " /test:$name"
        $output = "<Add Test=`"" + $case + "`" />"
        Write-Output $output  | Out-File -Append $playlist
    } 
    # build the command only if failed tests exist
    if ($failedtest1.count -gt 0)
    {
        Write-Output "copy /y $NUGETPACK\EntityFramework.4.3.1\lib\net40\EntityFramework.dll ." | Out-File -Append -Encoding ascii $reruncmd
        Write-Output $rerun | Out-File -Append -Encoding ascii $reruncmd
    }
    $rerun = "`"$MSTEST`""
    foreach ($dll in $E2eTestSuite)
    {
        $rerun += " $dll" 
    }    
    foreach($case in $failedtest2)
    {
        $name = $case.split('.')[-1]
        $rerun += " /test:$name"
        $output = "<Add Test=`"" + $case + "`" />"
        Write-Output $output  | Out-File -Append $playlist
    }
    # build the command only if failed tests exist
    if ($failedtest2.count -gt 0)
    {
        Write-Output "copy /y $NUGETPACK\EntityFramework.5.0.0\lib\net40\EntityFramework.dll ." | Out-File -Append -Encoding ascii $reruncmd
        Write-Output $rerun | Out-File -Append -Encoding ascii $reruncmd
    }
    Write-Output "cd $LOGDIR" | Out-File -Append -Encoding ascii $reruncmd
    Write-Output "</Playlist>" | Out-File -Append $playlist
    Write-Host "There are some test cases failed!" -ForegroundColor Red
    Write-Host "To replay failed tests, please open the following playlist file:" -ForegroundColor Red
    Write-Host $playlist -ForegroundColor Red
    Write-Host "To rerun failed tests, please run the following script:" -ForegroundColor Red
    Write-Host $reruncmd -ForegroundColor Red
}

Function TestSummary
{
    Write-Host 'Collecting test results'
    $playlist = "$LOGDIR\FailedTests.playlist"
    $reruncmd = "$LOGDIR\rerun.cmd"
    if (Test-Path $playlist)
    {
        rm $playlist
    }
    if (Test-Path $reruncmd)
    {
        rm $reruncmd
    }
    
    $file = Get-Content -Path $TESTLOG
    $pass = 0
    $fail = 0
    $trxfile = New-Object -TypeName System.Collections.ArrayList
    $failedtest1 = New-Object -TypeName System.Collections.ArrayList
    $failedtest2 = New-Object -TypeName System.Collections.ArrayList
    $part = 1
    foreach ($line in $file)
    {
    
        if ($line -match "^Passed.*") 
        {
            $pass = $pass + 1
        }
        elseif ($line -match "^Failed\s+(.*)")
        {
            $fail = $fail + 1
            if ($part -eq 1)
            {
                [void]$failedtest1.Add($Matches[1])
            }
            else
            {    
                [void]$failedtest2.Add($Matches[1])
            }
        }
        elseif ($line -match "^Results file: (.*)")
        {
            [void]$trxfile.Add($Matches[1])
            $part = 2
        }
    }
    Write-Host "The summary of $title :" -ForegroundColor Green
    Write-Host "Passed :`t$pass"  -ForegroundColor Green
    Write-Host "Failed :`t$fail"  -ForegroundColor Green
    Write-Host "---------------"  -ForegroundColor Green
    Write-Host "Total :`t$($pass + $fail)"  -ForegroundColor Green
    Write-Host "For more information, please open the following test result files:"
    foreach ($trx in $trxfile)
    {
        Write-Host $trx
    }
    if ($fail -gt 0)
    {
        FailedTestLog -playlist $playlist -reruncmd $reruncmd -failedtest1 $failedtest1 -failedtest2 $failedtest2 
    }
    else
    {
        Write-Host "Congratulation! All of the tests passed!" -ForegroundColor Green
    }
}

Function RunTest ($title, $testdir)
{
    Write-Host "**********Running $title***********"
    Write-Host "$testdir"
    & $MSTEST $testdir >> $TESTLOG
    if($LASTEXITCODE -ne 0)
    {
        Write-Host "Run $title FAILED" -ForegroundColor Red
    }
}

Function BuildProcess
{
    Write-Host '**********Start To Build The Project*********'
    $script:BUILD_START_TIME = Get-Date
    if (Test-Path $BUILDLOG)
    {
        rm $BUILDLOG
    }
    RunBuild ('Microsoft.Odata.Full.sln')
    RunBuild ('Microsoft.OData.Net35.sln')
    RunBuild ('Microsoft.OData.Net45.sln')
    RunBuild ('Microsoft.OData.Portable45.sln')
    RunBuild ('Microsoft.OData.CodeGen.sln')
    RunBuild ('Microsoft.Odata.E2E.sln')
    Write-Host "Build Done" -ForegroundColor Yellow
    $script:BUILD_END_TIME = Get-Date
}

Function TestProcess
{
    Write-Host '**********Start To Run The Test*********'
    if (Test-Path $TESTLOG)
    {
        rm $TESTLOG
    }
    $script:TEST_START_TIME = Get-Date
    cd $TESTDIR
    RestoringFile -file "$NUGETPACK\EntityFramework.4.3.1\lib\net40\EntityFramework.dll" -target $TESTDIR
    if ($TestType -eq 'Nightly')
    {
        RunTest -title 'NightlyTests' -testdir $NightlyTestSuite
    }
    elseif ($TestType -eq 'Rolling')
    {
        RunTest -title 'RollingTests' -testdir $RollingTestSuite
    }
    else
    {
        Write-Host 'Error : TestType' -ForegroundColor Red
        Cleanup
        exit
    }
    RestoringFile -file "$NUGETPACK\EntityFramework.5.0.0\lib\net40\EntityFramework.dll" -target $TESTDIR
    RunTest -title 'E2ETests' -testdir $E2eTestSuite
    Write-Host "Test Done" -ForegroundColor Yellow
    TestSummary
    $script:TEST_END_TIME = Get-Date
    cd $ENLISTMENT_ROOT
}

Function FxCopProcess
{
    Write-Host '**********Start To FxCop*********'
    & $FXCOP "/f:$ProductDir\Microsoft.Spatial.dll" "/o:$LOGDIR\SpatialFxCopReport.xml"  $DataWebRulesOption $FxCopRulesOptions 1>$null 2>$null
    & $FXCOP "/f:$ProductDir\Microsoft.OData.Core.dll" "/o:$LOGDIR\CoreFxCopReport.xml"  $FxCopRulesOptions 1>$null 2>$null
    & $FXCOP "/f:$ProductDir\Microsoft.OData.Edm.dll" "/o:$LOGDIR\EdmFxCopReport.xml"  $FxCopRulesOptions 1>$null 2>$null
    & $FXCOP "/f:$ProductDir\Microsoft.OData.Client.dll" "/o:$LOGDIR\ClientFxCopReport.xml"  $DataWebRulesOption $FxCopRulesOptions 1>$null 2>$null
    Write-Host "For more information, please open the following test result files:"
    Write-Host "$LOGDIR\SpatialFxCopReport.xml"
    Write-Host "$LOGDIR\CoreFxCopReport.xml"
    Write-Host "$LOGDIR\EdmFxCopReport.xml"
    Write-Host "$LOGDIR\ClientFxCopReport.xml"
    Write-Host "FxCop Done" -ForegroundColor Yellow
}
# Main Process

if (! (Test-Path $LOGDIR))
{
    mkdir $LOGDIR 1>$null
}

if ($TestType -eq 'SkipStrongName')
{
    CleanBeforeScorch 
    BuildProcess
    SkipStrongName
    Exit
}
elseif ($TestType -eq 'DisableSkipStrongName')
{
    CleanBeforeScorch 
    BuildProcess
    DisableSkipStrongName
    Exit
}

CleanBeforeScorch 
BuildProcess
SkipStrongName
TestProcess
FxCopProcess
Cleanup

Write-Host "Build time :`t" , (New-TimeSpan $script:BUILD_START_TIME -end $script:BUILD_END_TIME).TotalSeconds , "`tseconds"
Write-Host "Test time :`t" , (New-TimeSpan $script:TEST_START_TIME -end $script:TEST_END_TIME).TotalSeconds , "`tseconds"
