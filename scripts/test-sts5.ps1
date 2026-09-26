param(
    [string]$StsHome = 'C:\dev\sts-5.2.0.RELEASE',
    [string]$RuntimeHome = 'C:\dev\sts-5.2.0.RELEASE\plugins\org.eclipse.justj.openjdk.hotspot.jre.full.win32.x86_64_25.0.3.v20260502-0818\jre',
    [string]$JdkHome = 'C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot',
    [switch]$Installed
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runRoot = Join-Path $projectRoot ('build/sts5-test-' + [guid]::NewGuid().ToString('N'))
$config = Join-Path $runRoot 'configuration'
$simple = Join-Path $config 'org.eclipse.equinox.simpleconfigurator'
$classes = Join-Path $runRoot 'classes'
New-Item -ItemType Directory -Force -Path $simple,$classes | Out-Null
$classpath = (Join-Path $StsHome 'plugins/*') + ';' + (Join-Path $projectRoot 'build/artifacts/dev.coderecorder_0.5.2.jar')
$sources = @(Get-ChildItem (Join-Path $projectRoot 'tests/eclipse/src') -Recurse -Filter '*.java' | ForEach-Object { $_.FullName })
& (Join-Path $JdkHome 'bin/javac.exe') --release 21 -encoding UTF-8 -classpath $classpath -d $classes $sources
if ($LASTEXITCODE -ne 0) { throw 'Integration test compilation failed' }
$testJar = Join-Path $runRoot 'dev.coderecorder.tests_0.1.0.jar'
& (Join-Path $JdkHome 'bin/jar.exe') --create --file $testJar --manifest (Join-Path $projectRoot 'tests/eclipse/META-INF/MANIFEST.MF') -C $classes . -C (Join-Path $projectRoot 'tests/eclipse') plugin.xml
if ($LASTEXITCODE -ne 0) { throw 'Test JAR failed' }
function FileUri([string]$path) { return ([uri]$path).AbsoluteUri }
$bundleLines = Get-Content (Join-Path $StsHome 'configuration/org.eclipse.equinox.simpleconfigurator/bundles.info') | Where-Object { $_ -notmatch '^dev\.coderecorder\.tests,' -and ($Installed -or $_ -notmatch '^dev\.coderecorder,') } | ForEach-Object {
    if ($_.StartsWith('#')) { $_ } else {
        $parts = $_.Split(',')
        $parts[2] = FileUri (Join-Path $StsHome $parts[2])
        $parts -join ','
    }
}
if (!$Installed) { $bundleLines += 'dev.coderecorder,0.5.2,' + (FileUri (Join-Path $projectRoot 'build/artifacts/dev.coderecorder_0.5.2.jar')) + ',4,false' }
$bundleLines += 'dev.coderecorder.tests,0.1.0,' + (FileUri $testJar) + ',4,false'
[IO.File]::WriteAllLines((Join-Path $simple 'bundles.info'), $bundleLines, [Text.UTF8Encoding]::new($false))
$framework = Get-ChildItem (Join-Path $StsHome 'plugins') -Filter 'org.eclipse.osgi_*.jar' | Select-Object -First 1
$configurator = Get-ChildItem (Join-Path $StsHome 'plugins') -Filter 'org.eclipse.equinox.simpleconfigurator_*.jar' | Select-Object -First 1
$launcher = Get-ChildItem (Join-Path $StsHome 'plugins') -Filter 'org.eclipse.equinox.launcher_*.jar' | Select-Object -First 1
$settings = @(
    'osgi.bundles=reference:' + (FileUri $configurator.FullName) + '@1:start'
    'osgi.bundles.defaultStartLevel=4'
    'org.eclipse.equinox.simpleconfigurator.configUrl=' + (FileUri (Join-Path $simple 'bundles.info'))
    'osgi.framework=' + (FileUri $framework.FullName)
    'eclipse.application=dev.coderecorder.tests.run'
    'org.eclipse.update.reconcile=false'
    'osgi.configuration.cascaded=false'
)
[IO.File]::WriteAllLines((Join-Path $config 'config.ini'), $settings, [Text.UTF8Encoding]::new($false))
$arguments = @(
    '-Drecorder.test.output="' + $runRoot + '"'
    '-Xmx1024m'
    '-jar "' + $launcher.FullName + '"'
    '-configuration "' + $config + '"'
    '-data "' + (Join-Path $runRoot 'workspace') + '"'
    '-application dev.coderecorder.tests.run'
    '-nosplash -consoleLog -clean'
)
$process = Start-Process -FilePath (Join-Path $RuntimeHome 'bin/java.exe') -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runRoot 'stdout.log') -RedirectStandardError (Join-Path $runRoot 'stderr.log')
Write-Output "PID=$($process.Id)"
Write-Output "OUTPUT=$runRoot"

if (!$process.WaitForExit(60000)) { throw "Eclipse test did not exit within 60 seconds. Inspect $runRoot" }
if (Test-Path (Join-Path $runRoot 'FAIL.txt')) { throw (Get-Content (Join-Path $runRoot 'FAIL.txt') -Raw) }
if (!(Test-Path (Join-Path $runRoot 'PASS.txt'))) { throw "Eclipse test did not report success. Inspect $runRoot" }
Get-Content (Join-Path $runRoot 'PASS.txt')
& node (Join-Path $projectRoot 'tests/verify-export.cjs') $runRoot
if ($LASTEXITCODE -ne 0) { throw 'Export verification failed' }
