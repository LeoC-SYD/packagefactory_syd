# Generate-AppJsonComplete.ps1

## Vue d'ensemble

Le script `Generate-AppJsonComplete.ps1` est un outil PowerShell conçu pour générer automatiquement des fichiers `App.json` pour le packaging d'applications dans Microsoft Intune. Ces fichiers sont utilisés par le système de packaging pour créer des packages d'application déployables.

Le script offre les fonctionnalités suivantes :
- Génération d'un fichier `App.json` de base avec les paramètres standard
- Intégration avec Azure OpenAI pour compléter automatiquement les détails de l'application
- Support pour différents formats de réponse LLM (Large Language Model)
- Prise en charge des réponses de ChatGPT à partir de fichiers externes

## Prérequis

- PowerShell 5.1 ou supérieur
- Accès à Azure OpenAI Service (facultatif, pour l'enrichissement automatique)

## Format du fichier App.json

Le fichier `App.json` généré respecte la structure suivante :

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
    "IconFile": "https://github.com/aaronparker/icons/raw/main/companyportal/$app name"
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

## Utilisation

### Utilisation de base (sans LLM)

Pour générer un fichier `App.json` de base sans enrichissement LLM :

```powershell
.\Generate-AppJsonComplete.ps1 -ApplicationName "GoogleChrome"
```

### Avec version et éditeur spécifiés

```powershell
.\Generate-AppJsonComplete.ps1 -ApplicationName "GoogleChrome" -Version "115.0.5790.171" -Publisher "Google LLC"
```

### Avec Azure OpenAI (format détaillé)

```powershell
.\Generate-AppJsonComplete.ps1 -ApplicationName "GoogleChrome" `
    -UseAzureOpenAI `
    -AzureOpenAIEndpoint "https://votre-ressource.openai.azure.com/" `
    -AzureOpenAIKey "votre-clé-api" `
    -AzureOpenAIDeploymentName "nom-du-déploiement" `
    -AzureOpenAIApiVersion "2024-12-01-preview"
```

### Utilisation avec un fichier de réponse ChatGPT externe

```powershell
.\Generate-AppJsonComplete.ps1 -ApplicationName "AdobeReader" -ChatGptResponseFile "C:\Temp\AdobeReader_ChatGptResponse.json"
```

## Paramètres

| Paramètre | Description | Obligatoire |
|-----------|-------------|------------|
| ApplicationName | Nom de l'application pour laquelle générer le fichier App.json | Oui |
| Version | Version de l'application (par défaut : "1.0.0") | Non |
| Publisher | Éditeur de l'application (par défaut : "Unknown Publisher") | Non |
| SetupType | Type d'installation (par défaut : "MSI") | Non |
| Architecture | Architecture de l'application (par défaut : "x64") | Non |
| UseAzureOpenAI | Utiliser Azure OpenAI pour améliorer le contenu App.json | Non |
| AzureOpenAIEndpoint | Point de terminaison Azure OpenAI | Non |
| AzureOpenAIKey | Clé API Azure OpenAI | Non |
| AzureOpenAIDeploymentName | Nom du déploiement Azure OpenAI (par défaut : "gpt-4") | Non |
| AzureOpenAIApiVersion | Version de l'API Azure OpenAI (par défaut : "2023-12-01-preview") | Non |
| UseSimplifiedFormat | Utiliser un format simplifié pour les requêtes OpenAI | Non |
| ChatGptResponseFile | Chemin vers un fichier contenant une réponse ChatGPT à utiliser | Non |

## Intégration avec Azure OpenAI

Le script peut utiliser Azure OpenAI pour enrichir automatiquement le contenu du fichier `App.json`. Lorsque l'option `-UseAzureOpenAI` est spécifiée, le script envoie une demande à Azure OpenAI pour obtenir des informations détaillées sur l'application spécifiée.

### Format de requête OpenAI

Le script envoie une requête à Azure OpenAI en demandant des informations sur l'application dans le format JSON spécifié. Le LLM est invité à remplir tous les champs pertinents avec des informations précises pour l'application.

### Gestion des réponses

Le script analyse la réponse d'Azure OpenAI et extrait les informations pertinentes pour créer ou enrichir le fichier `App.json`. Si certaines informations sont manquantes dans la réponse, le script conserve les valeurs par défaut.

## Exemple de flux de travail

1. L'utilisateur exécute le script avec le nom de l'application et les informations d'authentification Azure OpenAI
2. Le script prépare une requête au format approprié et l'envoie à Azure OpenAI
3. Azure OpenAI renvoie des informations détaillées sur l'application au format JSON
4. Le script analyse la réponse et génère un fichier `App.json` dans le répertoire approprié
5. Le fichier `App.json` est prêt à être utilisé pour créer un package d'application pour Intune

## Limitations

- La qualité des informations générées dépend de la connaissance du modèle LLM concernant l'application spécifiée
- Certaines applications peu connues peuvent nécessiter des ajustements manuels après génération
- L'accès à Azure OpenAI est requis pour la fonctionnalité d'enrichissement automatique

## Intégration avec PackageFactory

Ce script s'intègre au workflow de PackageFactory en générant les fichiers `App.json` qui sont ensuite utilisés par `New-Win32Package.ps1` pour créer des packages d'application déployables dans Intune.

## Remarques

- Le script génère un GUID unique pour chaque application, qui est utilisé comme identifiant dans Intune
- Les paramètres de connexion à Azure OpenAI doivent être correctement configurés pour que l'enrichissement automatique fonctionne
- Le modèle Azure OpenAI doit être configuré pour prendre en charge le format de requête utilisé par le script

## Dépannage

### Problèmes de connexion à Azure OpenAI

Si vous rencontrez des problèmes de connexion à Azure OpenAI, vérifiez les points suivants :
- Le point de terminaison et la clé API sont corrects
- Le déploiement spécifié existe dans votre ressource Azure OpenAI
- La version de l'API spécifiée est prise en charge par votre déploiement

### Format de réponse incorrect

Si le script ne parvient pas à analyser la réponse d'Azure OpenAI, cela peut être dû à :
- Un changement dans le format de réponse du modèle
- Des limites de jetons qui tronquent la réponse
- Des paramètres incompatibles avec le modèle utilisé (température, max_tokens, etc.)

Dans ce cas, essayez d'ajuster les paramètres de requête ou utilisez un modèle différent.
