a very simple file syste implementation as described in the ass1.txt file

vsfs.b is the initial try.

vsfs_v1.b is improved, and I got 100% point from this improve version.

The improvement including:

1. Read tapes larger than a single block. This has been done by allocating
consecutive available blocks
2. Beable to read files with multiple blocks, blocks it need to read depend on
the file size
3. Seperate the functionality into separate functions
4. Seperate the ui from the functions


