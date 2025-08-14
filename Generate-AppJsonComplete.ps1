# Generate-AppJsonComplete.ps1
# This script generates a comprehensive App.json file for a specific application
# with optional Azure OpenAI enhancement
#
# Examples section with updated examples
# 1. Basic usage (without LLM):
#    .\Generate-AppJsonComplete.ps1 -ApplicationName "MyApplication"
#
# 2. With version and publisher:
#    .\Generate-AppJsonComplete.ps1 -ApplicationName "MyApplication" -Version "2.1.3" -Publisher "Contoso"
#
# 3. With Azure OpenAI enhancement (detailed format):
#    .\Generate-AppJsonComplete.ps1 -ApplicationName "GoogleChrome" -UseAzureOpenAI -AzureOpenAIEndpoint "https://your-resource.openai.azure.com" -AzureOpenAIKey "your-api-key"
#
# 4. With Azure OpenAI using simplified format:
#    .\Generate-AppJsonComplete.ps1 -ApplicationName "MicrosoftTeams" -UseAzureOpenAI -UseSimplifiedFormat -AzureOpenAIEndpoint "https://your-resource.openai.azure.com" -AzureOpenAIKey "your-api-key"
#
# 5. Using a ChatGPT response file:
#    .\Generate-AppJsonComplete.ps1 -ApplicationName "AdobeReader" -ChatGptResponseFile "C:\Temp\AdobeReader_ChatGptResponse.json"

using namespace System.Net.Http
using namespace System.Text
using namespace System.Collections.Generic

param(
    [Parameter(Mandatory = $true)]
    [string]$ApplicationName,
    
    [Parameter(Mandatory = $false)]
    [string]$Version = "1.0.0",
    
    [Parameter(Mandatory = $false)]
    [string]$Publisher = "Unknown Publisher",
    
    [Parameter(Mandatory = $false)]
    [string]$SetupType = "MSI",
    
    [Parameter(Mandatory = $false)]
    [string]$Architecture = "x64",
    
    [Parameter(Mandatory = $false)]
    [switch]$UseAzureOpenAI,
    
    [Parameter(Mandatory = $false)]
    [string]$AzureOpenAIEndpoint,
    
    [Parameter(Mandatory = $false)]
    [string]$AzureOpenAIKey,
    
    [Parameter(Mandatory = $false)]
    [string]$AzureOpenAIDeploymentName = "gpt-4",
    
    [Parameter(Mandatory = $false)]
    [string]$AzureOpenAIApiVersion = "2023-12-01-preview",
    
    [Parameter(Mandatory = $false)]
    [switch]$UseSimplifiedFormat,
    
    [Parameter(Mandatory = $false)]
    [string]$ChatGptResponseFile
)

# Function to get a valid MSI product code (GUID) for a given application
function Get-MsiProductCode {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationName
    )
    
    try {
        # Simply generate a new GUID using the built-in cmdlet
        return (New-Guid).ToString().ToUpper()
    }
    catch {
        Write-Warning "Error generating MSI product code: $_"
        # Return a random GUID as fallback using .NET method
        return [System.Guid]::NewGuid().ToString().ToUpper()
    }
}

# Function to convert simplified ChatGPT manifest to complete format
function ConvertFrom-SimplifiedManifest {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$SimplifiedJson,
        
        [Parameter(Mandatory = $true)]
        [string]$ApplicationName,
        
        [Parameter(Mandatory = $true)]
        [string]$PackageGuid
    )
    
    # Keep all of the structure from the simplified JSON but ensure all fields are present
    # We want to make minimal changes since the format is already expected to match
    
    # Make sure PSPackageFactoryGuid is set
    if (!$SimplifiedJson.Information.PSPackageFactoryGuid) {
        $SimplifiedJson.Information.PSPackageFactoryGuid = $PackageGuid
    }
    
    # Fill in Application.Name if empty
    if ([string]::IsNullOrEmpty($SimplifiedJson.Application.Name)) {
        $SimplifiedJson.Application.Name = $ApplicationName
    }
    
    # Fill in Title if empty
    if ([string]::IsNullOrEmpty($SimplifiedJson.Application.Title)) {
        $SimplifiedJson.Application.Title = $ApplicationName
    }
    
    # Ensure required arrays are initialized
    if ($null -eq $SimplifiedJson.CustomRequirementRule) {
        $SimplifiedJson.CustomRequirementRule = @()
    }
    
    if ($null -eq $SimplifiedJson.Dependencies) {
        $SimplifiedJson.Dependencies = @()
    }
    
    if ($null -eq $SimplifiedJson.Supersedence) {
        $SimplifiedJson.Supersedence = @()
    }
    
    if ($null -eq $SimplifiedJson.Assignments) {
        $SimplifiedJson.Assignments = @()
    }
    
    if ($null -eq $SimplifiedJson.Information.Categories) {
        $SimplifiedJson.Information.Categories = @()
    }
    
    return $SimplifiedJson
}

