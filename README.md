# sdlsync

`sdlsync` keeps a local copy of an SDL LiveContent (aka SDL Knowledge Center) repository.

## Setup

1. Install [ISHRemote](https://github.com/sdl/ISHRemote).
1. Clone this repository.
1. Open `sdlsync.ps1` and set the following values:
  - `$LocalRepository`: the local directory to which files are synced.
  - `$RemoteFolderPath`: the top-level directory you want to sync. Leave blank to sync everything.
  - (Optional) `$IshTypeFilter`: the IshTypes you want to sync.
1. Open the file `netrc.ps1` and set the variables `$username`, `$password`, and `$url`. For example:
```
$username = 'bob'
$password = '+@gS!7O]H4Ub2kq'
$url      = 'https://ccms.example.com/InfoShareWS/'
```

## Syncing SDL

The first time you run `.\sdlsync.ps1`, the specified files are synced to the location set
in `$LocalRepository`. (Syncing an entire repository takes several hours.) The next
time you run `sldsync.ps1`, only the files that were updated since the last run are downloaded.

After the initial sync, schedule the program to run as often as you want (e.g., every 
10 minutes, every hour, or every night).

## Filename length

Windows imposes a 260 character limit on filenames from the root directory. Because SDL
filename are long `<title>=<GUID>=<version>=<language>=.xml`, the `$LocalRepository`
should be short (e.g, `D:\repo`). Search the log for the word FAIL to see if any files
failed to download.

## Misc
- Use the `-Verbose` flag to create verbose logs.
- If you want to sync the whole repository again, or if you've changed any of the intial
variables, delete the file `last-time-run.txt` and re-run the program.

