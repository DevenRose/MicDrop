param([string]$BuildDirectory='X:\Downloads\MicDrop-EQ-2026-10-05\responsive-build')
$ErrorActionPreference='Stop'
$configDirectory='C:\Program Files\EqualizerAPO\config'
$stageDirectory='X:\Downloads\MicDrop-EQ-2026-10-05'
if(Get-Process -Name Peace,MicDropEqualizer -ErrorAction SilentlyContinue){throw 'An equalizer interface is running. Do not interrupt or replace it without exact approval.'}
if(Test-Path -LiteralPath (Join-Path $configDirectory 'MicDropEqualizer.exe')){throw 'MicDrop Equalizer already exists; this first-install script will not overwrite it.'}
$configPath=Join-Path $configDirectory 'config.txt'
$before=[IO.File]::ReadAllText($configPath)
$matches=[regex]::Matches($before,'(?im)^Include:\s*peace\.txt\s*$')
if($matches.Count -ne 1){throw 'Expected exactly one Peace include; refusing an unexpected configuration.'}
$after=[regex]::Replace($before,'(?im)^Include:\s*peace\.txt\s*$','Include: micdrop-eq.txt')
$backupDirectory=Join-Path $stageDirectory ('before-responsive-equalizer-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backupDirectory | Out-Null
Copy-Item -LiteralPath $configDirectory -Destination (Join-Path $backupDirectory 'config') -Recurse
$programDirectory=Join-Path ([Environment]::GetFolderPath('Programs')) 'Equalizer APO'
$oldShortcut=Join-Path $programDirectory 'Peace Equalizer.lnk'
if(Test-Path -LiteralPath $oldShortcut){Copy-Item -LiteralPath $oldShortcut -Destination $backupDirectory}
Copy-Item -LiteralPath (Join-Path $BuildDirectory 'MicDropEqualizer.exe') -Destination $configDirectory
$appPath=Join-Path $configDirectory 'MicDropEqualizer.exe'
$initProcess=Start-Process -FilePath $appPath -ArgumentList '--initialize' -WindowStyle Hidden -PassThru
if(-not $initProcess.WaitForExit(15000)){throw 'Initialization did not finish; configuration has not been switched.'}
if(-not (Test-Path -LiteralPath (Join-Path $configDirectory 'micdrop-eq.txt'))){throw 'Initialization did not create its EQ file; configuration has not been switched.'}
if(-not (Test-Path -LiteralPath (Join-Path $configDirectory 'micdrop-initialized.txt'))){throw 'Initialization did not verify the headset; configuration has not been switched.'}
[IO.File]::WriteAllText($configPath,$after,[Text.UTF8Encoding]::new($false))
$shell=New-Object -ComObject WScript.Shell
$shortcutPath=Join-Path $programDirectory 'MicDrop Equalizer.lnk'
$shortcut=$shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath=$appPath
$shortcut.WorkingDirectory=$configDirectory
$shortcut.Description='Resizable TOZO equalizer with standard bands, tray and taskbar icons'
$shortcut.Save()
if(Test-Path -LiteralPath $oldShortcut){Remove-Item -LiteralPath $oldShortcut}
$result=[ordered]@{Installed=$appPath;Shortcut=$shortcutPath;Backup=$backupDirectory;PreviousConfig=$before;ActiveConfig=$after;OriginalPeacePreserved=(Test-Path -LiteralPath (Join-Path $configDirectory 'Peace.exe'));ServicesRestarted=$false}
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $stageDirectory 'responsive-install.json') -Encoding UTF8
$result | ConvertTo-Json -Depth 4