# Function to parse ChatGPT string response into JSON
function ConvertFrom-ChatGptResponse {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Response,
        
        [Parameter(Mandatory = $true)]
        [string]$ApplicationName
    )
    
    try {
        # Extract JSON part from the response
        $jsonMatch = [regex]::Match($Response, '(?s)\{.*\}')
        if ($jsonMatch.Success) {
            $jsonString = $jsonMatch.Value
            
            # Replace variables with actual values
            $jsonString = $jsonString.Replace('$ApplicationName', $ApplicationName)
            
            # Convert to PSObject
            $jsonObject = $jsonString | ConvertFrom-Json
            return $jsonObject
        }
        else {
            Write-Warning "No valid JSON found in ChatGPT response"
            return $null
        }
    }
    catch {
        Write-Warning "Error parsing ChatGPT response: $_"
        return $null
    }
}

# Function to enhance the App.json with LLM-generated content
# Function to call Azure OpenAI to get app details in the simplified format
function Get-SimplifiedAppDetails {
    param(
        [string]$AppName,
        [string]$Endpoint,
        [string]$ApiKey,
        [string]$DeploymentName,
        [string]$ApiVersion
    )
    
    try {
        # Create HTTP client
        $client = New-Object HttpClient
        $client.DefaultRequestHeaders.Add("api-key", $ApiKey)
        
        # Prepare the request URL
        $requestUrl = "$Endpoint/openai/deployments/$DeploymentName/chat/completions?api-version=$ApiVersion"
        
        # Prepare the prompt
        $systemMessage = @"
You are an AI assistant specialized in software packaging for Microsoft Intune. 
Your task is to provide detailed and accurate information about software applications for packaging.
Focus on providing factual information only. If you're not sure about something, provide generic placeholder values.
"@

        $userMessage = @"
I need information about the application "$AppName" for creating an Intune package.
Return ONLY the following JSON format, populated with correct information for $AppName`:

```json
{
  "Application": {
    "Name": "",
    "Filter": "Get-EvergreenApp -Name \"\" | Where-Object { $_.Language -eq \"\" -and $_.Architecture -eq \"x64\" } | Select-Object -First 1",
    "Title": "",
    "Language": "",
    "Architecture": ""
  },
  "PackageInformation": {
    "SetupType": "",
    "SetupFile": "",
    "Version": "",
    "SourceFolder": "",
    "OutputFolder": "",
    "IconFile": "https://github.com/aaronparker/icons/raw/main/companyportal/$AppName"
  },
  "Information": {
    "DisplayName": "",
    "Description": ".",
    "Publisher": "",
    "InformationURL": "",
    "PrivacyURL": "",
    "FeaturedApp": false,
    "Categories": [],
    "PSPackageFactoryGuid": ""
  },
  "Program": {
    "InstallTemplate": "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\\Install.ps1",
    "InstallExperience": "system",
    "DeviceRestartBehavior": "suppress",
    "AllowAvailableUninstall": false
  },
  "RequirementRule": {
    "MinimumRequiredOperatingSystem": "W10_1809",
    "Architecture": "x64"
  },
  "CustomRequirementRule": [],
  "DetectionRule": [
    {
      "Type": "File",
      "DetectionMethod": "Version",
      "Path": "C:\\Program Files\\**\\..\\",
      "FileOrFolder": "",
      "Operator": "",
      "VersionValue": "",
      "Check32BitOn64System": ""
    }
  ],
  "Dependencies": [],
  "Supersedence": [],
  "Assignments": []
}
```

IMPORTANT: Your response should only contain the JSON object without any additional text, explanations, or formatting.
"@

        # Create request body
        $requestBody = @{
            messages = @(
                @{
                    role = "system"
                    content = $systemMessage
                },
                @{
                    role = "user"
                    content = $userMessage
                }
            )
            # Paramètres temperature et max_tokens retirés pour compatibilité avec tous les modèles
        } | ConvertTo-Json -Depth 10
        
        # Send request
        $content = New-Object StringContent($requestBody, [Encoding]::UTF8, "application/json")
        $response = $client.PostAsync($requestUrl, $content).Result
        
        if ($response.IsSuccessStatusCode) {
            $result = $response.Content.ReadAsStringAsync().Result | ConvertFrom-Json
            return $result.choices[0].message.content
        }
        else {
            Write-Warning "Failed to get app details: $($response.StatusCode) - $($response.ReasonPhrase)"
            return $null
        }
    }
    catch {
        Write-Warning "Error calling Azure OpenAI: $_"
        return $null
    }
}

# Function to enhance app details with more information
function Get-EnhancedAppDetails {
    param(
        [string]$AppName,
        [string]$Endpoint,
        [string]$ApiKey,
        [string]$DeploymentName,
        [string]$ApiVersion
    )
    
    try {
        # Create HTTP client
        $client = New-Object HttpClient
        $client.DefaultRequestHeaders.Add("api-key", $ApiKey)
        
        # Prepare the request URL
        $requestUrl = "$Endpoint/openai/deployments/$DeploymentName/chat/completions?api-version=$ApiVersion"
        
        # Prepare the prompt
        $systemMessage = @"
You are an AI assistant specialized in software packaging for Microsoft Intune. 
Your task is to provide detailed and accurate information about software applications for packaging.
Focus on providing factual information only. If you're not sure about something, provide generic placeholder values.
"@

        $userMessage = @"
I need detailed information about the application "$AppName" for creating an Intune package.
Please provide the following information in the exact JSON format below:

```json
{
  "Application": {
    "Name": "$AppName",
    "Filter": "Get-EvergreenApp -Name \"$AppName\" | Where-Object { $_.Language -eq \"en-US\" -and $_.Architecture -eq \"x64\" } | Select-Object -First 1",
    "Title": "$AppName",
    "Language": "English",
    "Architecture": "x64"
  },
  "PackageInformation": {
    "SetupType": "MSI",
    "SetupFile": "$AppName.msi",
    "Version": "",
    "SourceFolder": "Source",
    "OutputFolder": "Package",
    "IconFile": "https://github.com/aaronparker/icons/raw/main/companyportal/$AppName"
  },
  "Information": {
    "DisplayName": "$AppName",
    "Description": "",
    "Publisher": "",
    "InformationURL": "",
    "PrivacyURL": "",
    "FeaturedApp": false,
    "Categories": [],
    "PSPackageFactoryGuid": ""
  },
  "Program": {
    "InstallTemplate": "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\\Install.ps1",
    "InstallCommand": "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\\Install.ps1",
    "UninstallCommand": "msiexec.exe /X \"{GUID}\" /quiet",
    "InstallExperience": "system",
    "DeviceRestartBehavior": "suppress",
    "AllowAvailableUninstall": false
  },
  "RequirementRule": {
    "MinimumRequiredOperatingSystem": "W10_1809",
    "Architecture": "x64"
  },
  "CustomRequirementRule": [],
  "DetectionRule": [
    {
      "Type": "File",
      "DetectionMethod": "Version",
      "Path": "C:\\Program Files\\$AppName\\",
      "FileOrFolder": "",
      "Operator": "greaterThanOrEqual",
      "VersionValue": "",
      "Check32BitOn64System": "false"
    }
  ],
  "Dependencies": [],
  "Supersedence": [],
  "Assignments": []
}
```

Format your response as valid JSON without any additional text. Replace empty values with appropriate information for $AppName. Update the Filter property with the correct Evergreen filter for this application if known.
"@

        # Create request body
        $requestBody = @{
            messages = @(
                @{
                    role = "system"
                    content = $systemMessage
                },
                @{
                    role = "user"
                    content = $userMessage
                }
            )
            # Paramètres temperature et max_tokens retirés pour compatibilité avec tous les modèles
        } | ConvertTo-Json -Depth 10
        
        # Send request
        $content = New-Object StringContent($requestBody, [Encoding]::UTF8, "application/json")
        $response = $client.PostAsync($requestUrl, $content).Result
        
        if ($response.IsSuccessStatusCode) {
            $result = $response.Content.ReadAsStringAsync().Result | ConvertFrom-Json
            return $result.choices[0].message.content
        }
        else {
            Write-Warning "Failed to get enhanced app details: $($response.StatusCode) - $($response.ReasonPhrase)"
            return $null
        }
    }
    catch {
        Write-Warning "Error calling Azure OpenAI: $_"
        return $null
    }
}

# Function to get Install.json template from LLM
function Get-InstallJsonDetails {
    param(
        [string]$AppName,
        [string]$SetupType,
        [string]$SetupFile,
        [string]$Version,
        [string]$Endpoint,
        [string]$ApiKey,
        [string]$DeploymentName,
        [string]$ApiVersion
    )
    
    try {
        # Create HTTP client
        $client = New-Object HttpClient
        $client.DefaultRequestHeaders.Add("api-key", $ApiKey)
        
        # Prepare the request URL
        $requestUrl = "$Endpoint/openai/deployments/$DeploymentName/chat/completions?api-version=$ApiVersion"
        
        # Prepare the prompt
        $systemMessage = @"
You are an AI assistant specialized in software packaging for Microsoft Intune. 
Your task is to provide information for creating Install.json files that will be used by the installer script.
Focus on providing factual information only. If you're not sure about something, provide generic placeholder values.
"@

        $userMessage = @"
I need an Install.json template for the application "$AppName". This is a $SetupType installer with setup file "$SetupFile" and version "$Version".
Return ONLY the following JSON format, populated with correct information for $AppName`:

```json
{
  "PackageInformation": {
    "SetupType": "$SetupType",
    "SetupFile": "$SetupFile",
    "Version": "$Version"
  },
  "LogPath": "C:\\ProgramData\\Microsoft\\IntuneManagementExtension\\Logs",
  "InstallTasks": {
    "StopProcess": [],
    "ArgumentList": ""
  },
  "PostInstall": {
    "Remove": [],
    "CopyFile": []
  }
}
```

For the "ArgumentList" field, provide the appropriate silent installation command line arguments for this specific application.
If it's an MSI, typically it would be something like: "/package \"#SetupFile\" /quiet /log \"#LogPath\\#LogName.log\""
If it's an EXE, provide the specific silent switches this application uses.

For the "StopProcess" array, include any processes that should be stopped before installation.

IMPORTANT: Your response should only contain the JSON object without any additional text, explanations, or formatting.
"@

        # Create request body
        $requestBody = @{
            messages = @(
                @{
                    role = "system"
                    content = $systemMessage
                },
                @{
                    role = "user"
                    content = $userMessage
                }
            )
            # No temperature or max_tokens parameters for compatibility with all models
        } | ConvertTo-Json -Depth 10
        
        # Send request
        $content = New-Object StringContent($requestBody, [Encoding]::UTF8, "application/json")
        $response = $client.PostAsync($requestUrl, $content).Result
        
        if ($response.IsSuccessStatusCode) {
            $result = $response.Content.ReadAsStringAsync().Result | ConvertFrom-Json
            return $result.choices[0].message.content
        }
        else {
            Write-Warning "Failed to get Install.json details: $($response.StatusCode) - $($response.ReasonPhrase)"
            return $null
        }
    }
    catch {
        Write-Warning "Error calling Azure OpenAI for Install.json: $_"
        return $null
    }
}

