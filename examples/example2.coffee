SyncedAppend = require '../synced-append'

# recovers last written file
sync = new SyncedAppend "./data/example2_rollback.log"

lowWriter = sync.getFile 'log'
if logWriter?
 console.log "Recovered the file at #{logWriter.getPath()}"

# Every time we write to new files
files =
 log: "./data/log-#{(new Date).getTime()}.txt"

# starting write to new file
sync.star files
if not logWriter?
 logWriter = sync.getFile 'log'
logWriter.append "File written at #{(new Date).getTime()}"

# Let's commit the append
sync.syncStop()

# File paths can be changed on the file when sync is stopped
files.log += ".more"
sync.start files

# Force stop the program with uncommited appends
exit = (code) ->
 console.log """
  exit #{code}\n
  Process is force stopped. There can be uncommited appends in the file
  #{logWriter.getPath()}
 """
setTimeout exit, 100

# append the file without commiting so that file left with uncommited
# appends when the program exits
MAXN = 1<<20
next = ->
 # Make sure appends are large enough to fill the file buffer and
 # do an actual file write
 for i in [0...MAXN]
  logWriter.append "#{i}"
 setTimeout next, 0
next()
