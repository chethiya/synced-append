SyncAppend = require './../synced-append'
fs = require 'fs'

LINE_LEN = 99007
MAX_LINES = 10000000

filePath = "./output.txt"
journalPath = "./rollback_journal.log"
#a list of files that need to be in sync
#only one file in this example
files =
 output:
  path: filePath
  deleteOk: on

start = null
# Checks whether the output.txt got any corrupted lines
check = ->
 console.log 'Check file for corruptions'
 data = null
 try
  data = fs.readFileSync filePath, 'utf8'
 start = 0
 if data?
  arr = data.split '\n'
  for i in [0...arr.length]
   if arr[i].length isnt LINE_LEN
    console.error """
     Error in line #{i+1}: Has #{arr[i].length} digits when it should have #{LINE_LEN} digits
    """
    return off
  start = arr.length
 console.log 'No errors'
 return on

# Check before recovering
console.log 'Before recovery'
check()

# If there are corrupted files, those are restored using the journal log
# when the new instance is created bellow
try
 writer = new SyncAppend journalPath, files
catch e
 # Output file has been changed outside this program and can't be recovered
 console.error e
 process.exit 0

# Check after recovering
console.log 'After recovery'
if not check()
 process.exit 0

#file object which will be used to append
fileObject = writer.getFile 'output'

done = ->
 process.exit 0
setTimeout done, 1000

# Create a rollback journal to be used if program got crashed.
# Will be recovered next time the instance is created.
# This also start accepting appends
console.log 'Start writing'
writer.start()
next = (i) ->
 if i >= MAX_LINES
  writer.close()
  process.exit 0
  return
 if i > 0
  fileObject.append '\n'
 #repeat (i%10), 1000 times in a single line
 for j in [0...LINE_LEN]
  fileObject.append "#{i%10}"

 # Cnce following is done above appends will get commited
 # if program get crashed before finishing below sync()
 # the file get rolled back to the journal log created when start()
 # was called
 if i%7 is 0
  writer.sync()

 setTimeout next, 0, i+1
next start