# Function to create basic Install.json template
function New-InstallJsonTemplate {
    param(
        [string]$SetupType,
        [string]$SetupFile,
        [string]$Version
    )
    
    # Create a basic Install.json structure
    $installJson = @{
        "PackageInformation" = @{
            "SetupType" = $SetupType
            "SetupFile" = $SetupFile
            "Version" = $Version
        }
        "LogPath" = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
        "InstallTasks" = @{
            "StopProcess" = @()
            "ArgumentList" = ""
        }
        "PostInstall" = @{
            "Remove" = @()
            "CopyFile" = @()
        }
    }
    
    # Set default ArgumentList based on SetupType
    if ($SetupType -eq "MSI") {
        $installJson.InstallTasks.ArgumentList = '/package "#SetupFile" /quiet /log "#LogPath\#LogName.log"'
    }
    elseif ($SetupType -eq "EXE") {
        $installJson.InstallTasks.ArgumentList = '"#SetupFile" /S'
    }
    
    return $installJson
}

# Create the directory if it doesn't exist
$appDirectory = Join-Path -Path "d:\m365\packagefactory_syd\packages\App" -ChildPath $ApplicationName
if (-not (Test-Path -Path $appDirectory)) {
    New-Item -Path $appDirectory -ItemType Directory -Force | Out-Null
}

