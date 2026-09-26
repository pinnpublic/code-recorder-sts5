$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$archive = Join-Path $dist 'code-recorder-sts5-player.zip'
Compress-Archive -Path (Join-Path $projectRoot 'player') -DestinationPath $archive -Force
Write-Output "Viewer: $archive"
