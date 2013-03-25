/* A Sensible File System.
1. no limit to the size of a file (except imposed by the size of the disc)
2. Free blocks must be properly managed so deleted file for re-use.
3. Access to the data in a file must be efficient.
4. Do not use contiguous allocation.
5. Once a file has been created, ok to add data to it at any time, without limit.
6. Directories are just like any other file, but with a special data format.
7. Files have tags in their metadata now at least whether they are directories or regular data files.

Required operations, provided as a library of functions:
   1. Create a file
   2. Open an existing file
   3. Delete a file
   4. Create a directory
   5. Write N bytes to a file
   6. Read N bytes from a file
   7. Set file position (so, for example, the next write will be
                      appended to the end). */
static {

}

/*create a file*/
let create_f() be
{

}



/*open an existing file */
let open_f() be
{

}

/*delete a file */
let delete_f() be
{

}

/*create a directory*/
let create_dir() be
{

}

/*write N bytes to a file*/
let write_N_bytes() be
{

}

/*read N bytes from a file */
let read_N_bytes() be 
{

}

/*set file position(next read from this position)*/
let set_fiel_posi() be
{

}

/*start function*/
let start() be
{

}
