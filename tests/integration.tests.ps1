BeforeAll {
    $integrationTestScript = "$PSScriptRoot$([IO.Path]::DirectorySeparatorChar)integration-test-script.ps1"
    $integrationTestScriptContent = Get-Content -Raw $integrationTestScript

    $checkOutput = {
        param([string[]] $output, [string[]] $expected)
        # Remove empty lines
        $output = $output | Where-Object { $_ -ne '' }

        # Print out so that we can compare the whole output if the test fails
        $output | Write-Host

        for ($i = 0; $i -lt $expected.Count -and $i -lt $output.Count; $i++)
        {
            $output[$i] | Should -Be $expected[$i] -Because "Output line $i"
        }
        $output.Count | Should -Be $expected.Count
    }
}

Describe 'Out-Sentry captures expected stack traces for command input' {
    BeforeEach {
        Push-Location "$PSScriptRoot"
        $expected = @(
            '----------------'
            'AbsolutePath: <No file>'
            'AddressMode: '
            'ColumnNumber: '
            'ContextLine: '
            'FileName: '
            'FramesOmitted: '
            'Function: <ScriptBlock>'
            'FunctionId: '
            'ImageAddress: '
            'InApp: True'
            'InstructionAddress: '
            'LineNumber: 1'
            'Module: '
            'Package: '
            'Platform: '
            'PostContext: '
            'PreContext: '
            'SymbolAddress: '
            'Vars: '
            '----------------'
            'AbsolutePath: <No file>'
            'AddressMode: '
            'ColumnNumber: '
            'ContextLine: '
            'FileName: '
            'FramesOmitted: '
            'Function: <ScriptBlock>'
            'FunctionId: '
            'ImageAddress: '
            'InApp: True'
            'InstructionAddress: '
            'LineNumber: 14'
            'Module: '
            'Package: '
            'Platform: '
            'PostContext: '
            'PreContext: '
            'SymbolAddress: '
            'Vars: '
            '----------------'
            'AbsolutePath: '
            'AddressMode: '
            'ColumnNumber: 5'
            "ContextLine:     funcA 'throw' 'error'"
            'FileName: '
            'FramesOmitted: '
            'Function: '
            'FunctionId: '
            'ImageAddress: '
            'InApp: True'
            'InstructionAddress: '
            'LineNumber: 14'
            'Module: '
            'Package: '
            'Platform: '
            'PostContext: '
            'PreContext: '
            'SymbolAddress: '
            'Vars: '
        )

    }

    AfterEach {
        Pop-Location
    }

    It 'Windows PowerShell' -Skip:($env:OS -ne 'Windows_NT') {
        $output = powershell.exe -Command "& {$integrationTestScriptContent}" -ErrorAction Continue
        $checkOutput.Invoke($output, $expected)
    }

    It 'PowerShell' {
        $output = pwsh -Command "& {$integrationTestScriptContent}" -ErrorAction Continue
        $checkOutput.Invoke($output, $expected)
    }
}

Describe 'Out-Sentry captures expected stack traces for file input' {
    BeforeEach {
        Push-Location "$PSScriptRoot"
        $expected = @(
            '----------------'
            'AbsolutePath: <No file>'
            'AddressMode: '
            'ColumnNumber: '
            'ContextLine: '
            'FileName: '
            'FramesOmitted: '
            'Function: <ScriptBlock>'
            'FunctionId: '
            'ImageAddress: '
            'InApp: True'
            'InstructionAddress: '
            'LineNumber: 1'
            'Module: '
            'Package: '
            'Platform: '
            'PostContext: '
            'PreContext: '
            'SymbolAddress: '
            'Vars: '
            '----------------'
            "AbsolutePath: $integrationTestScript"
            'AddressMode: '
            'ColumnNumber: 5'
            "ContextLine:     funcA 'throw' 'error'"
            'FileName: '
            'FramesOmitted: '
            'Function: <ScriptBlock>'
            'FunctionId: '
            'ImageAddress: '
            'InApp: True'
            'InstructionAddress: '
            'LineNumber: 14'
            'Module: '
            'Package: '
            'Platform: '
            'PostContext: }'
            'catch'
            '{'
            '    $_ | Out-Sentry | Out-Null'
            '}'
            'PreContext: $transport = [RecordingTransport]::new()'
            'StartSentryForEventTests ([ref] $events) ([ref] $transport)'
            'try'
            '{'
            'SymbolAddress: '
            'Vars: '
        )
    }

    AfterEach {
        Pop-Location
    }

    It 'Windows PowerShell' -Skip:($env:OS -ne 'Windows_NT') {
        $PSNativeCommandUseErrorActionPreference = $false
        $output = powershell.exe $integrationTestScript
        $checkOutput.Invoke($output, $expected)
    }

    It 'PowerShell' {
        $PSNativeCommandUseErrorActionPreference = $false
        $output = pwsh -Command $integrationTestScript
        $checkOutput.Invoke($output, $expected)
    }
}
