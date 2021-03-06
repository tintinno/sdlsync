﻿#sdlsync

# whether the logs should be verbose
param([Switch]$Verbose)


################################################################################################
# Set the location of your local repository.
# Filenames may exceed the Windows character limit, so keep this short (e.g., D:\repo). No final slash.
$LocalRepository = ''

# Set the IshTypeFilter if you only want certain types of files (e.g., maps and topics).
# Example: $IshTypeFilter   = @('ISHMasterDoc','ISHModule')
# Default: $IshTypeFilter   = @('ISHIllustration','ISHLibrary','ISHMasterDoc','ISHModule')
$IshTypeFilter   = @('ISHIllustration','ISHLibrary','ISHMasterDoc','ISHModule')

# Set the location of the top-most directory you want to sync. Leave blank to sync everything.
# Example: $RemoteFolderPath = '\General\New Releases\topics'
# Default: $RemoteFolderPath = ''
$RemoteFolderPath = ''

################################################################################################


function write-log ($msgtype, $msg){
  # regardless of msgtype, write to log
  Write-Output "[ $(Get-Date -UFormat "%Y-%m-%d %H:%M:%S") ] [$msgtype] $msg" | Out-File -Append -Encoding ascii sdl.log
 
  # if msgtype is Error, echo to screen and exit; if Warn, echo to screen but do not exit
  if ( $msgtype -eq "ERROR"){
    Write-Output "[$msgtype] $msg"
    exit
  } elseif ( $msgtype -eq "WARN"){
    Write-Output "[$msgtype] $msg"
  }
}

# returns an ishSession
function authenticate(){
 
  if (Test-Path .\netrc.ps1){
    write-log "INFO" "Loading values from netrc.ps1"
    . .\netrc.ps1
  } else {
    write-log "ERROR" "Missing netrc.ps1 file"
  }

  write-log "INFO" "Authenticating"
  $session = New-IshSession -IshUserName $username -IshPassword $password -WsBaseUrl $url
  # return
  $session
}

function validation(){
  if ( -Not $LocalRepository ){
    write-log "ERROR" "Open sdlsync and set the value of LocalRepository."
  }
}

function Set-RequestedMetadata(){
  Set-IshRequestedMetadataField -IshSession $session -Name FTITLE -Level Logical -ValueType Value |
  Set-IshRequestedMetadataField -IshSession $session -Name VERSION -Level Version -ValueType Value |
  Set-IshRequestedMetadataField -IshSession $session -Name DOC-LANGUAGE -Level Lng -ValueType Value |
  Set-IshRequestedMetadataField -IshSession $session -Name MODIFIED-ON -Level Lng -ValueType Value
}

function Download-IshFile($ishdoc, $downloadPath){
  try {
    $null = Get-IshDocumentObjData -IshSession $session -IshObject $ishdoc -FolderPath $downloadPath
  } catch {
    write-log "FAIL" "File failed to download: $($ishdoc.IshRef). Probably file path length."
    write-log "INFO" "path: $downloadPath + $($ishdoc | Get-IshMetadataField -IshSession $session -Name FTITLE -Level Logical)"
  }
}

function Download-IshDocs($ishdocs){
  foreach ($ishdoc in $ishdocs){
    $guid = $ishdoc.IshRef
    $sdlPath = Get-IshDocumentObjFolderLocation -IshSession $session -IshObject $ishdoc
    $downloadPath = $LocalRepository + $sdlPath
    if ( $Verbose ){
      write-log "INFO" "Downloading $guid to '$downloadPath'"
    }
    Download-IshFile $ishdoc $downloadPath
  }
  write-log "INFO" "Done"
}

function Download-AllFiles(){
  [datetime]::Now.ToString('d/M/yyyy HH:mm:ss') | Out-File -Encoding ascii .\last-time-run.txt
  $requestedMetadata = Set-RequestedMetadata
 
  # pass $null to Get-IshDocs because we have no date metadataFilter
  $ishdocs = Get-IshDocs $null
  write-log "INFO" "Found $($ishdocs.count) new objects"
  Download-IshDocs $ishdocs
}

#download only those files changed since the last time this script was run
function Download-ChangedFiles(){
  $requestedMetadata = Set-RequestedMetadata
  $metadataFilter = Set-IshMetadataFilterField -IshSession $session `
                    -Name MODIFIED-ON           `
                    -Level Lng                  `
                    -FilterOperator GreaterThan `
                    -Value $(get-content .\last-time-run.txt)

  # reset the last-time-run value
  [datetime]::Now.ToString('d/M/yyyy HH:mm:ss') | Out-File -Encoding ascii .\last-time-run.txt

  # get all the topics modified after the date specified in last-time-run
  $ishdocs = Get-IshDocs $metadataFilter
  write-log "INFO" "Found $($ishdocs.count) updated objects"
  Download-IshDocs $ishdocs
}

