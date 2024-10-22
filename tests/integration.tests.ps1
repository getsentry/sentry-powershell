BeforeAll {
    $integrationTestScript = "$PSScriptRoot$([IO.Path]::DirectorySeparatorChar)integration-test-script.ps1"
    $integrationTestThrowingScript = "$PSScriptRoot$([IO.Path]::DirectorySeparatorChar)throwingshort.ps1"
    $integrationTestScriptContent = Get-Content -Raw $integrationTestScript

    $checkOutput = {
        param([string[]] $output, [string[]] $expected)
        # Remove color codes
        $output = $output -replace '\x1b\[[0-9;]*[a-z]', ''

        # Remove escape sequences (these appear on macOS and Linux)
        $output = $output -replace '\e\[\?1[hl]', ''

        # Remove warnings
        $output = $output | Where-Object { $_ -notmatch 'WARNING: warning CS1701: Assuming assembly reference' }

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

# These fail when THIS script is executed on Windows PowerShell 5.1 or Poweshell 7.3 or lower with the following error:
# ParserError:
# Line |
#   28 |          $($prop): $value
#      |                  ~
#      | Unexpected token ':' in expression or statement.
#
# It looks like the variable `$integrationTestScriptContent` is expanded in place and then evaluted as an expression.
# Let's just skip these versions. We test Windows PowerShell as the target anyway in a test case.
# And we can live without testing on PowerShell 7.2 & 7.3 because we have tests for 7.4.
Describe 'Out-Sentry captures expected stack traces for command argument' -Skip:(($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -le 3) -or $PSVersionTable.PSEdition -eq 'Desktop') {
    BeforeEach {
        Push-Location "$PSScriptRoot"
        $expected = @(
            '----------------'
            'AbsolutePath: <No file>'
            'Function: <ScriptBlock>'
            'InApp: True'
            'LineNumber: 1'
            '----------------'
            'AbsolutePath: <No file>'
            'Function: <ScriptBlock>'
            'InApp: True'
            'LineNumber: 15'
            '----------------'
            "AbsolutePath: $integrationTestThrowingScript"
            'ColumnNumber: 5'
            'ContextLine:     throw "Short context test"'
            'Function: funcC'
            'InApp: True'
            'LineNumber: 2'
            'PostContext: }'
            'PreContext: function funcC {'
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

Describe 'Out-Sentry captures expected stack traces for piped command' {
    BeforeEach {
        Push-Location "$PSScriptRoot"
        $expected = @(
            '----------------'
            'AbsolutePath: <No file>'
            'Function: <ScriptBlock>'
            'InApp: True'
            'LineNumber: 3'
            '----------------'
            "AbsolutePath: $integrationTestThrowingScript"
            'ColumnNumber: 5'
            'ContextLine:     throw "Short context test"'
            'Function: funcC'
            'InApp: True'
            'LineNumber: 2'
            'PostContext: }'
            'PreContext: function funcC {'
        )
    }

    AfterEach {
        Pop-Location
    }

    It 'Windows PowerShell' -Skip:($env:OS -ne 'Windows_NT') {
        $output = $integrationTestScriptContent | powershell.exe -Command -
        $checkOutput.Invoke($output, $expected)
    }

    It 'PowerShell' {
        $output = $integrationTestScriptContent | pwsh -Command -
        $checkOutput.Invoke($output, $expected)
    }
}

Describe 'Out-Sentry captures expected stack traces for file input' {
    BeforeEach {
        Push-Location "$PSScriptRoot"
        $expected = @(
            '----------------'
            'AbsolutePath: <No file>'
            'Function: <ScriptBlock>'
            'InApp: True'
            'LineNumber: 1'
            '----------------'
            "AbsolutePath: $integrationTestScript"
            'ContextLine:     funcC'
            'Function: <ScriptBlock>'
            'InApp: True'
            'LineNumber: 15'
            'PostContext: }'
            'catch'
            '{'
            '    $_ | Out-Sentry | Out-Null'
            '}'
            'PreContext: $transport = [RecordingTransport]::new()'
            'StartSentryForEventTests ([ref] $events) ([ref] $transport)'
            'try'
            '{'
            '----------------'
            "AbsolutePath: $integrationTestThrowingScript"
            'ColumnNumber: 5'
            'ContextLine:     throw "Short context test"'
            'Function: funcC'
            'InApp: True'
            'LineNumber: 2'
            'PostContext: }'
            'PreContext: function funcC {'
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
