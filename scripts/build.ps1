param(
    [string]$StsHome = 'C:\dev\sts-5.2.0.RELEASE',
    [string]$JdkHome = 'C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$classes = Join-Path $projectRoot 'build/classes'
$dist = Join-Path $projectRoot 'dist'
$artifacts = Join-Path $projectRoot 'build/artifacts'
if (!(Test-Path (Join-Path $StsHome 'plugins'))) { throw 'Eclipse plugins folder not found. Specify -StsHome.' }
if (!(Test-Path (Join-Path $JdkHome 'bin/javac.exe'))) { throw 'JDK not found. Specify -JdkHome.' }
New-Item -ItemType Directory -Force -Path $classes,$dist,$artifacts | Out-Null
$sources = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'plugin/src') -Recurse -Filter '*.java' | ForEach-Object { $_.FullName })
& (Join-Path $JdkHome 'bin/javac.exe') --release 21 -encoding UTF-8 -classpath (Join-Path $StsHome 'plugins/*') -d $classes $sources
if ($LASTEXITCODE -ne 0) { throw 'Java compilation failed' }
$jar = Join-Path $artifacts 'dev.coderecorder_0.5.1.jar'
& (Join-Path $JdkHome 'bin/jar.exe') --create --file $jar --manifest (Join-Path $projectRoot 'plugin/META-INF/MANIFEST.MF') -C $classes . -C (Join-Path $projectRoot 'plugin') plugin.xml
if ($LASTEXITCODE -ne 0) { throw 'JAR packaging failed' }
Write-Output "Built: $jar"