# Create the Source directory if it doesn't exist
$appSourceDirectory = Join-Path -Path $appDirectory -ChildPath "Source"
if (-not (Test-Path -Path $appSourceDirectory)) {
    New-Item -Path $appSourceDirectory -ItemType Directory -Force | Out-Null
}

# Generate a new GUID for the package
$packageGuid = [guid]::NewGuid().ToString()

# Generate MSI product code if needed
$msiProductCode = $null
if ($SetupType -eq "MSI") {
    $msiProductCode = Get-MsiProductCode -ApplicationName $ApplicationName
    Write-Output "Generated MSI product code: $msiProductCode"
}

# Create the base App.json content with the structure seen in the template
$baseJsonContent = @{
  "Application" = @{
    "Name" = $ApplicationName
    "Filter" = "Get-EvergreenApp -Name ""$ApplicationName"" | Where-Object { `$_.Language -eq ""en-US"" -and `$_.Architecture -eq ""x64"" } | Select-Object -First 1"
    "Title" = $ApplicationName
    "Language" = "English"
    "Architecture" = $Architecture
  }
  "PackageInformation" = @{
    "SetupType" = $SetupType
    "SetupFile" = "$ApplicationName.msi"
    "Version" = $Version
    "SourceFolder" = "Source"
    "OutputFolder" = "Package"
    "IconFile" = "https://github.com/aaronparker/icons/raw/main/companyportal/$ApplicationName"
  }
  "Information" = @{
    "DisplayName" = "$ApplicationName $Version $Architecture"
    "Description" = "Installs $ApplicationName $Version"
    "Publisher" = $Publisher
    "InformationURL" = ""
    "PrivacyURL" = ""
    "FeaturedApp" = $false
    "Categories" = @()
    "PSPackageFactoryGuid" = $packageGuid
  }
  "Program" = @{
    "InstallTemplate" = "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\Install.ps1"
    "InstallExperience" = "system"
    "DeviceRestartBehavior" = "suppress"
    "AllowAvailableUninstall" = $false
  }
  "RequirementRule" = @{
    "MinimumRequiredOperatingSystem" = "W10_1809"
    "Architecture" = $Architecture
  }
  "CustomRequirementRule" = @()
  "DetectionRule" = @(
    @{
      "Type" = "File"
      "DetectionMethod" = "Version"
      "Path" = "C:\Program Files\$ApplicationName\"
      "FileOrFolder" = ""
      "Operator" = "greaterThanOrEqual"
      "VersionValue" = ""
      "Check32BitOn64System" = "false"
    }
  )
  "Dependencies" = @()
  "Supersedence" = @()
  "Assignments" = @()
}


