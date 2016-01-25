BUFFER_SIZE = 1<<17 # 128KB
FS = require 'fs'
PATH = require 'path'

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

  # Optimization for smaller strings by not creating lot of smaller Buffers.
  #
  # Note: It's said that there are some optimizations [1] at the nodejs level not to
  # create many small memory allocations, but create one large memory chunk
  # and allocate for small Buffers from that chunk. But still it's very slow
  # compared to Buffer.write()
  # [1] - https://nodejs.org/api/buffer.html#buffer_class_slowbuffer
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
    @pos += FS.writeSync @fd, bytes, start, length, null # @pos
    start += length
    #len = len % BUFFER_SIZE
   @bufferLen = bytes.copy @buffer, 0, start, bytes.length

  return on

 _createFile: ->
  if not @fd?
   @fd = FS.openSync @path, 'a'
   stat = FS.statSync @path
   @pos = stat.size
   parentPath = PATH.resolve @path, '..'
   try
    @fdDir = FS.openSync parentPath, 'r'
  return

 _flush: ->
  if @bufferLen is 0
   return
  @_createFile()
  @pos += FS.writeSync @fd, @buffer, 0, @bufferLen, null # @pos
  @bufferLen = 0
  return

 fsync: ->
  if @synced is on
   return off
  @_flush()
  if @fd?
   FS.fsyncSync @fd
   if @fdDir?
    try
     FS.fsyncSync @fdDir
  @synced = on
  return on

 changePath: (filePath, encoding) ->
  @fsync()
  if @fd?
   FS.close @fd
   if @fdDir
    FS.close @fdDir
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
   FS.close @fd
   if @fdDir?
    FS.close @fdDir
  @closed = on
  return

module.exports = FileBase
