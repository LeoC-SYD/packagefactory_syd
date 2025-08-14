# Generate-AppJson.ps1
# This script generates an App.json file for a specific application

param(
    [Parameter(Mandatory = $true)]
    [string]$ApplicationName
)

# Create the directory if it doesn't exist
$appDirectory = Join-Path -Path "d:\m365\packagefactory_syd\packages\App" -ChildPath $ApplicationName
if (-not (Test-Path -Path $appDirectory)) {
    New-Item -Path $appDirectory -ItemType Directory -Force | Out-Null
}

# Create the App.json content
$appJsonContent = @"
{
  "Application": {
    "Name": "$ApplicationName",
    "Version": "1.0.0",
    "Publisher": "Unknown Publisher",
    "InstallCommand": "",
    "UninstallCommand": "",
    "Filter": "",
    "PrePackageCmd": ""
  },
  "PackageInformation": {
    "SetupType": "MSI",
    "SetupFile": "$ApplicationName.msi",
    "Architecture": "x64"
  },
  "DetectionRule": {
    "Type": "Registry",
    "Key": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{GUID}",
    "CheckType": "Exists"
  }
}
"@

# Write the content to the App.json file
$appJsonPath = Join-Path -Path $appDirectory -ChildPath "App.json"
$appJsonContent | Out-File -FilePath $appJsonPath -Encoding utf8 -Force

Write-Output "App.json file created at: $appJsonPath"
