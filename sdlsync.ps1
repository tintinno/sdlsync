#sdlsync

# whether the logs should be verbose
param([Switch]$Verbose)


################################################################################################
# Set the location of your local repository.
# Filenames may exceed the Windows character limit, so keep this short (e.g., D:\repo). No final slash.
$LocalRepository = 'D:\repo'

# Set the IshTypeFilter if you only want certain types of files (e.g., maps and topics).
# Example: $IshTypeFilter   = @('ISHMasterDoc','ISHModule')
# Default: $IshTypeFilter   = @('ISHIllustration','ISHLibrary','ISHMasterDoc','ISHModule')
$IshTypeFilter   = @('ISHIllustration','ISHLibrary','ISHMasterDoc','ISHModule')

# TODO: Implement some reasonably efficient way to allow users to sync only specific directories.
#
# Set the location of the top-most directory you want to sync. Leave blank to sync everything. 
# Example: $RemoteFolderPath = '\General\New Releases\topics'
# Default: $RemoteFolderPath = ''
#$RemoteFolderPath = ''

################################################################################################


# if we encounter an error, write to log and screen, then exit; otherwise, only write to log
function write-log ($msgtype, $msg){
  if ( $msgtype -eq "ERROR"){
    Write-Output "[ $(Get-Date -UFormat "%Y-%m-%d %H:%M:%S") ] [$msgtype] $msg" | Out-File -Append -Encoding ascii sdl.log
    Write-Output "[$msgtype] $msg"
    exit
  } else {
    Write-Output "[ $(Get-Date -UFormat "%Y-%m-%d %H:%M:%S") ] [$msgtype] $msg" | Out-File -Append -Encoding ascii sdl.log
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
    echo "Open sdlsync and set the value of LocalRepository."
    exit
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
  $ishdocs = Find-IshDocumentObj -IshSession $session `
                -RequestedMetadata $requestedMetadata `
                -IshTypeFilter $IshTypeFilter
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
  $ishdocs = Find-IshDocumentObj -IshSession $session `
                -RequestedMetadata $requestedMetadata `
                -MetadataFilter $metadataFilter       `
                -IshTypeFilter $IshTypeFilter
  write-log "INFO" "Found $($ishdocs.count) updated objects"
  Download-IshDocs $ishdocs
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