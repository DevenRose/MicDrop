#requires -Modules Pester
<#
  Emulated tests for MicDrop core logic. No real hardware needed — the Windows
  PnP cmdlets are mocked so each headset "combo" is simulated. Run with:

      Invoke-Pester -Path .\tests

  Each headset below is exercised in three states: mic-on, stereo-locked, and
  disconnected. Add your headset to the -ForEach list and send us a PR/report.
#>

BeforeAll {
    . "$PSScriptRoot\..\MicDrop.Core.ps1"
    function New-FakeHfp {
        param([string]$Name, [string]$Status)
        [pscustomobject]@{
            FriendlyName = "$Name Hands-Free"
            Status       = $Status            # 'OK' = enabled (mic on); else disabled
            InstanceId   = 'BTHHFENUM\BTHHFPAUDIO\8&FAKE&3&97'
            Class        = 'MEDIA'
        }
    }
}

Describe "Headset combo: <Name>" -ForEach @(
    @{ Name = 'TOZO HT3';             Pattern = 'TOZO HT3' }
    @{ Name = 'Apple AirPods Pro';    Pattern = 'AirPods' }
    @{ Name = 'Sony WH-1000XM4';      Pattern = 'WH-1000XM4' }
    @{ Name = 'Bose QuietComfort 45'; Pattern = 'Bose' }
    @{ Name = 'Jabra Elite 85h';      Pattern = 'Jabra' }
    @{ Name = 'Galaxy Buds2 Pro';     Pattern = 'Galaxy Buds' }
) {
    Context 'mic on (HFP enabled)' {
        It 'reports Mic state' {
            Mock Get-PnpDevice { New-FakeHfp -Name $Name -Status 'OK' }
            Get-MicDropState -Pattern $Pattern | Should -Be 'Mic'
        }
        It 'Stereo action disables HFP exactly once' {
            Mock Get-PnpDevice { New-FakeHfp -Name $Name -Status 'OK' }
            Mock Disable-PnpDevice {}
            Set-MicDropStereo -Pattern $Pattern
            Should -Invoke Disable-PnpDevice -Times 1 -Exactly
        }
    }
    Context 'stereo-locked (HFP disabled)' {
        It 'reports Stereo state' {
            Mock Get-PnpDevice { New-FakeHfp -Name $Name -Status 'Error' }
            Get-MicDropState -Pattern $Pattern | Should -Be 'Stereo'
        }
        It 'Mic action enables HFP exactly once' {
            Mock Get-PnpDevice { New-FakeHfp -Name $Name -Status 'Error' }
            Mock Enable-PnpDevice {}
            Set-MicDropMic -Pattern $Pattern
            Should -Invoke Enable-PnpDevice -Times 1 -Exactly
        }
    }
    Context 'disconnected' {
        It 'reports Disconnected' {
            Mock Get-PnpDevice { @() }
            Get-MicDropState -Pattern $Pattern | Should -Be 'Disconnected'
        }
    }
}

Describe 'Pattern targeting with multiple headsets connected' {
    BeforeEach {
        Mock Get-PnpDevice {
            @(
                (New-FakeHfp -Name 'Apple AirPods Pro' -Status 'OK'),
                (New-FakeHfp -Name 'Sony WH-1000XM4'   -Status 'OK')
            )
        }
    }
    It 'selects only the headset matching the pattern' {
        (Get-MicDropHfpDevice -Pattern 'Sony').FriendlyName | Should -Be 'Sony WH-1000XM4 Hands-Free'
    }
    It 'empty/all pattern matches every hands-free device' {
        (Get-MicDropHfpDevice -Pattern '*').Count | Should -Be 2
    }
}

Describe 'Pattern resolution precedence' {
    It 'prefers an explicit override over config' {
        Resolve-MicDropPattern -Override 'Bose' -ConfigPath 'nope.json' | Should -Be 'Bose'
    }
    It 'falls back to * when nothing is set' {
        Resolve-MicDropPattern -Override '' -ConfigPath 'nope.json' | Should -Be '*'
    }
}