# If Azure OpenAI is enabled, try to enhance the JSON with LLM-generated content
$finalJsonContent = $baseJsonContent

# Process a supplied ChatGPT response file if provided
if (-not [string]::IsNullOrEmpty($ChatGptResponseFile) -and (Test-Path -Path $ChatGptResponseFile)) {
    Write-Output "Reading ChatGPT response from file: $ChatGptResponseFile"
    $chatGptResponse = Get-Content -Path $ChatGptResponseFile -Raw
    
    if ($chatGptResponse) {
        $simplifiedJson = ConvertFrom-ChatGptResponse -Response $chatGptResponse -ApplicationName $ApplicationName
        
        if ($simplifiedJson) {
            Write-Output "Successfully parsed ChatGPT response from file."
            $finalJsonContent = ConvertFrom-SimplifiedManifest -SimplifiedJson $simplifiedJson -ApplicationName $ApplicationName -PackageGuid $packageGuid
            
            # If it's an MSI, adjust the InstallCommand and UninstallCommand fields
            if ($finalJsonContent.PackageInformation.SetupType -eq "MSI") {
                $finalJsonContent.Program.InstallCommand = "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\Install.ps1"
                # Try to extract GUID if present in UninstallCommand
                if ($finalJsonContent.Program.UninstallCommand -match '{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}}') {
                    $guid = [regex]::Match($finalJsonContent.Program.UninstallCommand, '{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}}').Value
                    $finalJsonContent.Program.UninstallCommand = "msiexec.exe /X $guid /quiet"
                } else {
                    $finalJsonContent.Program.UninstallCommand = "msiexec.exe /X {GUID} /quiet"
                }
            } else {
                # For EXE, ensure these fields are populated
                if (-not $finalJsonContent.Program.InstallCommand) {
                    $finalJsonContent.Program.InstallCommand = "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\Install.ps1"
                }
                if (-not $finalJsonContent.Program.UninstallCommand) {
                    $finalJsonContent.Program.UninstallCommand = ".\uninstall.exe /S"
                }
            }
        }
        else {
            Write-Warning "Failed to parse ChatGPT response from file. Using basic template."
        }
    }
}
# Use Azure OpenAI to get app details
elseif ($UseAzureOpenAI) {
    # Validate required parameters for Azure OpenAI
    if ([string]::IsNullOrEmpty($AzureOpenAIEndpoint) -or [string]::IsNullOrEmpty($AzureOpenAIKey)) {
        Write-Warning "Azure OpenAI endpoint and key are required when UseAzureOpenAI is specified."
        Write-Warning "Continuing with basic template..."
    }
    else {
        # If simplified format is requested, use the appropriate function
        if ($UseSimplifiedFormat) {
            Write-Output "Calling Azure OpenAI to get simplified app details..."
            $llmResponse = Get-SimplifiedAppDetails -AppName $ApplicationName -Endpoint $AzureOpenAIEndpoint -ApiKey $AzureOpenAIKey -DeploymentName $AzureOpenAIDeploymentName -ApiVersion $AzureOpenAIApiVersion
            
            if ($llmResponse) {
                Write-Output "Successfully received simplified details from Azure OpenAI."
                $simplifiedJson = ConvertFrom-ChatGptResponse -Response $llmResponse -ApplicationName $ApplicationName
                
                if ($simplifiedJson) {
                    $finalJsonContent = ConvertFrom-SimplifiedManifest -SimplifiedJson $simplifiedJson -ApplicationName $ApplicationName -PackageGuid $packageGuid
                    
                    # If it's an MSI, adjust the InstallCommand and UninstallCommand fields
                    if ($finalJsonContent.PackageInformation.SetupType -eq "MSI") {
                        $finalJsonContent.Program.InstallCommand = "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\Install.ps1"
                        # Try to extract GUID if present in UninstallCommand
                        if ($finalJsonContent.Program.UninstallCommand -match '{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}}') {
                            $guid = [regex]::Match($finalJsonContent.Program.UninstallCommand, '{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}}').Value
                            $finalJsonContent.Program.UninstallCommand = "msiexec.exe /X $guid /quiet"
                        } else {
                            $finalJsonContent.Program.UninstallCommand = "msiexec.exe /X {GUID} /quiet"
                        }
                    } else {
                        # For EXE, ensure these fields are populated
                        if (-not $finalJsonContent.Program.InstallCommand) {
                            $finalJsonContent.Program.InstallCommand = "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\Install.ps1"
                        }
                        if (-not $finalJsonContent.Program.UninstallCommand) {
                            $finalJsonContent.Program.UninstallCommand = ".\uninstall.exe /S"
                        }
                    }
                }
                else {
                    Write-Warning "Failed to parse simplified format from Azure OpenAI. Using basic template."
                }
            }
            else {
                Write-Warning "Failed to get simplified details from Azure OpenAI. Using basic template."
            }
        }
        # Otherwise use the enhanced detailed format
        else {
            Write-Output "Calling Azure OpenAI to enhance the App.json..."
            $llmResponse = Get-EnhancedAppDetails -AppName $ApplicationName -Endpoint $AzureOpenAIEndpoint -ApiKey $AzureOpenAIKey -DeploymentName $AzureOpenAIDeploymentName -ApiVersion $AzureOpenAIApiVersion
            
            if ($llmResponse) {
                Write-Output "Successfully received enhanced details from Azure OpenAI."
                try {
                    # Parse the JSON response
                    $enhancedData = $llmResponse | ConvertFrom-Json
                    
                    # Update with the enhanced data
                    $finalJsonContent.Application.Name = $enhancedData.Application.Name
                    $finalJsonContent.Application.Filter = $enhancedData.Application.Filter
                    $finalJsonContent.Application.Title = $enhancedData.Application.Title
                    $finalJsonContent.Application.Language = $enhancedData.Application.Language
                    $finalJsonContent.Application.Architecture = $enhancedData.Application.Architecture
                    
                    $finalJsonContent.PackageInformation.SetupType = $enhancedData.PackageInformation.SetupType
                    $finalJsonContent.PackageInformation.SetupFile = $enhancedData.PackageInformation.SetupFile
                    $finalJsonContent.PackageInformation.Version = $enhancedData.PackageInformation.Version
                    $finalJsonContent.PackageInformation.SourceFolder = $enhancedData.PackageInformation.SourceFolder
                    $finalJsonContent.PackageInformation.OutputFolder = $enhancedData.PackageInformation.OutputFolder
                    $finalJsonContent.PackageInformation.IconFile = $enhancedData.PackageInformation.IconFile
                    
                    $finalJsonContent.Information.DisplayName = $enhancedData.Information.DisplayName
                    $finalJsonContent.Information.Description = $enhancedData.Information.Description
                    $finalJsonContent.Information.Publisher = $enhancedData.Information.Publisher
                    $finalJsonContent.Information.InformationURL = $enhancedData.Information.InformationURL
                    $finalJsonContent.Information.PrivacyURL = $enhancedData.Information.PrivacyURL
                    $finalJsonContent.Information.FeaturedApp = $enhancedData.Information.FeaturedApp
                    $finalJsonContent.Information.Categories = $enhancedData.Information.Categories
                    $finalJsonContent.Information.PSPackageFactoryGuid = $packageGuid  # Keep original GUID
                    
                    $finalJsonContent.Program.InstallTemplate = $enhancedData.Program.InstallTemplate
                    
                    # For MSI, we set standard values for InstallCommand and UninstallCommand
                    if ($enhancedData.PackageInformation.SetupType -eq "MSI") {
                        $finalJsonContent.Program.InstallCommand = "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\Install.ps1"
                        # If we have a GUID, use it, otherwise use a placeholder
                        if ($enhancedData.Program.UninstallCommand -match '{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}}') {
                            $guid = [regex]::Match($enhancedData.Program.UninstallCommand, '{[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}}').Value
                            $finalJsonContent.Program.UninstallCommand = "msiexec.exe /X $guid /quiet"
                        } elseif ($msiProductCode) {
                            $finalJsonContent.Program.UninstallCommand = "msiexec.exe /X {$msiProductCode} /quiet"
                        } else {
                            $finalJsonContent.Program.UninstallCommand = "msiexec.exe /X {GUID} /quiet"
                        }
                    } else {
                        $finalJsonContent.Program.InstallCommand = $enhancedData.Program.InstallCommand
                        $finalJsonContent.Program.UninstallCommand = $enhancedData.Program.UninstallCommand
                    }
                    
                    $finalJsonContent.Program.InstallExperience = $enhancedData.Program.InstallExperience
                    $finalJsonContent.Program.DeviceRestartBehavior = $enhancedData.Program.DeviceRestartBehavior
                    $finalJsonContent.Program.AllowAvailableUninstall = $enhancedData.Program.AllowAvailableUninstall
                    
                    $finalJsonContent.RequirementRule = $enhancedData.RequirementRule
                    $finalJsonContent.CustomRequirementRule = $enhancedData.CustomRequirementRule
                    $finalJsonContent.DetectionRule = $enhancedData.DetectionRule
                    $finalJsonContent.Dependencies = $enhancedData.Dependencies
                    $finalJsonContent.Supersedence = $enhancedData.Supersedence
                    $finalJsonContent.Assignments = $enhancedData.Assignments
                    
                    Write-Output "Successfully enhanced App.json with LLM data."
                }
                catch {
                    Write-Warning "Error parsing LLM response: $_"
                    Write-Warning "Using basic template instead."
                }
            }
            else {
                Write-Warning "Failed to get enhanced details from Azure OpenAI. Using basic template."
            }
        }
    }
}