function Get-TopicsInRemoteFolderPath(){
  $ishdocs = @()
  $folders = Get-IshFolder -IshSession $session -FolderPath $RemoteFolderPath -Recurse
  foreach ($folder in $folders){
    $content = Get-IshFolderContent -IshSession $session -FolderId $folder.IshFolderRef
    if ($content){
      $ishdocs += $content
    }
  }
  # return
  $ishdocs
}

function Filter-IshDocsByIshTypeFilter($temp){
  $ishdocs = @()
  foreach ($ishdoc in $temp){
    if ($IshTypeFilter -contains $ishdoc.IshType){
      $ishdocs += $ishdoc
    }
  }
  # return
  $ishdocs
}

function Filter-IshDocsByMetadataFilter($temp){
  $ishdocs = @()
  foreach ($ishdoc in $temp){
    # if tempdoc has a value, then the topic matches the metadataFilter
    $tempdoc = Get-IshDocumentObj -IshSession $session `
                    -LogicalId $ishdoc.IshRef          `
                    -MetadataFilter $metadataFilter
    if ($tempdoc){
      $ishdocs += $ishdoc
    }
  }
  # return
  $ishdocs
}

# make sure each item in ishdocs contains all necessary metadata
function Add-IshDocMetadata($temp){
  $ishdocs = @()
  foreach ($tempfile in $temp){
    $ishdoc = Get-IshDocumentObj -IshSession $session `
                        -LogicalId $tempfile.IshRef   `
                        -RequestedMetadata $requestedMetadata
    $ishdocs += $ishdoc
  }
  # return
  $ishdocs
}

# if $RemoteFolderPath has been set, use get-ishfoldercontent to create $ishdocs; otherwise,
# use find-ishdocumentobj to create $ishdocs (where $ishdocs is the array of topics to sync)
# The ishdocs returned depends on the state of 2 variables, so there are 4 combinations to
# handle: 00, 01, 10, 11. Note that the IshTypeFilter is always present.
function Get-IshDocs($metadataFilter){

  # if RemoteFolderPath and metadataFilter have not been set, we want to sync the entire
  # repository, so ishdocs should return everything
  if (-not $RemoteFolderPath -and -not $metadataFilter){

    $ishdocs = Find-IshDocumentObj -IshSession $session `
                -RequestedMetadata $requestedMetadata   `
                -IshTypeFilter $IshTypeFilter

  # if RemoteFolderPath is not set but metadataFilter is, we should return everything in the
  # repository that matches the metadata filter (i.e., that has changed since time-last-run)
  } elseif (-not $RemoteFolderPath -and $metadataFilter){

    $ishdocs = Find-IshDocumentObj -IshSession $session `
                -RequestedMetadata $requestedMetadata   `
                -MetadataFilter $metadataFilter         `
                -IshTypeFilter $IshTypeFilter
 
  # if RemoteFolderPath has been set but metadataFilter has not, ishdocs should contain all the
  # items within RemoteFolderPath, recursively
  } elseif ( $RemoteFolderPath -and -not $metadataFilter){

    $ishdocs = Get-TopicsInRemoteFolderPath
    $ishdocs = Filter-IshDocsByIshTypeFilter $ishdocs
    $ishdocs = Add-IshDocMetadata $ishdocs
 
  # if RemoteFolderPath and metadataFilter have been set, ishdocs should contain all the items
  # within RemoteFolderPath, recursively, that match the metadata filter (i.e., that have
  # changed since time-last-run)
  } elseif ($RemoteFolderPath -and $metadataFilter){

    $ishdocs = Get-TopicsInRemoteFolderPath
    $ishdocs = Filter-IshDocsByMetadataFilter $ishdocs
    $ishdocs = Filter-IshDocsByIshTypeFilter $ishdocs
    $ishdocs = Add-IshDocMetadata $ishdocs
      
  } else {
    write-log "ERROR" "Impossible combination of variables"
  }

  # return value
  $ishdocs
}

function main(){
  $session = authenticate
  validation
 
  if ( Test-Path .\last-time-run.txt ){
    Download-ChangedFiles
  } else {
    Download-AllFiles
  }
}

main

