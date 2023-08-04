param(
  [Parameter(Mandatory=$true)][string] $InputPath,
  [Parameter(ValueFromRemainingArguments=$true)][String[]]$tokensToRedact
)

try {
  . $PSScriptRoot\post-build-utils.ps1

  # This has issue when the tool is requiring newer (unreleased) runtime
  #
  # $redactor = Get-Logredactor 
  
  $packageName = 'JanK.BinlogRedactor'

  $dotnetRoot = InitializeDotNetCli -install:$true
  $dotnet = "$dotnetRoot\dotnet.exe"
  $toolList = & "$dotnet" tool list -g

  if ($toolList -like "*$packageName*") {
    & "$dotnet" tool uninstall $packageName -g
  }

  # https://devdiv.pkgs.visualstudio.com/DevDiv/_packaging/JanK/nuget/v3/index.json 
  # internal - General Testing Interanl
  # 'https://pkgs.dev.azure.com/dnceng/7ea9116e-9fac-403d-b258-b31fcf1bb293/_packaging/41d92f4c-3da0-42e5-9736-2eb5905885b9/nuget/v3/index.json'
  # public - General Testing
  # 'https://pkgs.dev.azure.com/dnceng/9ee6d478-d288-47f7-aacc-f6e6d082ae6d/_packaging/f834bf93-0cae-437a-ac42-be249daa930d/nuget/v3/index.json'
  $packageFeed = 'https://pkgs.dev.azure.com/dnceng/9ee6d478-d288-47f7-aacc-f6e6d082ae6d/_packaging/f834bf93-0cae-437a-ac42-be249daa930d/nuget/v3/index.json'

  $toolPath  = "$TempDir\logredactor\$(New-Guid)"
  $verbosity = 'minimal'
  
  New-Item -ItemType Directory -Force -Path $toolPath
  
  Push-Location -Path $toolPath

  try {
    Write-Host "Installing Binlog redactor CLI..."
    Write-Host 'You may need to restart your command window if this is the first dotnet tool you have installed.'
    Write-Host "'$dotnet' new tool-manifest"
    & "$dotnet" new tool-manifest
    Write-Host "'$dotnet' tool install $packageName --prerelease --add-source '$packageFeed' -v $verbosity"
    & "$dotnet" tool install $packageName --prerelease --add-source "$packageFeed" -v $verbosity
  
  

    $optionalParams = [System.Collections.ArrayList]::new()
  
    Foreach ($p in $tokensToRedact)
    {
      $optionalParams.Add("-p") | Out-Null
	  $optionalParams.Add($p) | Out-Null
    }

    & $dotnet redact-binlog -f -r -i $InputPath `
	  @optionalParams

    if ($LastExitCode -ne 0) {
      Write-Host "Problems using Redactor tool. But ingoring them now."
    }
  }
  finally {
    Pop-Location
  }

  Write-Host 'done.'
} 
catch {
  Write-Host $_
  Write-PipelineTelemetryError -Category 'Redactor' -Message "There was an error while trying to redact logs."
  ExitWithExitCode 1
}