# Convert to JSON and write to the App.json file
$appJsonPath = Join-Path -Path $appDirectory -ChildPath "App.json"
$finalJsonContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $appJsonPath -Encoding utf8 -Force

Write-Output "App.json file created at: $appJsonPath"

# Save the raw LLM response for reference if available
# if (($UseAzureOpenAI -or $ChatGptResponseFile) -and $llmResponse) {
#     $llmResponsePath = Join-Path -Path $appDirectory -ChildPath "LlmResponse.json"
#     # $llmResponse | Out-File -FilePath $llmResponsePath -Encoding utf8 -Force
#     # Write-Output "LLM response saved at: $llmResponsePath"
# }

# Now create the Install.json file
$setupFile = $finalJsonContent.PackageInformation.SetupFile
$setupType = $finalJsonContent.PackageInformation.SetupType
$appVersion = $finalJsonContent.PackageInformation.Version

# Set InstallCommand and UninstallCommand if they don't exist yet
if (-not $finalJsonContent.Program.InstallCommand) {
    $finalJsonContent.Program.InstallCommand = "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\Install.ps1"
}

if (-not $finalJsonContent.Program.UninstallCommand) {
    if ($setupType -eq "MSI") {
        if ($msiProductCode) {
            $finalJsonContent.Program.UninstallCommand = "msiexec.exe /X {$msiProductCode} /quiet"
        } else {
            $finalJsonContent.Program.UninstallCommand = "msiexec.exe /X {GUID} /quiet"
        }
    } else {
        $finalJsonContent.Program.UninstallCommand = ".\uninstall.exe /S"
    }
}

