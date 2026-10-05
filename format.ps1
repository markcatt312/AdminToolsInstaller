$lines = Get-Content 'l:\AdminToolsInstaller\AdminToolManager.ps1' | Where-Object { $_.Trim() -ne '' }
$output = @()

for ($i=0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $trimmed = $line.Trim()
    
    # Blank line before functions, region, endregion
    if ($output.Count -gt 0 -and $trimmed -match '^(function |#region|#endregion|param\s*\()') {
        if ($output[-1].Trim() -ne '') {
            $output += ""
        }
    }
    
    $output += $line
    
    # Blank line after comment block closing
    if ($trimmed -match '^#>') {
        $output += ""
    }
}

Set-Content -Path 'l:\AdminToolsInstaller\AdminToolManager.ps1' -Value $output
$formatted = Invoke-Formatter -ScriptDefinition (Get-Content 'l:\AdminToolsInstaller\AdminToolManager.ps1' -Raw)
Set-Content -Path 'l:\AdminToolsInstaller\AdminToolManager.ps1' -Value $formatted
