param (
    $verbosity = 'minimal',
    $toolpath = $null
)

. $PSScriptRoot\tools.ps1

function InstallRedactorCli ($toolpath) {
  $packageName = 'JanK.BinlogRedactor'

  $dotnetRoot = InitializeDotNetCli -install:$true
  $dotnet = "$dotnetRoot\dotnet.exe"
  $toolList = & "$dotnet" tool list -g

  if ($toolList -like "*$packageName*") {
    & "$dotnet" tool uninstall $packageName -g
  }

  # https://devdiv.pkgs.visualstudio.com/DevDiv/_packaging/em-tools/nuget/v3/index.json
  $packageFeed = 'https://pkgs.dev.azure.com/dnceng/7ea9116e-9fac-403d-b258-b31fcf1bb293/_packaging/41d92f4c-3da0-42e5-9736-2eb5905885b9/nuget/v3/index.json'

  Write-Host "Installing Binlog redactor CLI..."
  Write-Host 'You may need to restart your command window if this is the first dotnet tool you have installed.'
  if (-not $toolpath) {
    Write-Host "'$dotnet' tool install $packageName --prerelease --add-source '$packageFeed' -v $verbosity -g"
    & "$dotnet" tool install $packageName --prerelease --add-source "$packageFeed" -v $verbosity -g
  }else {
    Write-Host "'$dotnet' tool install $packageName --prerelease --add-source '$packageFeed' -v $verbosity --tool-path '$toolpath'"
    & "$dotnet" tool install $packageName --prerelease --add-source "$packageFeed" -v $verbosity --tool-path "$toolpath"
  }
}

try {
  InstallRedactorCli $toolpath
}
catch {
  Write-Host $_.ScriptStackTrace
  Write-PipelineTelemetryError -Category 'Redactor' -Message $_
  ExitWithExitCode 1
}