Describe 'FxSound endpoint id conversion' {
    It 'strips the SWD\MMDEVAPI prefix and lower-cases the GUID' {
        ConvertTo-MicDropEndpointId -InstanceId 'SWD\MMDEVAPI\{0.0.0.00000000}.{B56632B2-8E96-4C11-A623-8E233B195ADB}' |
            Should -Be '{0.0.0.00000000}.{b56632b2-8e96-4c11-a623-8e233b195adb}'
    }
}

Describe 'Render endpoint selection' {
    BeforeAll {
        function New-FakeEndpoint {
            param([string]$Name, [string]$InstanceId, [string]$Status = 'OK')
            [pscustomobject]@{ FriendlyName = $Name; InstanceId = $InstanceId; Status = $Status; Class = 'AudioEndpoint' }
        }
    }
    It 'ignores capture (mic) endpoints, keeping only render {0.0.0.*}' {
        Mock Get-PnpDevice {
            @(
                (New-FakeEndpoint 'Microphone (TOZO HT3)' 'SWD\MMDEVAPI\{0.0.1.00000000}.{AAAA}'),
                (New-FakeEndpoint 'Headphones (TOZO HT3)' 'SWD\MMDEVAPI\{0.0.0.00000000}.{BBBB}')
            )
        }
        (Get-MicDropRenderEndpoint -Pattern 'TOZO').InstanceId | Should -BeLike '*{0.0.0.00000000}.{BBBB}'
    }
    It 'prefers the A2DP "Headphones" node over the HFP "Headset" node' {
        Mock Get-PnpDevice {
            @(
                (New-FakeEndpoint 'Headset (TOZO HT3) Hands-Free' 'SWD\MMDEVAPI\{0.0.0.00000000}.{HFP}'),
                (New-FakeEndpoint 'Headphones (TOZO HT3)'         'SWD\MMDEVAPI\{0.0.0.00000000}.{A2DP}')
            )
        }
        (Get-MicDropRenderEndpoint -Pattern 'TOZO').InstanceId | Should -BeLike '*{A2DP}'
    }
    It 'returns $null when nothing matches' {
        Mock Get-PnpDevice { @() }
        Get-MicDropRenderEndpoint -Pattern 'TOZO' | Should -BeNullOrEmpty
    }
}

Describe 'FxSound re-pin' {
    BeforeEach {
        $script:settings = Join-Path $TestDrive 'FxSound.settings'
        @'
<?xml version="1.0" encoding="UTF-8"?>
<PROPERTIES>
  <VALUE name="output_device_id" val="{0.0.0.00000000}.{b4aed55f-f797-4e72-b292-41db08f3d0ba}"/>
  <VALUE name="output_device_name" val="Speakers (Senary Audio)"/>
</PROPERTIES>
'@ | Set-Content -Path $script:settings -Encoding UTF8
        Mock Get-PnpDevice {
            @([pscustomobject]@{
                FriendlyName = 'Headphones (TOZO HT3)'
                InstanceId   = 'SWD\MMDEVAPI\{0.0.0.00000000}.{B56632B2-8E96-4C11-A623-8E233B195ADB}'
                Status       = 'OK'; Class = 'AudioEndpoint'
            })
        }
        Mock Get-Process { @() }      # FxSound not running -> no kill/relaunch
        Mock Stop-Process {}
        Mock Start-Process {}
    }
    It 'rewrites the output device to the headset' {
        Set-MicDropFxSound -Pattern 'TOZO' -SettingsPath $script:settings | Should -BeTrue
        $out = Get-Content $script:settings -Raw
        $out | Should -BeLike '*output_device_id" val="{0.0.0.00000000}.{b56632b2-8e96-4c11-a623-8e233b195adb}"*'
        $out | Should -BeLike '*output_device_name" val="Headphones (TOZO HT3)"*'
    }
    It 'is a no-op when already pinned to the headset' {
        Set-MicDropFxSound -Pattern 'TOZO' -SettingsPath $script:settings | Out-Null   # first pins it
        Set-MicDropFxSound -Pattern 'TOZO' -SettingsPath $script:settings | Should -BeFalse
    }
    It 'returns $false when FxSound is not installed (no settings file)' {
        Set-MicDropFxSound -Pattern 'TOZO' -SettingsPath (Join-Path $TestDrive 'missing.settings') | Should -BeFalse
    }
    It 'restarts FxSound via Explorer when it was running' {
        Mock Get-Process { @([pscustomobject]@{ Name = 'FxSound'; Path = 'C:\FxSound\FxSound.exe' }) }
        Mock Stop-Process {}
        Mock Start-Process {}
        Mock Test-Path { $true } -ParameterFilter { $Path -eq 'C:\FxSound\FxSound.exe' }
        Set-MicDropFxSound -Pattern 'TOZO' -SettingsPath $script:settings | Out-Null
        Should -Invoke Stop-Process -Times 1 -Exactly
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $FilePath -eq 'explorer.exe' }
    }
}

