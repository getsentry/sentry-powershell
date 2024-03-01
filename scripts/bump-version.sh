#!/bin/bash
set -euxo pipefail

# Requires powershell: `brew install powershell`
# craft executes this file by convension, passing the new version as the second argument:
pwsh ./scripts/bump-version.ps1 "$2"
