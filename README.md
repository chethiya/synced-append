# Synced Append

A library that can be used to append multiple text files and do commits so that all files are in sync and doesn't leave in corrupted states between process crashes and restarts. In case you only
have just one file to append still this library can be useful as it ensures files will not stuck
in corrupted states.

Note: It's assumed fs.fsyncSync() ensures data written to the hardware.

## The Problem

If strings are appended to files using write() it's not guaranteed data written
to the disk in an atomic manner. This makes sense as if it initiates a write to disk for
each small string append, OS will be spending lot more time doing disk IO. But the problem with
this is if the process crashes in an unexpected manner (e.g. a SIGKILL), it's possible that
all the appends you did might not reach the disk.

## Solution

Please go through following links to understand basic concepts on how to solve
these types of problems.

[Files are hard](http://danluu.com/file-consistency/)

[Transaction log](https://en.wikipedia.org/wiki/Transaction_log)


## How to get it

```
 npm install synced-append
```

## Example

```coffeescript

 SyncedAppend = require 'synced-append'
 files =
  country: './data/country.csv'
  city: './data/city.csv'

 # - First parameters is the file used to store states so that commits can be
 # rolledback.
 # - Second parameter is the set of files that need to be in sync
 # - At the time of object creatation any previous uncomiited work will be
 # rolled back.
 sync = new SyncedAppend './data/rollback.log', files

 # starts the sync for appends. This creates the rollback log
 sync.start()

 countryWriter = sync.getFile 'country'
 cityWriter = sync.getFile 'city'

 # append strigns to files
 countryWriter.append 'code,name\n'
 countryWriter.append 'LKA,Sri Lanka\n'
 cityWriter.append 'id,name,countryCode\n'
 cityWriter.append '0,Colombo,LKA\n'
 cityWriter.append '1,Kandy,LKA\n'

 # Commit above appends to files. This doesn't leave corrupted states in case of
 # crash
 sync.syncStop()

 newFiles =
  language:
   path: './data/language.csv'
   encoding: 'utf8'

 # Since sync was stopped previously can add new files when starting again
 sync.start newFiles

 langWriter = sync.getFile 'language'

 countryWriter.append 'USA,United States of America\n'
 langWriter.append 'countryCode,lanague\n'
 langWriter.append 'USA,English\n'

 # Commits above changes and auto start.
 # This is euqauvlent to sync.syncStop and sync.start()
 sync.sync()

```

## Example 2

```coffeescript
 # Run this program multiple times. Every time it runs it writes to a
 # new log file.

 SyncedAppend = require 'synced-append'

 # recovers last written file
 sync = new SyncedAppend "./data/example2_rollback.log"

 logWriter = sync.getFile 'log'
 if logWriter?
  console.log "Recovered the file at #{logWriter.getPath()}"

 # Every time we write to a new file
 files =
  log: "./data/log-#{(new Date).getTime()}.txt"

 # starting write to the new file
 sync.start files
 if not logWriter?
  logWriter = sync.getFile 'log'
 logWriter.append "File written at #{(new Date).getTime()}"

 # Let's commit the append
 sync.syncStop()

 # File paths can be changed on the file when sync is stopped
 files.log += ".more"
 sync.start files

 # Try removing these two lines. If not bytes are committed to a file
 # the file will be removed when recovered.
 logWriter.append 'first line\n'
 sync.sync()

 # Force stop the program with uncommitted appends
 exit = (code) ->
  console.log """
   exit #{code}\n
   Process is force stopped. There can be uncommited appends in the file
   #{logWriter.getPath()}
  """
  process.exit code
 setTimeout exit, 100, 1

 # Append the file without commiting so that file left with uncommited
 # appends when the program exits
 MAXN = 1<<20
 next = ->
  # Make sure appends are large enough to fill the file buffer so that
  # actual file write will happen.
  for i in [0...MAXN]
   logWriter.append "#{i}"
  setTimeout next, 0
 next()
```

## License

MIT
