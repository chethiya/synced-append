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
  language: './data/language.csv'

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

## License

MIT