# Add other standard properties if they're missing
if (-not $finalJsonContent.Program.InstallExperience) {
    $finalJsonContent.Program.InstallExperience = "system"
}
if (-not $finalJsonContent.Program.DeviceRestartBehavior) {
    $finalJsonContent.Program.DeviceRestartBehavior = "suppress"
}
if (-not [bool]($finalJsonContent.Program.PSObject.Properties.Match("AllowAvailableUninstall"))) {
    $finalJsonContent.Program.AllowAvailableUninstall = $false
}

# Create Install.json - first try with LLM if Azure OpenAI is enabled
if ($UseAzureOpenAI -and -not [string]::IsNullOrEmpty($AzureOpenAIEndpoint) -and -not [string]::IsNullOrEmpty($AzureOpenAIKey)) {
    Write-Output "Calling Azure OpenAI to get Install.json details..."
    $installLlmResponse = Get-InstallJsonDetails -AppName $ApplicationName -SetupType $setupType -SetupFile $setupFile -Version $appVersion -Endpoint $AzureOpenAIEndpoint -ApiKey $AzureOpenAIKey -DeploymentName $AzureOpenAIDeploymentName -ApiVersion $AzureOpenAIApiVersion
    
    if ($installLlmResponse) {
        Write-Output "Successfully received Install.json details from Azure OpenAI."
        try {
            # Extract JSON from the response
            $jsonMatch = [regex]::Match($installLlmResponse, '(?s)\{.*\}')
            if ($jsonMatch.Success) {
                $installJsonContent = $jsonMatch.Value | ConvertFrom-Json
            }
            else {
                # If no JSON found, use the whole response
                $installJsonContent = $installLlmResponse | ConvertFrom-Json
            }
        }
        catch {
            Write-Warning "Error parsing Install.json LLM response: $_"
            Write-Warning "Creating basic Install.json template instead."
            $installJsonContent = New-InstallJsonTemplate -SetupType $setupType -SetupFile $setupFile -Version $appVersion
        }
    }
    else {
        Write-Warning "Failed to get Install.json details from Azure OpenAI. Creating basic template."
        $installJsonContent = New-InstallJsonTemplate -SetupType $setupType -SetupFile $setupFile -Version $appVersion
    }
}
else {
    # Create a basic Install.json if not using Azure OpenAI
    Write-Output "Creating basic Install.json template..."
    $installJsonContent = New-InstallJsonTemplate -SetupType $setupType -SetupFile $setupFile -Version $appVersion
}

# Save the Install.json file
$installJsonPath = Join-Path -Path $appSourceDirectory -ChildPath "Install.json"
$installJsonContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $installJsonPath -Encoding utf8 -Force

Write-Output "Install.json file created at: $installJsonPath"
