BUFFER_SIZE = 1<<17 # 128KB
fs = require 'fs'
path = require 'path'

class FileBase
 constructor: (filePath, encoding) ->
  @path = filePath
  @buffer = new Buffer BUFFER_SIZE
  @bufferLen = 0
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

  remain = BUFFER_SIZE - @bufferLen

  # Optimization for smaller strings as creating lot of smaller Buffers
  # can be expensive - https://nodejs.org/api/buffer.html#buffer_class_slowbuffer
  if str.length * 2 < remain
   len = @buffer.write str, @bufferLen, remain, @encoding
   if len < remain
    @bufferLen += len
    return on

  bytes = new Buffer str, @encoding
  len = Math.min remain, bytes.length
  @bufferLen += bytes.copy @buffer, @bufferLen, 0, len
  if bytes.length >= remain
   @_flush()
   start = remain
   len = bytes.length - remain
   chunks = Math.floor len / BUFFER_SIZE
   if chunks > 0
    length = BUFFER_SIZE * chunks
    @pos += fs.writeSync @fd, bytes, start, length, @pos
    start += length
    #len = len % BUFFER_SIZE
   @bufferLen = bytes.copy @buffer, 0, start, bytes.length

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
  if @bufferLen is 0
   return
  @_createFile()
  @pos += fs.writeSync @fd, @buffer, 0, @bufferLen, @pos
  @bufferLen = 0
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
