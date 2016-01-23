SyncedAppend = require './../synced-append'
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


