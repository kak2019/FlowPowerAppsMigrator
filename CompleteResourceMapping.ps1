﻿[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [switch]$DoNotReconnect
)
if ($null -eq $TARGET_SITE_URL) {
    $TARGET_SITE_URL = Read-Host "Enter the URL of the destination SharePoint site"
}
if($DoNotReconnect.IsPresent -eq $false){
    Connect-PnPOnline -Url $TARGET_SITE_URL -UseWebLogin -WarningAction Ignore
}

$lists = Get-PnPList -Includes Views, Fields, DefaultView
$lists = $lists | Where-Object hidden -eq $false

$resources = Import-Csv -Path .\resourceMapping.csv
$resources[0].newId = $TARGET_SITE_URL

$lists | ForEach-Object {
    $line = "" | Select-Object resource, oldId, newId
    $line.resource = $_.RootFolder.ServerRelativeUrl.Replace($_.ParentWebUrl, "")
    $line.newId = $_.ID
    $resource = $resources | Where-Object resource -eq $line.resource
    if ($resource -ne $null) {
        $resource.newId = $line.newId
    }

    $line = "" | Select-Object resource, oldId, newId
    $line.resource = $_.DefaultView.ServerRelativeUrl.Replace($_.ParentWebUrl, "")
    $line.newId = $_.DefaultView.ID

    $resource = $resources | Where-Object resource -eq $line.resource
    if ($resource -ne $null) {
        $resource.newId = $line.newId
    }
}

$resources | Export-Csv -Path "resourceMapping.csv" -NoTypeInformation
Write-Host resourceMapping.csv fully complete -ForegroundColor Green