# Synced Append

A library that can be used to append multiple text files and do commits where it doesn't leave
corrupted states. All appended files will be in sync over process crashes or restarts. In case
you don't wont to append multiple files and ensure those files are in sync, this can be simple
use to append just one file and commit appends making sure there are no corrupted states when
process crashes or restarts.

It's assumed fs.fsync() ensures data written to the hardware. There certain hardware and file
system configurations where this is not guaranteed.

## Example

```coffeescript

 SyncedAppend = require './synced-append'
 files =
  country: './data/country.csv'
  city: './data/city.csv'

 # First parameters is the file used to store states so that commits can be
 # rolledback.
 # Second parameter is the set of files that need to be in sync

 sync = new SyncedAppend './data/rollback.log', files

 sync.start() # starts the sync by rolling back uncommited changes

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

 # Commits above changes
 sync.sync()

```

## License

MIT
