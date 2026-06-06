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
