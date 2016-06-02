FileBase = require './file'
FS = require 'fs'
PATH = require 'path'
crypto = require 'crypto'

class File
 constructor: (base) ->
  @base = base

 append: (str) -> @base.append str
 isClosed: -> @base.closed
 getPath: -> @base.path

class SyncAppend
 constructor: (journalPath, files) ->
  @journalPath = PATH.normalize journalPath
  @fdJournalDir = null
  dir = PATH.resolve @journalPath, '..'
  try
   @fdJournalDir = FS.openSync dir, 'r'
  @files = {}
  @stopped = on
  @closed = off

  @_recover()
  files ?= {}
  for id, obj of files
   #don't replace existing working files
   if @files[id]? and obj.deleteOk?
    @files[id].deleteOk = obj.deleteOk
   if not @files[id]?
    p = encoding = bufferSize = deleteOk = null
    if 'string' is typeof obj
     p = obj
    else
     p = obj.path
     if obj.encoding?
      encoding = obj.encoding
     if obj.bufferSize?
      bufferSize = obj.bufferSize
     if obj.deleteOk?
      deleteOk = obj.deleteOk
    p = PATH.normalize p
    deleteOk ?= off
    base = new FileBase p, encoding, bufferSize
    @files[id] =
     path: p
     base: base
     file: new File base
     deleteOk: deleteOk

 _recover: ->
  # If @journalPath exists restore paths based on that
  # Throw errors if file sizes are corrupted
  # Update @files based on the journal log
  # Delete journal file
  data = null
  try
    data = FS.readFileSync @journalPath, encoding: "utf8"
  catch
   return off

  recovered = off
  hash = data.substr 0, 32
  data = data.substr 32
  hash2 = crypto.createHash('md5').update(data, "utf8").digest("hex")
  if hash is hash2
   log = JSON.parse data
   #recover
   for id, obj of log
    exists = off
    try
     FS.accessSync obj.path, FS.F_OK
     exists = on
    if exists is off
     if obj.size > 0 and obj.deleteOk isnt on
      throw new Error """
       Trying to recover a non-existing file #{obj.path} to the file size #{obj.size}
      """
    else
     stat = FS.statSync obj.path
     if stat.size < obj.size
      throw new Error """
       Trying to recover a corrupted file #{obj.path} having file
       size #{stat.size} to file size #{obj.size}
      """
     dir = PATH.resolve obj.path, '..'
     fdDir = null
     try
      fdDir = FS.openSync dir, 'r'
     if obj.size is 0
      FS.unlinkSync obj.path
      if fdDir?
       try
        FS.fsyncSync fdDir
     else
      fd = FS.openSync obj.path, 'r+'
      FS.ftruncateSync fd, obj.size
      FS.fsyncSync fd
      FS.closeSync fd
      if fdDir?
       try
        FS.fsyncSync fdDir
     if fdDir?
      FS.closeSync fdDir
   recovered = on

   #build @files
   for id, obj of log
    base = new FileBase obj.path, obj.encoding, obj.bufferSize
    @files[id] =
     path: obj.path
     base: base
     file: new File base
     deleteOk: if obj.deleteOk? then obj.deleteOk else off

  #delete journal log
  FS.unlinkSync @journalPath
  if @fdJournalDir?
   try
    FS.fsyncSync @fdJournalDir
  return recovered

 start: (files) ->
  #update @files using files by replacing any existing (existing File objects also
  #need to be updated with new file pahts - not harmful as old files are in sync)

  if @stopped is off or @closed is on
   return off

  #update files
  if files?
   for id, obj of files
    p = encoding = bufferSize = deleteOk = null
    if 'string' is typeof obj
     p = obj
    else
     p = obj.path
     encoding = obj.encoding
     bufferSize = obj.bufferSize
     deleteOk = obj.deleteOk

    if @files[id]?
     o = @files[id]
     o.base.changePath p, encoding #no fsyncs as everything is synced and stopped
     o.path = p
     if deleteOk?
      o.deleteOk = deleteOk
    else
     base = new FileBase p, encoding, bufferSize
     deleteOk ?= off
     @files[id] =
      path: p
      base: base
      file: new File base
      deleteOk: deleteOk

  @_initJournal()

  #mark everything as started
  for id, obj of @files
   obj.base.stopped = off
  @stopped = off
  return on

 _initJournal: ->
  if @stopped is off
   return off
  log = {}
  for id, obj of @files
   size = null
   try
    FS.accessSync obj.path, FS.F_OK
   catch
    size = 0
   if not size?
    stat = FS.statSync obj.path
    size = stat.size

   log[id] =
    path: obj.path
    size: size
    encoding: obj.base.encoding
    bufferSize: obj.base.bufferSize
    deleteOk: obj.deleteOk
  str = JSON.stringify log
  hash = crypto.createHash('md5').update(str, "utf8").digest("hex")
  data = [hash, str].join ''
  fd = FS.openSync @journalPath, 'w'
  FS.writeSync fd, data, 0, "utf8"
  FS.fsyncSync fd
  FS.closeSync fd
  if @fdJournalDir?
   try
    FS.fsyncSync @fdJournalDir
  return on

 sync: ->
  res = @syncStop()
  if res is off
   return off
  @start()
  return on

 syncStop: ->
  # Call fsync of all files, remove journal file
  # This will stop writes to files after sync, without automaticall creating
  # another checkpoint after sync
  # This can be used to update the files by calling start with updated files
  # all File.appends will return false until start() is called

  if @stopped is on
   return off
  for id, obj of @files
   obj.base.stopped = on
   obj.base.fsync()

  FS.unlinkSync @journalPath
  if @fdJournalDir?
   try
    FS.fsyncSync @fdJournalDir
  @stopped = on

 close: ->
  @syncStop()
  for id, obj of @files
   obj.base.close()
  if @fdJournalDir?
   FS.closeSync @fdJournalDir
  @closed = on

 getFile: (id) ->
  if @files[id]?
   return @files[id].file
  else
   return null

 getFiles: ->
  res = {}
  for id, obj of @files
   res[id] = obj.file
  return res

module.exports = SyncAppend
