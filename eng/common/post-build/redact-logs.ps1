param(
  [Parameter(Mandatory=$true)][string] $InputPath,
  [Parameter(ValueFromRemainingArguments=$true)][String[]]$tokensToRedact
)

try {
  . $PSScriptRoot\post-build-utils.ps1

  $redactor = Get-Logredactor 

  $optionalParams = [System.Collections.ArrayList]::new()
  
  Foreach ($p in $tokensToRedact)
  {
    $optionalParams.Add("-p") | Out-Null
	$optionalParams.Add($p) | Out-Null
  }

  & $redactor -f -r -i $InputPath `
	@optionalParams

  if ($LastExitCode -ne 0) {
    Write-Host "Problems using Redactor tool. But ingoring them now."
  }

  Write-Host 'done.'
} 
catch {
  Write-Host $_
  Write-PipelineTelemetryError -Category 'Redactor' -Message "There was an error while trying to redact logs."
  ExitWithExitCode 1
}