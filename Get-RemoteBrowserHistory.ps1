<#
    .SYNOPSIS
        Queries remote Edgium or Chrome browser history database for downloads and urls.
    .DESCRIPTION
        Queries remote browser history database for downloads and urls to aid DFIR investigations.
    .PARAMETER ComputerName
        Remote endpoint to target.
    .PARAMETER UserName
        Remote user to target.
    .PARAMETER Browser
        The Edge or Chrome browser to pull history from.
    .PARAMETER Count
        Optional. Number of results to pull from database.
    .PARAMETER Output
        Optional. Output as List or Table of data.
    .EXAMPLE
        Get-RemoteBrowserHistory.ps1 -ComputerName lab01 -UserName tech01 -Browser Edge
    .EXAMPLE
        Get-RemoteBrowserHistory.ps1 -ComputerName lab01 -UserName tech01 -Browser Edge -Count 25 -Output List
    .NOTES
        File Name: Get-RemoteBrowserHistory.ps1
        Author: keyboardcrunch
        Date Created: 15/01/21
#>

param (
    [string]$ComputerName = $(throw "-ComputerName is required."),
    [string]$UserName = $(throw "-UserName is required."),
    [ValidateSet('Edge','Chrome')]
    [string]$Browser = "Chrome",
    [string]$Count = 10,
    [ValidateSet('Table','List')]
    [string]$Output = "Table"
)

Try {
    Import-Module PSSqlite
} Catch {
    Write-Host "Please install PSSqlite.`r`nExample (w/Admin PowerShell): Install-Module PSSqlite`r`nExiting..."
    Exit
}

# User Data paths per browser
If ( $Browser -eq "Edge" ) { $History = "\\$ComputerName\C$\Users\$UserName\AppData\Local\Microsoft\Edge\User Data\Default\History" }
If ( $Browser -eq "Chrome" ) { $History = "\\$ComputerName\C$\Users\$UserName\AppData\Local\Google\Chrome\User Data\Default\History" }

# Sqlite Queries
$DownloadQuery = "SELECT id, target_path, total_bytes, opened, referrer, tab_url, tab_referrer_url, mime_type FROM downloads ORDER BY id DESC LIMIT $Count;"
$URLQuery = "SELECT id, url, title, visit_count FROM urls ORDER BY id DESC LIMIT $Count;"

$TempHistoryDB = "$env:TEMP\$ComputerName-$UserName-history.db"

If ( Test-Connection -ComputerName $ComputerName -Count 2 -Quiet ) {
    If ( Test-Path $History ) {
        Try {
            Copy-Item -Path $History -Destination $TempHistoryDB -Force
        } Catch {
            Write-Host "Failed to copy $History`r`nExiting..."
            Exit
        }
        # Use PSSqlite to dump last $Count downloads and urls
        Try {
            $Downloads = Invoke-SqliteQuery -DataSource $TempHistoryDB -Query $DownloadQuery
            $Urls = Invoke-SqliteQuery -DataSource $TempHistoryDB -Query $URLQuery
        } Catch { 
            Write-Host "Failure running queries!" -ForegroundColor Red
            Exit
        }

        Write-Host "`r`nLast 10 URLs:" -ForegroundColor Green
        If ( $Output -eq "Table" ) {
            Write-Output $Urls | Format-Table -AutoSize
        }
        If ( $Output -eq "List" ) {
            Write-Output $Urls | Format-List
        }

        Write-Host "`r`nLast 10 Downloads:" -ForegroundColor Green
        If ( $Output -eq "Table" ) {
            Write-Output $Downloads | Format-Table -AutoSize
        }
        If ( $Output -eq "List" ) {
            Write-Output $Downloads | Format-List
        }
    } Else {
        Write-Host "Failed to copy remote database: $History" -ForegroundColor Red
        Exit
    }
} Else {
    Write-Host "$ComputerName is offline!" -ForegroundColor Red
}
