param([string]$OutputDirectory='X:\Downloads\MicDrop-EQ-2026-10-05\responsive-build')
$ErrorActionPreference='Stop'
$framework='C:\Windows\Microsoft.NET\Framework64\v4.0.30319'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$arguments=@('/nologo','/target:winexe',('/out:'+ (Join-Path $OutputDirectory 'MicDropEqualizer.exe')),
 '/r:System.Xaml.dll','/r:System.Runtime.Serialization.dll','/r:System.Windows.Forms.dll','/r:System.Drawing.dll',
 ('/r:'+ $framework+'\WPF\PresentationFramework.dll'),('/r:'+ $framework+'\WPF\PresentationCore.dll'),
 ('/r:'+ $framework+'\WPF\WindowsBase.dll'),(Join-Path $PSScriptRoot 'MicDropEqualizer.cs'))
& (Join-Path $framework 'csc.exe') @arguments
if($LASTEXITCODE -ne 0){throw 'Equalizer compilation failed'}
Get-FileHash -LiteralPath (Join-Path $OutputDirectory 'MicDropEqualizer.exe') -Algorithm SHA256
