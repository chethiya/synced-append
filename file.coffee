MAX_APPENDS = 10000
fs = require 'fs'
path = require 'path'

class FileBase
 constructor: (filePath) ->
  @path = filePath
  @buffer = []

  @stopped = on
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
  @pos += fs.writeSync @fd, str, @pos, "utf8"
  @buffer = []
  return

 fsync: ->
  if @synced is on
   return off
  @_flush()
  if @fd?
   fs.fsyncSync @fd
   if @fdDir?
    fs.fsyncSync @fdDir
  @synced = on
  return on

 changePath: (filePath) ->
  @fsync()
  if @fd?
   fs.close @fd
   if @fdDir
    fs.close @fdDir
  @fd = null
  @fdDir = null
  @pos = null
  @path = filePath
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
