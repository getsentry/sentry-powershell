BeforeAll {
    $integrationTestScript = "$PSScriptRoot$([IO.Path]::DirectorySeparatorChar)integration-test-script.ps1"
    $integrationTestScriptContent = Get-Content -Raw $integrationTestScript

    $checkOutput = {
        param([string[]] $output, [string[]] $expected)
        # Remove color codes
        $output = $output -replace '\x1b\[[0-9;]*[a-z]', ''
        # Normalize spaces
        $output = $output -replace ' +: +', ': '
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
            'FileName: '
            'Function: <ScriptBlock>'
            'Module: '
            'LineNumber: 1'
            'ColumnNumber: '
            'AbsolutePath: <No file>'
            'ContextLine: '
            'PreContext: {}'
            'PostContext: {}'
            'InApp: True'
            'Vars: {}'
            'FramesOmitted: {}'
            'Package: '
            'Platform: '
            'ImageAddress: '
            'SymbolAddress: '
            'InstructionAddress: '
            'AddressMode: '
            'FunctionId: '
            '----------------'
            'FileName: '
            'Function: <ScriptBlock>'
            'Module: '
            'LineNumber: 14'
            'ColumnNumber: '
            'AbsolutePath: <No file>'
            'ContextLine: '
            'PreContext: {}'
            'PostContext: {}'
            'InApp: True'
            'Vars: {}'
            'FramesOmitted: {}'
            'Package: '
            'Platform: '
            'ImageAddress: '
            'SymbolAddress: '
            'InstructionAddress: '
            'AddressMode: '
            'FunctionId: '
            '----------------'
            'FileName: '
            'Function: '
            'Module: '
            'LineNumber: 14'
            'ColumnNumber: 5'
            'AbsolutePath: '
            "ContextLine: funcA 'throw' 'error'"
            'PreContext: {}'
            'PostContext: {}'
            'InApp: True'
            'Vars: {}'
            'FramesOmitted: {}'
            'Package: '
            'Platform: '
            'ImageAddress: '
            'SymbolAddress: '
            'InstructionAddress: '
            'AddressMode: '
            'FunctionId: '
        )

    }

    AfterEach {
        Pop-Location
    }

    It 'Windows PowerShell' -Skip:(-not $IsWindows) {
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
            'FileName: '
            'Function: <ScriptBlock>'
            'Module: '
            'LineNumber: 1'
            'ColumnNumber: '
            'AbsolutePath: <No file>'
            'ContextLine: '
            'PreContext: {}'
            'PostContext: {}'
            'InApp: True'
            'Vars: {}'
            'FramesOmitted: {}'
            'Package: '
            'Platform: '
            'ImageAddress: '
            'SymbolAddress: '
            'InstructionAddress: '
            'AddressMode: '
            'FunctionId: '
            '----------------'
            'FileName: '
            'Function: <ScriptBlock>'
            'Module: '
            'LineNumber: 14'
            'ColumnNumber: 5'
            "AbsolutePath: $integrationTestScript"
            "ContextLine: funcA 'throw' 'error'"
            'PreContext: {$transport = [RecordingTransport]::new(), StartSentryForEventTests ([ref] $events) ([ref] $transport), , try.}'
            'PostContext: {}, catch, {,     $_ | Out-Sentry | Out-Null.}'
            'InApp: True'
            'Vars: {}'
            'FramesOmitted: {}'
            'Package: '
            'Platform: '
            'ImageAddress: '
            'SymbolAddress: '
            'InstructionAddress: '
            'AddressMode: '
            'FunctionId: '
        )
    }

    AfterEach {
        Pop-Location
    }

    It 'Windows PowerShell' -Skip:(-not $IsWindows) {
        $PSNativeCommandUseErrorActionPreference = $false
        $output = powershell.exe $integrationTestScript
        $checkOutput.Invoke($output, ($expected -replace '\.}', '...}'))
    }

    It 'PowerShell' {
        $PSNativeCommandUseErrorActionPreference = $false
        $output = pwsh -Command $integrationTestScript
        $checkOutput.Invoke($output, $expected)
    }
}
