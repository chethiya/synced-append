MAX_APPENDS = 10000
fs = require 'fs'
path = require 'path'

class FileBase
 constructor: (filePath, encoding) ->
  @path = filePath
  @buffer = []
  @encoding = encoding
  @encoding ?= "utf8"

  @stopped = on #controlled by SyncAppend
  @synced = on
  @closed = off

  @fd = null
  @fdDir = null
  @pos = null

 append: (str) ->
  if @stopped is on
   return off
  @synced = off
  @buffer.push str
  if @buffer.length > MAX_APPENDS
   @_flush()
  return on

 _createFile: ->
  if not @fd?
   @fd = fs.openSync @path, 'a'
   stat = fs.statSync @path
   @pos = stat.size
   parentPath = path.resolve @path, '..'
   try
    @fdDir = fs.openSync parentPath, 'r'
  return

 _flush: ->
  if @buffer.length is 0
   return
  @_createFile()
  str = @buffer.join ''
  @pos += fs.writeSync @fd, str, @pos, @encoding
  @buffer = []
  return

 fsync: ->
  if @synced is on
   return off
  @_flush()
  if @fd?
   fs.fsyncSync @fd
   if @fdDir?
    try
     fs.fsyncSync @fdDir
  @synced = on
  return on

 changePath: (filePath, encoding) ->
  @fsync()
  if @fd?
   fs.close @fd
   if @fdDir
    fs.close @fdDir
  @fd = null
  @fdDir = null
  @pos = null
  @path = filePath
  if encoding?
   @encoding = encoding
  return

 close: ->
  @fsync()
  if @fd?
   fs.close @fd
   if @fdDir?
    fs.close @fdDir
  @closed = on
  return

module.exports = FileBase
