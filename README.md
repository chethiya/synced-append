# Sync Append

Append a file without leaving corrupted states when machine crashes. A set of files can be grouped together so that all those files are in sync when recovered from crash.

This implements rollback journal mechanism using fsync(). So this module assumes fsync() does what it is supposed to do in the target system.

Look for examples to see how this can be used.
