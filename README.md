# sdlsync

`sdlsync` keeps a local copy of an SDL LiveContent (aka SDL Knowledge Center) repository.

## Setup

1. Install [ISHRemote](https://github.com/sdl/ISHRemote).
1. Clone this repository.
1. Open `sdlsync.ps1` and set the value for `$LocalRepository`.
   This is the directory where you want to store a copy of items in the SDL repository.
1. Open the file `netrc.ps1` and set the variables `$username`, `$password`, and `$url`. For example:
```
$username = 'bob'
$password = '+@gS!7O]H4Ub2kq'
$url      = 'https://ccms.example.com/InfoShareWS/'
```

## Syncing SDL

The first time you run `.\sdlsync.ps1`, the entire repository will sync to the specified
directory. This will take several hours. The next time you run `sldsync.ps1`, only the
files that were updated since the last run will be downloaded. 

After the initial sync, schedule the program to run as often as you want (e.g., every 
10 minutes, every hour, or every night).

## Filename length

Windows imposes a 260 character limit on filenames from the root directory. Because SDL
filename are long `<title>=<GUID>=<version>=<language>=.xml`, the `$LocalRepository`
should be short (e.g, `D:\repo`). Search the log for the word FAIL to see if any files
failed to download.

## Misc
- Use the `-Verbose` flag to create verbose logs.
- If you want to sync the whole repository again, delete the file `last-time-run.txt` and re-run the program.

## TODO
- Let users specify a specific directory (rather than the whole repository) to sync.
- Add fail warnings for topics that failed to download.