Describe 'FxSound restart (wedge recovery)' {
    It 'kills and relaunches FxSound via Explorer when running' {
        Mock Get-Process { @([pscustomobject]@{ Name = 'FxSound'; Path = 'C:\FxSound\FxSound.exe' }) }
        Mock Stop-Process {}
        Mock Start-Process {}
        Mock Test-Path { $true } -ParameterFilter { $Path -eq 'C:\FxSound\FxSound.exe' }
        Restart-MicDropFxSound | Should -BeTrue
        Should -Invoke Stop-Process -Times 1 -Exactly
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $FilePath -eq 'explorer.exe' }
    }
    It 'starts FxSound without killing when it is not already running' {
        Mock Get-Process { @() }
        Mock Stop-Process {}
        Mock Start-Process {}
        Mock Test-Path { $true } -ParameterFilter { $Path -eq 'C:\Program Files\FxSound LLC\FxSound\FxSound.exe' }
        Restart-MicDropFxSound | Should -BeTrue
        Should -Invoke Stop-Process -Times 0 -Exactly
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $FilePath -eq 'explorer.exe' }
    }
    It 'returns $false when the FxSound exe cannot be found' {
        Mock Get-Process { @() }
        Mock Stop-Process {}
        Mock Start-Process {}
        Mock Test-Path { $false }
        Restart-MicDropFxSound | Should -BeFalse
        Should -Invoke Start-Process -Times 0 -Exactly
    }
}

Describe 'FxSound re-pin debounce gate' {
    It 'is not due when no device-change is pending ($null)' {
        Test-MicDropFxRepairDue -LastChange $null -Now (Get-Date) | Should -BeFalse
    }
    It 'is not due for the DateTime.MinValue sentinel' {
        Test-MicDropFxRepairDue -LastChange ([datetime]::MinValue) -Now (Get-Date) | Should -BeFalse
    }
    It 'is not due while still inside the quiet window' {
        $now = Get-Date
        Test-MicDropFxRepairDue -LastChange $now.AddMilliseconds(-300) -Now $now -QuietMs 1200 | Should -BeFalse
    }
    It 'becomes due once the quiet window has elapsed' {
        $now = Get-Date
        Test-MicDropFxRepairDue -LastChange $now.AddMilliseconds(-1500) -Now $now -QuietMs 1200 | Should -BeTrue
    }
}

Describe 'manageFxSound config resolution' {
    It 'defaults to $true when no config exists' {
        Resolve-MicDropManageFxSound -ConfigPath 'nope.json' | Should -BeTrue
    }
    It 'honours an explicit false in config' {
        $cfg = Join-Path $TestDrive 'config.json'
        '{ "manageFxSound": false }' | Set-Content -Path $cfg -Encoding UTF8
        Resolve-MicDropManageFxSound -ConfigPath $cfg | Should -BeFalse
    }
}
