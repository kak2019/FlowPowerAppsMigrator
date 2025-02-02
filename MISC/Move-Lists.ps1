[CmdletBinding()]
param (
    [Parameter()]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Export', 'Import')]
    [string]$MigrationType,

    [Parameter(Mandatory = $false)]
    [string]$SourceSite,

    [Parameter(Mandatory = $false)]
    [string]$TargetSite     
)


#-----------------------------------------------------------------------
# Script lets you migrate one or more SharePoint lists from source site
# To destination site
# Denis Molodtsov, 2021
#-----------------------------------------------------------------------

$ErrorActionPreference = "Stop"

Clear-Host

Write-Host $Path -ForegroundColor Green

Set-Location $Path
. .\MISC\PS-Forms.ps1

Get-ChildItem -Recurse | Unblock-File
# Legacy PowerShell PnP Module is used because the new one has a critical bug
Import-Module (Get-ChildItem -Recurse -Filter "*.psd1").FullName -DisableNameChecking

if ($MigrationType -eq "Export") {
    Get-ChildItem *.xml | ForEach-Object { Remove-Item -Path $_.FullName }
    Get-ChildItem *.json | ForEach-Object { Remove-Item -Path $_.FullName }
    $lists = Get-PnPList
    $lists = $lists | Where-Object { $_.Hidden -eq $false }
    
    $selectedLists = Get-FormArrayItems ($lists) -dialogTitle "Select lists and libraries to migrate" -key Title
    $titles = $selectedLists.Title
    Get-pnpProvisioningTemplate -ListsToExtract $titles -Out "Lists.xml" -Handlers Lists -Force -WarningAction Ignore
    ((Get-Content -path Lists.xml -Raw) -replace 'RootSite', 'Web') | Set-Content -Path Lists.xml
    foreach ($title in $titles) {
        # Get the latest list item form layout. Footer, Header and the Body:
        $list = Get-PnPList $title -Includes ContentTypes
        $contentType = $list.ContentTypes | Where-Object { $_.Name -eq "Item" }
        $contentType.ClientFormCustomFormatter | Set-Content .\$title.json
    }
}

if ($MigrationType -eq "Import") {
    Apply-PnPProvisioningTemplate -Path Lists.xml 
    $jsonFiles = Get-ChildItem *.json
    if ($jsonFiles) {
        $titles = $jsonFiles | ForEach-Object { "$($_.BaseName)" }

        foreach ($title in $titles) {
            $list = Get-PnPList $title -Includes ContentTypes
            $contentType = $list.ContentTypes | Where-Object { $_.Name -eq "Item" }
            if ($contentType) {
                $json = Get-Content .\$title.json
                $contentType.ClientFormCustomFormatter = $json
                $contentType.Update($false)
                $contentType.Context.ExecuteQuery();
            }
        }
    }
}