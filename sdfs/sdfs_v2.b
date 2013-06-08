import "io"

manifest
{ words_per_block = 128 }

manifest	//superblock
{ sb_discname = 0,	
    sb_discnamesize = 32,
  sb_inodestart = 8,  
  sb_inodesize = 9, 
  sb_blockmapstart = 10,
  sb_blockmapsize = 11,
  sb_rootstart = 12,
  sb_rootsize = 13,
  sb_firstfree = 14, 
  sb_updated = 15 //update time for the superblock
  //may add more info later
}

manifest	//inode structure entry 
			//indexing inode table caculated based on the # entry
{ inode_type = byte 0,		//dir or file?
    inode_file = 0,
    inode_dir = 1,
  inode_status = byte 1,	//status byte for reuse of the entry
    inode_free = 0,
    inode_exists = 1,
  inode_size = 1,			//file size
  inode_nblock = 2,			//num of blocks allocated for this file
  inode_time = 3,			//last accessed?
    inode_month = byte 12,
	inode_day = byte 13,
	inode_hour = byte 14,
	inode_min = byte 15,
  inode_ctime = 4,			//create time
    inode_month_c = byte 16,
	inode_day_c = byte 17,
	inode_hour_c = byte 18,
	inode_min_c = byte 19,
  inode_firstblockptrs = 5, //first block pointer, +i to index others
  inode_blocksptrsize = 8,  //total number
  inode_firstlevelptr = 14,
  inode_secondlevelptr = 15,
  sizeof_inode = 16
  //may add more info later
}

manifest	//free block management
{ blockmap_nextfree = 0,	//index to the next free block
  blockmap_nextused = 1,	//index to the next "to be" free block
  blockmap_allfree = 2,		//keep the total number of the free blocks
  blockmap_nblocks = 6000 / 128 + 1}	//about 47 blocks

manifest	//root directory entry
{ rde_name = 0,
  rde_namesize = 27, //pick 27 to make each block fit 16 entry
  rde_status = byte 27,
	rde_free = 0,
	rde_exists = 1,
  rde_inodenum = 7,
  sizeof_rde = 8 }		//might need to change to 6 also

manifest	//directory entry, same as the root direcotry entry
{ de_name = 0,
  de_namesize = 27,
  de_status = byte 27,
    de_free = 0,
    de_exists = 1,
  de_inodenum = 7,
  sizeof_de = 8 }

manifest	//in-mem fs structure
{ fs_discnum = 0,	//which disc drive
  fs_nblocks = 1,	//total number of blocks
  fs_inodestart = 2,
  fs_inodesize = 3,
  fs_inodetable = 4,//in memory inode table
  fs_blockmapstart = 5,
  fs_blockmapsize = 6,
  fs_blockmap = 7,    //in memory blockmap, 6000/128 in total
  fs_rootstart = 8,
  fs_rootsize = 9,
  fs_rootdir = 10,	//pinter to in-memory copy
  fs_firstfree = 11,
  fs_discname = 12,	//pointer to a string
  fs_sbupdated = 13,//when last written to disc
  fs_currentdir = 14,//ptr to the current directory
  sizeof_fs = 15 }

manifest	//file information
{ fi_status = 0,
  fi_number = 1,
  fi_firstblock = 2,
  fi_length = 3,
  sizeof_fi = 4 }

manifest	//file buffer in-mem
{ file_mode = 0,
  file_inode = 1,
  file_size = 2,
  file_nblock = 3,
  file_thisblockn = 4,
  file_offset = 5,
  file_datablockptr1 = 6,
  //file_datablockptr9 = 14,
  file_datablockptrN = 14,
	file_ndatablockptrs = 8,
  file_firstlevelptr = 15,
  file_secondlevelptr = 16,
  
  file_firstindexblock = 17,
  file_secondindexblock = 145, //17 + 128=file_firstindexblock + 128 = 145
  file_thirdindexblock = 273,  //145 + 128
  file_currentdatablock = 401, //273 + 128,	

  file_firstindexentryN = 529, //401 + 128, 
  file_secondindexentryN = 530,//529 + 1,
  file_thirdindexentryN = 531, //530 + 1,
  sizeof_fileheader = 6,
  sizeof_filebuf = 532 }

/*
manifest	//file = open file, information used by higher level function
			// open, read, write, close. Includes buffer space
{ file_mode = 0,		//R and W mode
  file_filesys = 1,		//ptr to the in-mem fs structure
  file_inode = 2,
  file_thisblockn = 3,	//current block of the file
  file_remaining = 4,	//size of the file
  file_sizetype = 5,    //small=0, medium=1, large=2
  file_position = 6,	//new open position=0 
  file_nblockswriten = 7,
  file_buffer = 8,		//keep the file buffer address
  sizeof_file = 9 + sizeof_inode + 3*128 }//128 is the file buffer size
*/

/* error messages */
let last_error = nil,
    err_dscfull = "not enough disc space",
    err_dirfull = "directory is full",
    err_notfound = "file not found",
    err_wrongmode = "incorrect mode";

/* string input function */
let ins(ptr, sz) be
{ let max = sz*4-1,
      len = 0;
  while true do
  { let c = inch();
    if c = '\n' then break;
    if len < max then
    { byte len of ptr := c;
      len +:= 1 } }
  byte len of ptr := 0;
  resultis ptr }

/* copy of a string, but in heap memory */
let strdup(s) be
{ let len = strlen(s)/4 + 1;
  let r = newvec(len);
  for i = 0 to len-1 do
    r ! i := s ! i;
  resultis r }

/* are two strings equal? */
let streq(a, b) be           
{ let i = 0;
  while true do
  { let ca = byte i of a, cb = byte i of b;
    if ca <> cb then resultis false;
    if ca = 0 then resultis true;
    i +:= 1 } }

/* copy a string from zero terminated to non-zero terminated string*/
let zstr_to_nzstr(src, dst, size) be
{ let len = 0;
  while len<size do
  { let c = byte len of src;
    if c = 0 then break;
    byte len of dst := c;
    len +:= 1 }
  while len<size do
  { byte len of dst := 0;
    len +:= 1 } }

/* copy a string from non-zero terminated to zero terminated string*/
let nzstr_to_zstr(src, dst, size) be
{ let len = 0;
  while len<size do
  { let c = byte len of src;
    if c = 0 then break;
    byte len of dst := c;
    len +:= 1 }
  byte len of dst := 0 }

/*write super block from mem to disc */
let write_superblock(fs) be
{ let b = vec 128, r;
  for i = 0 to 127 do
    b ! i := 0;
  zstr_to_nzstr(fs ! fs_discname, b + sb_discname, sb_discnamesize);
  b ! sb_inodestart := fs ! fs_inodestart;
  b ! sb_inodesize := fs ! fs_inodesize;
  b ! sb_blockmapstart := fs ! fs_blockmapstart;
  b ! sb_blockmapsize := fs ! fs_blockmapsize;
  b ! sb_rootstart := fs ! fs_rootstart;
  b ! sb_rootsize := fs ! fs_rootsize;
  b ! sb_firstfree := fs ! fs_firstfree;
  fs ! fs_sbupdated := seconds();
  b ! sb_updated := fs ! fs_sbupdated;
  r := devctl(dc_disc_write, fs ! fs_discnum, 0, 1, b);
  if r < 0 then out("write_superblock dc_disc_write error %d\n", r);
  resultis r }

/*write rood directory entry to disc */
let write_rootdir(fs) be
{ let r = devctl(dc_disc_write, fs ! fs_discnum, fs ! fs_rootstart,
                 fs ! fs_rootsize, fs ! fs_rootdir);
  if r < 0 then out ("write_rootdir dc_disc_write error %d\n", r);
  resultis r }

/*write inode table from mem to disk */
let write_inodetable(fs) be
{ let r = devctl(dc_disc_write, fs ! fs_discnum, fs ! fs_inodestart,
				 fs ! fs_inodesize, fs ! fs_inodetable);
  if r < 0 then 
  out("write_inodetable dc_disc_write error %d\n", r);
  resultis r }

let write_blockmap(fs) be
{ let r = devctl(dc_disc_write, fs ! fs_discnum, fs ! fs_blockmapstart,
				 fs ! fs_blockmapsize, fs ! fs_blockmap);
  if r < 0 then
  out("write_blockmap dc_disc_write error %d\n", r);
  resultis r }

/*read super block from disc to mem */
let read_superblock(fs) be
{ let b = 128, r;
  r := devctl(dc_disc_read, fs ! fs_discnum, 0, 1, b);
  if r < 0 then
  { out(" read_superblock dc_disc_read error %d\n", r);
    resultis r}
  fs ! fs_discname := newvec(sb_discnamesize/4+1);
  nzstr_to_zstr(b + sb_discname, fs ! fs_discname, sb_discnamesize);
  fs ! fs_inodestart := b ! sb_inodestart;
  fs ! fs_inodesize := b ! sb_inodesize;
  fs ! fs_blockmapstart := b ! sb_blockmapstart;
  fs ! fs_blockmapsize := b ! sb_blockmapsize;
  fs ! fs_rootstart := b ! sb_rootstart; 
  fs ! fs_rootsize := b ! sb_rootsize; 
  fs ! fs_firstfree := b ! sb_firstfree;
  resultis r }

/*read inode table from disk to mem */
let read_inodetable(fs) be
{ let itable = newvec(fs ! fs_inodesize * 128),
      i = devctl(dc_disc_read, fs ! fs_discnum, fs ! fs_inodestart,
				 fs ! fs_inodesize, itable); 
  if i < 0 then
  { out("read_inodetable dc_disc_read error %d\n", i);
	freevec(itable) }
  fs ! fs_inodetable := itable;
  resultis i }

/* read blockmap from disc to mem */
let read_blockmap(fs) be
{ let blockmap = newvec(fs ! fs_blockmapsize * 128),
	  i = devctl(dc_disc_read, fs ! fs_discnum, fs ! fs_blockmapstart,
				 fs ! fs_blockmapsize, blockmap);
  if i < 0 then
  { out("read_blockmap dc_disc_read error %d\n", i);
    freevec(blockmap) }
  fs ! fs_blockmap := blockmap;
  //out("blockmap first words=%b\n", blockmap ! 0);//debug
  resultis i }

/*read root directory entry from disc to mem*/
let read_rootdir(fs) be
{ let rd = newvec(fs ! fs_rootsize * 128),
      r = devctl(dc_disc_read, fs ! fs_discnum, fs ! fs_rootstart,
                 fs ! fs_rootsize, rd);
  if r < 0 then 
  { out("read_rootdir dc_disc_read error %d\n", r);
    freevec(rd) }
  fs ! fs_rootdir := rd;
  resultis r }

/* write datablocks with all zeros */
let format_datablocks(fs) be
{ let b = vec words_per_block, x;
  for i = 0 to 127 do b ! i := 0;
  out("fs_firstfree = %d\n", fs ! fs_firstfree);
  for i = fs ! fs_firstfree to fs ! fs_nblocks - 1 do
	x := devctl(dc_disc_write, fs ! fs_discnum, i, 1, b);
  if x = 1 then
	out("disc %d formated!!!\n", fs ! fs_discnum) }

/* format the disc to the following
   |super block|inode table|block map|root dir|free data blocks| */
let format(fs) be 
{ let d, r, m, n, tempstr = vec sb_discnamesize/4+1;
  let b = vec words_per_block, x;
  let rootdirname = vec rde_namesize/4 + 2;
  let rootparent_status, rootparent_type;

  while true do
  { outs("which disc unit? ");
    d := inno();
	r := devctl(dc_disc_check, d);
	if r > 0 then break;
	out("error %d\n", r) }
  out("disc unit %d, %d blocks\n", d, r);
  fs ! fs_discnum := d;
  fs ! fs_nblocks := r;
  out("disc label (max 32 chars)? "); //ask for disc lable input
  fs ! fs_discname := strdup(ins(tempstr, sb_discnamesize/4+1)); //see ins()
  //inode table
  outs("size (in blocks) of inode table ? "); //define inode table
  n := inno();
  fs ! fs_inodestart := 1; //inode table start after rood dir 
  fs ! fs_inodesize := n;
  //block map
  //outs("size (in blocks) of free block blockmap?");
  //m := inno();
  fs ! fs_blockmapstart := 1+n;
  fs ! fs_blockmapsize := blockmap_nblocks;
  //root dir
  outs("size (in blocks) of root directory? ");
  r := inno();
  fs ! fs_rootstart := 1+n+blockmap_nblocks; //root start right after block 0 (superblock)
  fs ! fs_rootsize := r;
  outs("root dir name? ");
  ins(rootdirname, rde_namesize);
  //other fs
  fs ! fs_firstfree := 1+r+n+blockmap_nblocks; //superblock, rootdir, inodetabel, ...
  // initialize inodetable
  d := newvec(n * 128);
  for i = 0 to n*128-1 do
    d ! i := 0;
  //initial first inode for root dir
  inode_type of d := inode_dir;
  inode_status of d := inode_exists;
  d ! inode_size := 0;
  d ! inode_nblock := 25;	//9+firstlevel(16)
  d ! inode_time := 0;
  d ! inode_ctime := 0;
  d ! inode_firstblockptrs := fs ! fs_rootstart;// hard coded to point to the first block
  fs ! fs_inodetable := d; //hold in-mem address of inode table
  rootparent_type := sizeof_inode * 4;//pay attention to this indexing thing
  rootparent_status := sizeof_inode * 4 + 1;//pay attention to this 
  byte rootparent_type of d := inode_dir;// the parent dir of root(no)
  byte rootparent_status of d := inode_exists; 

  //initialize blockmap
  d := newvec(blockmap_nblocks * 128);
  out("blockmap_nblocks=%d\n", blockmap_nblocks);
  d ! blockmap_nextused := 3;//point to the same block number
  d ! blockmap_nextfree := 3;
  d ! blockmap_allfree := 6000 - fs ! fs_firstfree;
  for i = 3 to 6000 - fs ! fs_firstfree + 2 do //+2 because i is the index
	d ! i := i + fs ! fs_firstfree - 3;			   //add a shift by the used block	
  fs ! fs_blockmap := d;

  //initialize root dir (with root and its parent)
  d := newvec(r * 128);
  for i = 0 to r*128-1 do //start with the third entry
    d ! i := 0;
  zstr_to_nzstr(rootdirname, d + rde_name, rde_namesize); 
  rde_status of d := rde_exists;	//mark first entry as used
  d ! rde_inodenum := 0;			//hard coded inode number for root 
  //format the second entry of the root directory
  zstr_to_nzstr("..", d + sizeof_rde + rde_name, rde_namesize);
  d +:= sizeof_rde;		//temperory go to second entry
  rde_status of d := rde_exists;//for consistancy with directory
  d ! rde_inodenum := 1;//inode of the second entry set equal root inode (useless)
  d -:= sizeof_rde;		//go back to the beginning
  fs ! fs_rootdir := d;	//hold in-mem address of root directory

  d := write_superblock(fs);
  unless d<0 do d := write_blockmap(fs);
  unless d<0 do d := write_inodetable(fs);
  unless d<0 do d := write_rootdir(fs);
  if d<0 then
  { freevec(fs ! fs_discname); // newvec is allocated in strdup()
    freevec(fs ! fs_inodetable);
    freevec(fs ! fs_blockmap);
    freevec(fs ! fs_rootdir);
    fs ! fs_discnum := 0 } 
  for i = 0 to 127 do b ! i := 0;
  //out("fs_firstfree = %d\n", fs ! fs_firstfree);
  for i = fs ! fs_firstfree to fs ! fs_nblocks - 1 do
	x := devctl(dc_disc_write, fs ! fs_discnum, i, 1, b);
  if x = 1 then
	out("disc %d formated!!!\n", fs ! fs_discnum);
  out("root direcotry name = %s\n", rootdirname) }
 
/*load a exsit disc */
let load(fs) be
        // get an already formatted disc ready for use.
        // the user of this function is responsible for providing an empty
        //    fs object to hold the information generated.
{ let d, r, sb = vec 128;
  while true do
  { outs("which disc unit? ");
    d := inno();
    r := devctl(dc_disc_check, d);
    if r > 2 then break; // disc ready -> break
    out("error %d\n", r) }
  fs ! fs_discnum := d;
  fs ! fs_nblocks := r;
  out("disc unit %d, %d blocks\n", d, r);
  r := read_superblock(fs); //read super block to mem
  if r<0 then
  { fs ! fs_discnum := 0;
    return }
  r := read_rootdir(fs);	//read root directory
  unless r < 0 do r := read_inodetable(fs);	//read inode table 
  unless r < 0 do r := read_blockmap(fs);   //read the block map
  if r<0 then
  { freevec(fs ! fs_discname); //free the allocated heap
    fs ! fs_discnum := 0 } 
  out("disc label '%s'\n", fs ! fs_discname);
  out("inode table blocks %d to %d\n", fs ! fs_inodestart,
       fs ! fs_inodestart + fs ! fs_inodesize -1); 
  out("free blocks blockmap %d to %d\n", fs ! fs_blockmapstart,
	   fs ! fs_blockmapstart + fs ! fs_blockmapsize -1);
  out("root directory blocks %d to %d\n", fs ! fs_rootstart, 
       fs ! fs_rootstart + fs ! fs_rootsize - 1);
  out("first free block: %d\n", fs ! fs_firstfree) }

/* list the root directory */
let listroot(fs) be
{ let entry = fs ! fs_rootdir,
	  nentries = fs ! fs_rootsize * 128 / sizeof_rde,
      fname = vec rde_namesize/4+2, //+2 because 23/4
	  inodenum, inodentry,
      count = -2; //don't want to count the dir its s
  //get inode table
  let inodetable = fs ! fs_inodetable;
   
  for i = 0 to nentries-1 do
  { if rde_status of entry <> rde_free then
    { nzstr_to_zstr(entry + rde_name, fname, rde_namesize);
      //need to access to inode table
      inodenum := entry ! rde_inodenum; 
	  inodentry := inodetable + inodenum * sizeof_inode; 
      //i | type | filesize | numblocks | time | ctime | name
      //out("  \# type       size blocks last modifie"
	  out("%3d %4d %10d %6d %16s %2d\n", i, inode_type of inodentry, 
           inodentry ! inode_size, inodentry ! inode_nblock, fname, inodenum); 
      count +:= 1 }
    entry +:= sizeof_rde }
   out("%d files\n", count) }

/*********************************************************************************
  create a file, only initialize its directory entry and inode num 
*********************************************************************************/
let makefile(fs, fname, length, info) be
{ let entry = fs ! fs_rootdir,
      nentries = fs ! fs_rootsize * 128 / sizeof_rde;
  //get inode table
  let inodetable = fs ! fs_inodetable,
      numinodentry = fs ! fs_inodesize * 128 / sizeof_inode,
      inodenum, inodentry;
  //get the free blockmap
  let blockmap = fs ! fs_blockmap;
  let freeblock_index;

  let nblocks = (length + 511) / 512;
  
}

let makefile_ui(fs) be
{ let fname = vec rde_namesize/4+2,
	  fi = vec sizeof_fi,
	  length;
  outs("file name? ");
  ins(fname, rde_namesize);
  outs("length (in bytes)? ");
  length := inno();
  fi := makefile(fs, fname, length, fi);
  test fi = nil then
    out("failed: %s\n", last_error)
  else
    out("	entry %d firstblock=%d length=%d\n", fi ! fi_number, 
		fi ! fi_firstblock, fi ! fi_length) }


}

/* create a blank file that need more than 9 blocks
   duplication function for debuging
let makefile(fs, fname, length, info) be
{ let entry = fs ! fs_rootdir,
      nentries = fs ! fs_rootsize * 128 / sizeof_rde;
  //get inode table
  let inodetable = fs ! fs_inodetable,
      numinodentry = fs ! fs_inodesize * 128 / sizeof_inode,
      inodenum, inodentry;
  //get the free blockmap
  let blockmap = fs ! fs_blockmap;
  let freeblock_index;

  let t, v;	//for time functions
  let b = newvec(words_per_block), x; //for read a single block from disc
  let b1 = newvec(words_per_block);
  let b2 = newvec(words_per_block);
  let num_second_index_blocks;
  let nblocks = (length + 511) / 512;	//calculate the block
  if fs ! fs_firstfree + nblocks > fs ! fs_nblocks then
      { last_error := err_dscfull;
        resultis nil }
  //t := seconds();
  //datetime(t, v);
  for i = 0 to nentries-1 do				//for each entry in the rootdir
  { if rde_status of entry = 0 then			//find the available entry
    { zstr_to_nzstr(fname, entry + rde_name, rde_namesize); //1. rde name
	  // update root directory entry 
	  rde_status of entry := rde_exists; //2. rde status byte
      for i = 0 to numinodentry - 1 do
	  { if inode_status of inodetable = 0 then //find the available entry
        { test nblocks <= inode_blocksptrsize then
		  { out("file size only need less than 9 blocks\n");
            for j = 0 to nblocks - 1 do		//assign free block < 9
		    { freeblock_index := blockmap ! blockmap_nextfree; 
			  inodetable ! (inode_firstblockptrs + j) := blockmap ! freeblock_index;
			  blockmap ! blockmap_nextfree +:= 1 } }
		  else test nblocks <= words_per_block then
		  { out("file size need one level index!!\n");
			freeblock_index := blockmap ! blockmap_nextfree;
			inodetable ! inode_firstlevelptr := blockmap ! freeblock_index;//indexbloc
			blockmap ! blockmap_nextfree +:= 1;
			//prepare an index block
			for i = 0 to nblocks - inode_blocksptrsize - 1 do
			{ freeblock_index := blockmap ! blockmap_nextfree;
			  b ! i := blockmap ! freeblock_index; 
			  blockmap ! blockmap_nextfree +:= 1 }
			x := devctl(dc_disc_write, fs ! fs_discnum,
						inodetable ! inode_firstlevelptr, 1, b);
			//todo: whether or when need to release this newvec b? 
			if x <> 1 do
			  out("write fisrtlevelptr failed!!! x = %d", x) }
		  else test nblocks <= blockmap ! blockmap_allfree then
		  { out("file size need two level index!!\n");
            freeblock_index := blockmap ! blockmap_nextfree;
			inodetable ! inode_secondlevelptr := blockmap ! freeblock_index;
			blockmap ! blockmap_nextfree +:= 1;
			//calculate how many indexing block to data block needed
			num_second_index_blocks := (nblocks + 127) / 128;//

			for i = 0 to num_second_index_blocks do// fill block ptr in first level 
			{ freeblock_index := blockmap ! blockmap_nextfree;
			  b1 ! i := blockmap ! freeblock_index;	// second level index block allocated 
			  blockmap ! blockmap_nextfree +:= 1; }
			x := devctl(dc_disc_write, fs ! fs_discnum, 
						inodetable ! inode_secondlevelptr, 1, b1);
			if x <> 1 do
			  out("2write secondlevelptr failed!!! x = %d", x); 
			//this for loop is to write the data block indexing blocks 
			for k = 0 to num_second_index_blocks do
			{ for i = 0 to words_per_block -1 do
			  { freeblock_index := blockmap ! blockmap_nextfree;
				b2 ! i := blockmap ! freeblock_index;
				blockmap ! blockmap_nextfree +:= 1 }
			  x := devctl(dc_disc_write, fs ! fs_discnum, b1 ! k, 1, b2);
			  if x <> 1 do
			  out("write datablock index block failed!!! x = %d",x) } }
		  else 
		  { out("out of file system capacity\n");
			break } 
		  //update the fs ! fs_firstfree
		  //todo: this blockmap_nextfree might not right
          freeblock_index := blockmap ! blockmap_nextfree;
		  fs ! fs_firstfree := blockmap ! freeblock_index;
		  blockmap ! blockmap_allfree -:= nblocks; 
		  //write the entry back to disc like create dir. 
		  x := devctl(dc_disc_write, fs ! fs_discnum, fs ! fs_rootstart, 
					  fs ! fs_rootsize, fs ! fs_rootdir);
		  if x <> fs ! fs_rootsize do
		    out("write to \"root\" block failed!!!\n");
		  inodenum := i;	//find the first available inode table entry
		  inode_type of inodetable := inode_file; //0 is file, 1 is dir 
		  inode_status of inodetable := inode_exists;
		  inodetable ! inode_size := length; 
		  inodetable ! inode_nblock := nblocks; 
		  inodetable ! inode_time := 0; //todo: manipulate time functions
		  inodetable ! inode_ctime := 0;// 
		  break } 
	    inodetable +:= sizeof_inode }
      entry ! rde_inodenum := inodenum; //3. rde inode number 
	  info ! fi_status := rde_exists;
	  info ! fi_number := inodenum;
	  info ! fi_firstblock := inodetable ! inode_firstblockptrs;
      info ! fi_length := length;
	  resultis info }
    entry +:= sizeof_rde }
  last_error := err_dirfull;
  info ! fi_status := rde_free;
  resultis nil }
*/

/* make directory */
let makedir(fs, dirname, info) be
{ let entry = fs ! fs_rootdir,
	  nentries = fs ! fs_rootsize * 128 / sizeof_rde;
  let curdirinode = entry ! rde_inodenum;//get current dir inode number
  //get inode table
  let inodetable = fs ! fs_inodetable,
      numinodentry = fs ! fs_inodesize * 128 / sizeof_inode,
      inodenum, inodentry;
  //get blockmap
  let blockmap = fs ! fs_blockmap, freeblock_index;

  let b = newvec(2 * words_per_block), x;
  for i = 0 to nentries-1 do
  { if rde_status of entry = 0 then
    { zstr_to_nzstr(dirname, entry + rde_name, rde_namesize); //1. rde name
	  rde_status of entry := rde_exists;	//2. rde status byte
      for j = 0 to numinodentry-1 do		//new dir inode
	  { if inode_status of inodetable = 0 then
        { inodenum := j;	//find the first available inode table entry
		  inode_type of inodetable := inode_dir; //0 is file, 1 is dir 
		  inode_status of inodetable := inode_exists;
		  inodetable ! inode_size := 0;		//number of files in this dir
		  inodetable ! inode_nblock := 11;	//give all 11 ptrs
		  inodetable ! inode_time := 0;		//todo: manipulate time functions
		  inodetable ! inode_ctime := 0;
		  freeblock_index := blockmap ! blockmap_nextfree;
		  inodetable ! inode_firstblockptrs := blockmap ! freeblock_index;//initialize the first ptr
		  blockmap ! blockmap_nextfree +:= 2;//take 2 block for new dir
		  freeblock_index := blockmap ! blockmap_nextfree;
		  fs ! fs_firstfree := blockmap ! freeblock_index;//update the fs_firstfree
		  //prepare the directory content block
		  zstr_to_nzstr(".", b + rde_name, rde_namesize);
		  rde_status of b := rde_exists; //2. rde status byte
		  b ! rde_inodenum := inodenum; //3. rde inode number 
		  b +:= sizeof_rde;
		  zstr_to_nzstr("..", b + rde_name, rde_namesize);
		  rde_status of b := rde_exists;
		  b ! rde_inodenum := curdirinode;
		  b -:= sizeof_rde;
		  x := devctl(dc_disc_write, fs ! fs_discnum, 
					  inodetable ! inode_firstblockptrs, fs ! fs_rootsize, b);
          if x <> fs ! fs_rootsize do
			out("write to new dir content block failed!!!\n");
		  //update the total available blocks
		  blockmap ! blockmap_allfree -:= 2;//create new dir consume 2 blocks 

		  break } 
	    inodetable +:= sizeof_inode }
      entry ! rde_inodenum := inodenum; //3. rde inode number 

      x := devctl(dc_disc_write, fs ! fs_discnum, fs ! fs_rootstart, 
				  fs ! fs_rootsize, fs ! fs_rootdir );
      if x <> fs ! fs_rootsize do
		out("write to \"root\" block failed!!!\n");
				 
	  info ! fi_status := rde_exists;
	  info ! fi_number := inodenum;
	  info ! fi_firstblock := inodetable ! inode_firstblockptrs;
      info ! fi_length := 0;
	  resultis info }
    entry +:= sizeof_rde }
  last_error := err_dirfull;
  info ! fi_status := rde_free;
  resultis nil }

let makedir_ui(fs) be
{ let dirname = vec rde_namesize/4+2,
	  fi = vec sizeof_fi;	//because directory is also a file
  out("directory name? ");
  ins(dirname, rde_namesize);
  fi := makedir(fs, dirname, fi);
  test fi = nil then
	out("failed: %s\n", last_error)
  else
	out("\n	inode=%d, dirname=%s\n", fi ! fi_number, dirname) }

/* change current directory */
let chdir(fs, dirname, info) be
{ let entry = fs ! fs_rootdir,
	  nentries = fs ! fs_rootsize * 128 / sizeof_rde,
	  thisname = vec rde_namesize/4+2;
  //get inode table
  let inodetable = fs ! fs_inodetable,
      numinodentry = fs ! fs_inodesize * 128 / sizeof_inode,
      inodenum, inodentry;
  let b, x;
  for i = 0 to nentries-1 do
  { if rde_status of entry <> rde_free then	//find in rde
    { nzstr_to_zstr(entry + rde_name, thisname, rde_namesize);
	  if dirname %streq thisname then			//find the entry in rde
	  { inodenum := entry ! rde_inodenum;
		inodentry := inodetable + inodenum * sizeof_inode;//+2 for cur dir and parent dir
		info ! fi_status := rde_status of entry;
		info ! fi_number := inodenum;
		info ! fi_firstblock := inodentry ! inode_firstblockptrs;
		info ! fi_length := inodentry ! inode_size;
		// write current dir in-mem datastructure to disc
		x := devctl(dc_disc_write, fs ! fs_discnum,
				   fs ! fs_rootstart, fs ! fs_rootsize, fs ! fs_rootdir);
		// read the directory block into mem
		b := newvec(2*words_per_block);
		x := devctl(dc_disc_read, fs ! fs_discnum, 
					inodentry ! inode_firstblockptrs, fs ! fs_rootsize, b); 	
		fs ! fs_rootdir := b;
		out("inodentry ! inode_firstblockptrs=%d\n", inodentry ! inode_firstblockptrs);//debug
		fs ! fs_rootstart := inodentry ! inode_firstblockptrs;//todo: attention
	    resultis info } }
    entry +:= sizeof_rde }
  last_error := err_notfound;
  info ! fi_status := rde_free;
  resultis nil }

/* change the directory ui*/
let chdir_ui(fs) be
{ let dirname = vec de_namesize/4+2,
	  fi = vec sizeof_fi;	//because directory is also a file
  out("which directory? ");
  ins(dirname, de_namesize);
  fi := chdir(fs, dirname, fi);
  test fi = nil then
	out("failed: %s\n", last_error)
  else
	out("	change to dir=%s inode=%d, firstblock=%d\n", 
			dirname, fi ! fi_number, fi ! fi_firstblock) }

/* find the exist file */
let findfile(fs, fname, info) be
{ let entry = fs ! fs_rootdir,
	  nentries = fs ! fs_rootsize * 128 / sizeof_rde,
	  thisname = vec rde_namesize/4+2;

  let inodetable = fs ! fs_inodetable,
      numinodentry = fs ! fs_inodesize * 128 / sizeof_inode,
      inodenum, inodentry;
  for i = 0 to nentries-1 do
  { if rde_status of entry <> rde_free then	//find in rde
    { nzstr_to_zstr(entry + rde_name, thisname, rde_namesize);
	  if fname %streq thisname then			//find the entry in rde
	  { inodenum := entry ! rde_inodenum;
		inodentry := inodetable + inodenum * sizeof_inode; 
		info ! fi_status := rde_status of entry;
		info ! fi_number := inodenum;
		info ! fi_firstblock := inodentry ! inode_firstblockptrs;
		info ! fi_length := inodentry ! inode_size;
	    resultis info } }
    entry +:= sizeof_rde }
  last_error := err_notfound;
  info ! fi_status := rde_free;
  resultis nil }

let findfile_ui(fs) be
{ let wantname = vec rde_namesize/4+2,
	  fi = vec sizeof_fi;
  outs("file name? ");
  ins(wantname, rde_namesize);
  fi := findfile(fs, wantname);
  test fi = nil then
    out("failed: %s\n", last_error)
  else
    out("   inodenum=%d firstblock=%d length=%d\n",
        fi ! fi_number, fi ! fi_firstblock, fi ! fi_length) }

/* open an existing file */
let open(fs, fname, mode, f) be
{ let entry = fs ! fs_rootdir,
	  nentries = fs ! fs_rootsize * 128 / sizeof_rde,
	  thisname = vec rde_namesize/4+2;

  let inodetable = fs ! fs_inodetable,
      numinodentry = fs ! fs_inodesize * 128 / sizeof_inode,
      inodenum, inodentry;
  //let f = newvec(sizeof_filebuf);
  let b = newvec(words_per_block), x;

  out("in open function !\n");

  if mode <> 'r' /\ mode <> 'w' then	//check mode
  { last_error := err_wrongmode;
    out("in returning the nil check");
	resultis nil }

  out("in open function !\n");

  //look for the file
  for i = 0 to nentries-1 do
  { if rde_status of entry <> rde_free then	//find in rde
    { nzstr_to_zstr(entry + rde_name, thisname, rde_namesize);
	  if fname %streq thisname then			//find the entry in rde
	  { inodenum := entry ! rde_inodenum;
		inodentry := inodetable + inodenum * sizeof_inode; 
        // prepare the in-mem file info and file buf
		f ! file_mode := mode;
		f ! file_inode := inodenum;
		f ! file_size := inodentry ! inode_size;
		f ! file_nblock := inodentry ! inode_nblock;
		f ! file_firstlevelptr := inodentry ! inode_firstlevelptr;
        f ! file_secondlevelptr := inodentry ! inode_secondlevelptr;
		out("Open: in the if !!\n");
		out("Open: f ! file_nblock=%d\n", f ! file_nblock);
		//for large files
		test f ! file_nblock > (words_per_block + file_ndatablockptrs) then//>137
		{ f ! file_secondindexentryN := 0;// -1 could be useful in write function
		  f ! file_thirdindexentryN := 0;
		  //read the two level index first level index block
		  x := devctl(dc_disc_read, fs ! fs_discnum,
				inodentry ! inode_secondlevelptr, 1, f + file_secondindexblock);
		  if x <> 1 do
		    out("Open file %s failed: read secondindexblock...", fname); 
		  //read the two level index second level index block
		  x := devctl(dc_disc_read, fs ! fs_discnum,
				f ! file_secondindexblock, 1, f + file_thirdindexblock);
		  if x <> 1 do
		    out("Open file %s failed: read thirdindexblock...", fname);
		  x := devctl(dc_disc_read, fs ! fs_discnum,
				f ! file_thirdindexblock, 1, f + file_currentdatablock);
		  if x <> 1 do
			out("read \"this block\" failed: read file_currentdatablock...");
		  f ! file_thisblockn := f ! file_thirdindexblock;
		  f ! file_offset := 0 }
		//for media files
		else test f ! file_nblock > file_ndatablockptrs then
		{ f ! file_firstindexentryN := 0;//could be useful in write function
		  x := devctl(dc_disc_read, fs ! fs_discnum, 
				inodentry ! inode_firstlevelptr, 1, f + file_firstindexblock);
          if x <> 1 do
			out("Open: Open file %s failed: read firstindexblock...", fname); 
          x := devctl(dc_disc_read, fs ! fs_discnum,
				f ! file_firstindexblock, 1, f + file_currentdatablock);
		  if x <> 1 do
			out("Open: read \"this block\" failed: read file_currentdatablock...");
		  f ! file_thisblockn := f ! file_firstindexblock;
		  f ! file_offset := 0 }
		//for small files
		else //test f ! file_nblock <= file_ndatablockptrs then
		//else test f ! file_nblock <= file_ndatablockptrs then
		{ f ! file_datablockptrN := 0;
		  for i = 0 to (f ! file_nblock) - 1 do
		  { let f_index = file_datablockptr1 + i,
			    i_index = inode_firstblockptrs + i;
		    f ! f_index := inodentry ! i_index } 
		  //read the current data block(for open, the first block)
		  out("Open: f ! file_datablockptr1=%d\n",f ! file_datablockptr1); 
		  x := devctl(dc_disc_read, fs ! fs_discnum,
					  f ! file_datablockptr1, 1, f + file_currentdatablock );
		  if x <> 1 do
		    out("Open: Open file %s failed: read datablock...", fname); 
		  //update current block number and offset
		  f ! file_thisblockn := f ! file_datablockptr1;//todo: first block because open
		  f ! file_offset := 0 }  //open point to the begining of the file.
        //else
		  //out("else!!!????\n");
	  resultis f } }
    entry +:= sizeof_rde }

  resultis nil }

/* set position to offset bytes */
let lseek(fs, filebuf, pos) be
{ let totalblocks = (pos + 511)/ 512;//totalblocks = fullblocks + 1
  let offset = pos rem 512;
  let filesize = filebuf ! file_size;
  let blocks_offset, secondlevel_blockn, thirdlevel_blockn, firstlevel_blockn,x; 
  
  if pos = 0 then
	resultis filebuf;	

  test filebuf ! file_nblock > 128*128 then
  { out("fatal error, file too big!!!");
	return }
  //if the pos is need two level index
  else test filebuf ! file_nblock > words_per_block then
  {	//calculate the index and entry following the instructor's note. 
	filebuf ! file_thirdindexentryN := (totalblocks + 127) rem words_per_block;
    totalblocks := (totalblocks + 127) / words_per_block;
    filebuf ! file_secondindexentryN := (totalblocks rem words_per_block) - 1;
    //read the appropriate second level index block into buffer
	x := devctl(dc_disc_read, fs ! fs_discnum, 
			file_secondlevelptr, 1, filebuf + file_secondindexblock);
    //read the appropriate third level index block into buffer
    secondlevel_blockn := filebuf ! (file_secondindexblock +(filebuf ! file_secondindexentryN)); 
    x := devctl(dc_disc_read, fs ! fs_discnum, 
			secondlevel_blockn, 1, filebuf + file_thirdindexblock);
	//read the current data block.
    thirdlevel_blockn := filebuf ! (file_thirdindexblock + (filebuf ! file_thirdindexentryN));
	x := devctl(dc_disc_read, fs ! fs_discnum, 
			thirdlevel_blockn, 1, filebuf + file_currentdatablock);
	//update offset and current block number
	filebuf ! file_offset := offset;
    filebuf ! file_thisblockn := thirdlevel_blockn } 
  //if the pos is need only one level index
  else test filebuf ! file_nblock > file_ndatablockptrs then
  {	filebuf ! file_firstindexentryN := totalblocks - 1;
	//read the current data block
    firstlevel_blockn := filebuf ! (file_firstindexblock + (filebuf ! file_firstindexentryN));
    x := devctl(dc_disc_read, fs ! fs_discnum, 
			firstlevel_blockn, 1, filebuf + file_currentdatablock);
    filebuf ! file_offset := offset;
    filebuf ! file_thisblockn := firstlevel_blockn } 
  //only have less than 9 blocks
  else test filebuf ! file_nblock < file_ndatablockptrs then
  { //read the current data block
    filebuf ! file_datablockptrN := totalblocks - 1;
    x := devctl(dc_disc_read, fs ! fs_discnum, 
			filebuf ! (file_datablockptr1 + totalblocks - 1), 1,
			filebuf + file_currentdatablock);
    filebuf ! file_offset := offset;
    filebuf ! file_thisblockn := filebuf ! (file_datablockptr1 + totalblocks - 1)}
    //out("lseek: filebuf ! file_thisblockn=%d\n", filebuf ! file_thisblockn) } 
  else
	out("else is here!!!\n");

  resultis filebuf } 

/* write a pattern repeatedly to the file */
let write(fs, filebuf, pattern, count) be
{ let block_offset = filebuf ! file_offset;//offset inside block 
  let fullblocks = (count - (512 - block_offset) ) / 512;//
  let remain = (count - (512 - block_offset) ) rem 512;
  let secondlevel_blockn,x;
  
  test (filebuf ! file_nblock) > 128*128 then
  { out("fatal error, file too big!!!");
	return }
  //todo: for large file
  else test filebuf ! file_nblock > words_per_block then
  { //prepare the partial block 
    for i = block_offset to 512 - 1 do
	{ byte i of (filebuf + file_currentdatablock) := byte 1 of pattern }
	x := devctl(dc_disc_write, fs ! fs_discnum, filebuf ! file_thisblockn,
			1, filebuf ! file_currentdatablock);
    if x <> 1 do
	  outs("Write file failed!! "); 
	//update this_blockn todo: take care of the transient to the next index
	//block
	test filebuf ! file_thirdindexentryN <= 127 do
	{ filebuf ! file_thirdindexentryN +:= 1;
      filebuf ! file_thisblockn := filebuf ! (file_thirdindexblock
											  + (filebuf ! file_thirdindexentryN)) }
	else
	{ //read the next third level index block
      filebuf ! file_secondindexentryN +:= 1;
	  secondlevel_blockn := filebuf ! (file_secondindexblock+(filebuf ! file_secondindexentryN));
	  x := devctl(dc_disc_write, fs ! fs_discnum, 
					secondlevel_blockn, 1, filebuf ! file_thirdindexblock);
      if x <> 1 do
	    outs("Write file failed!! "); 
      filebuf ! file_thisblockn := filebuf ! file_thirdindexblock;
      filebuf ! file_thirdindexentryN := 0 }
    //update the full blocks 
    for i = 0 to fullblocks do
	{ for i = 0 to 512 - 1 do
      { byte i of (filebuf + file_currentdatablock) := byte 1 of pattern }
	  x := devctl(dc_disc_write, fs ! fs_discnum, filebuf ! file_thisblockn,
					1, filebuf ! file_currentdatablock); 
	  if x <> 1 do
	    outs("write file failed!!");	
      test filebuf ! file_thirdindexentryN <= 127 do
	  { filebuf ! file_thirdindexentryN +:= 1;
        filebuf ! file_thisblockn := filebuf ! (file_thirdindexblock
											  + (filebuf ! file_thirdindexentryN)) }
      else
	  { //read the next third level index block
        filebuf ! file_secondindexentryN +:= 1;
	    secondlevel_blockn := filebuf ! (file_secondindexblock+(filebuf ! file_secondindexentryN));
	    x := devctl(dc_disc_write, fs ! fs_discnum, 
					secondlevel_blockn, 1, filebuf ! file_thirdindexblock);
        if x <> 1 do
	      outs("Write file failed!! "); 
        filebuf ! file_thisblockn := filebuf ! file_thirdindexblock;
        filebuf ! file_thirdindexentryN := 0 } }
    //update the remaining blocks
    for i = 0 to remain - 1 do
    { byte i of (filebuf + file_currentdatablock) := byte 1 of pattern }
	x := devctl(dc_disc_write, fs ! fs_discnum, filebuf ! file_thisblockn,
				1, filebuf ! file_currentdatablock);
	if x <> 1 do
	  outs("write file failed!") }
  //todo: for medium file
  else test filebuf ! file_nblock > file_ndatablockptrs then
  { //prepare the partial block 
    for i = block_offset to 512 - 1 do
	{ byte i of (filebuf + file_currentdatablock) := byte 1 of pattern }
	x := devctl(dc_disc_write, fs ! fs_discnum, filebuf ! file_thisblockn,
			1, filebuf ! file_currentdatablock);
    if x <> 1 do
	  outs("Write file failed!! "); 
	//update this_blockn
    filebuf ! file_firstindexentryN +:= 1;
    filebuf ! file_thisblockn := filebuf ! (file_firstindexblock 
											+ (filebuf ! file_firstindexentryN));
    //fill the fullblocks
	for i = 0 to fullblocks - 1 do
	{ for i = 0 to 512 - 1 do
      { byte i of (filebuf + file_currentdatablock) := byte 1 of pattern }
	  x := devctl(dc_disc_write, fs ! fs_discnum, filebuf ! file_thisblockn,
					1, filebuf ! file_currentdatablock); 
	  if x <> 1 do
	    outs("write file failed!!");	
      filebuf ! file_firstindexentryN +:= 1;
      filebuf ! file_thisblockn := filebuf ! (file_firstindexblock 
											  + (filebuf ! file_firstindexentryN)) }
	//fill the remaining blocks
    for i = 0 to remain - 1 do
    { byte i of (filebuf + file_currentdatablock) := byte 1 of pattern }
	x := devctl(dc_disc_write, fs ! fs_discnum, filebuf ! file_thisblockn,
					1, filebuf ! file_currentdatablock);
	if x <> 1 do
	  outs("write file failed!!") } 
  //todo: for small file
  else test filebuf ! file_nblock < file_ndatablockptrs then
  { //prepare the partial block
    for i = block_offset to 512 - 1  do
    //{ byte i of (filebuf + file_currentdatablock) := pattern }
    { !(filebuf + file_currentdatablock + i) := "a" }

    x := devctl(dc_disc_write, fs ! fs_discnum, filebuf ! file_thisblockn,
				1, filebuf + file_currentdatablock);
    if x <> 1 do
	  outs("Write file failed!! "); 
    //update this block
	filebuf ! file_datablockptrN +:= 1;
    filebuf ! file_thisblockn := filebuf ! (file_datablockptr1 + (filebuf ! file_datablockptrN));
    //fill the fullblocks
	for i = 0 to fullblocks - 1 do
	{ for i = 0 to 512 - 1 do
      { !(filebuf + file_currentdatablock + i) := "a" }
	  x := devctl(dc_disc_write, fs ! fs_discnum, filebuf ! file_thisblockn,
					1, filebuf + file_currentdatablock); 
	  if x <> 1 do
	    outs("write file failed!!");	
      filebuf ! file_datablockptrN +:= 1;
	  filebuf ! file_thisblockn := filebuf ! (file_datablockptr1+(filebuf ! file_datablockptrN));
    out("write: 3. thisblockn=%d\n", filebuf ! file_thisblockn) }
    for i = 0 to remain - 1 do
    { byte i of (filebuf + file_currentdatablock) := "a" }
	x := devctl(dc_disc_write, fs ! fs_discnum, filebuf ! file_thisblockn,
					1, filebuf + file_currentdatablock);
	if x <> 1 do
	  outs("write file failed!!\n") }
    else 
      outs("else is here!!\n");	
	outs("write file compeleted!!\n") } 

let write_ui(fs) be
{ let filename = vec rde_namesize/4+2,
	  filebuf = newvec(sizeof_filebuf);
  let len, pos, pattern = "A";
  outs("file name? ");
  ins(filename, rde_namesize);
  filebuf := open(fs, filename, 'w', filebuf);//open file

  if filebuf = nil then
  { out("failed: %s\n", last_error);
	return }
  outs("write from position(nth bytes)? ");
  pos := inno();
  filebuf := lseek(fs, filebuf, pos);//reposit the file
  outs("how many bytes to write? ");
  len := inno();
  //outs("what character to write? ");
  //ins(pattern, 2);
  write(fs, filebuf, pattern, len);	 //write the pattern to the file
  outs("write %d bytes finished!\n", len) }

let read(fs, filebuf, count) be
{ let block_offset = filebuf ! file_offset;//offset inside block 
  let fullblocks = (count - (512 - block_offset) ) / 512;//
  let remain = (count - (512 - block_offset) ) rem 512;
  let secondlevel_blockn,x,pattern;
  
  test (filebuf ! file_nblock) > 128*128 then
  { out("fatal error, too big!!!");
	return }
  //todo: for large file
  else test filebuf ! file_nblock > words_per_block then
  { //prepare the partial block 
    for i = block_offset to 512 - 1 do
	{ byte i of (filebuf + file_currentdatablock) := byte 1 of pattern }
	x := devctl(dc_disc_read, fs ! fs_discnum, filebuf ! file_thisblockn,
			1, filebuf ! file_currentdatablock);
    if x <> 1 do
	  outs("Read: read file failed!! "); 
	//update this_blockn todo: take care of the transient to the next index
	//block
	test filebuf ! file_thirdindexentryN <= 127 do
	{ filebuf ! file_thirdindexentryN +:= 1;
      filebuf ! file_thisblockn := filebuf ! (file_thirdindexblock
											  + (filebuf ! file_thirdindexentryN)) }
	else
	{ //read the next third level index block
      filebuf ! file_secondindexentryN +:= 1;
	  secondlevel_blockn := filebuf ! (file_secondindexblock+(filebuf ! file_secondindexentryN));
	  x := devctl(dc_disc_read, fs ! fs_discnum, 
					secondlevel_blockn, 1, filebuf ! file_thirdindexblock);
      if x <> 1 do
	    outs("Write file failed!! "); 
      filebuf ! file_thisblockn := filebuf ! file_thirdindexblock;
      filebuf ! file_thirdindexentryN := 0 }
    //update the full blocks 
    for i = 0 to fullblocks do
	{ for i = 0 to 512 - 1 do
      { byte i of (filebuf + file_currentdatablock) := byte 1 of pattern }
	  x := devctl(dc_disc_read, fs ! fs_discnum, filebuf ! file_thisblockn,
					1, filebuf ! file_currentdatablock); 
	  if x <> 1 do
	    outs("write file failed!!");	
      test filebuf ! file_thirdindexentryN <= 127 do
	  { filebuf ! file_thirdindexentryN +:= 1;
        filebuf ! file_thisblockn := filebuf ! (file_thirdindexblock
											  + (filebuf ! file_thirdindexentryN)) }
      else
	  { //read the next third level index block
        filebuf ! file_secondindexentryN +:= 1;
	    secondlevel_blockn := filebuf ! (file_secondindexblock+(filebuf ! file_secondindexentryN));
	    x := devctl(dc_disc_read, fs ! fs_discnum, 
					secondlevel_blockn, 1, filebuf ! file_thirdindexblock);
        if x <> 1 do
	      outs("Write file failed!! "); 
        filebuf ! file_thisblockn := filebuf ! file_thirdindexblock;
        filebuf ! file_thirdindexentryN := 0 } }
    //update the remaining blocks
    for i = 0 to remain - 1 do
    { byte i of (filebuf + file_currentdatablock) := byte 1 of pattern }
	x := devctl(dc_disc_read, fs ! fs_discnum, filebuf ! file_thisblockn,
				1, filebuf ! file_currentdatablock);
	if x <> 1 do
	  outs("write file failed!") }
  //todo: for medium file
  else test filebuf ! file_nblock > file_ndatablockptrs then
  { //prepare the partial block 
    for i = block_offset to 512 - 1 do
	{ byte i of (filebuf + file_currentdatablock) := byte 1 of pattern }
	x := devctl(dc_disc_read, fs ! fs_discnum, filebuf ! file_thisblockn,
			1, filebuf ! file_currentdatablock);
    if x <> 1 do
	  outs("Write file failed!! "); 
	//update this_blockn
    filebuf ! file_firstindexentryN +:= 1;
    filebuf ! file_thisblockn := filebuf ! (file_firstindexblock 
											+ (filebuf ! file_firstindexentryN));
    //fill the fullblocks
	for i = 0 to fullblocks - 1 do
	{ for i = 0 to 512 - 1 do
      { byte i of (filebuf + file_currentdatablock) := byte 1 of pattern }
	  x := devctl(dc_disc_read, fs ! fs_discnum, filebuf ! file_thisblockn,
					1, filebuf ! file_currentdatablock); 
	  if x <> 1 do
	    outs("write file failed!!");	
      filebuf ! file_firstindexentryN +:= 1;
      filebuf ! file_thisblockn := filebuf ! (file_firstindexblock 
											  + (filebuf ! file_firstindexentryN)) }
	//fill the remaining blocks
    for i = 0 to remain - 1 do
    { !(filebuf + file_currentdatablock + i) := "a" }
	x := devctl(dc_disc_read, fs ! fs_discnum, filebuf ! file_thisblockn,
					1, filebuf ! file_currentdatablock);
	if x <> 1 do
	  outs("write file failed!!") } 
  //todo: for small file
  else test filebuf ! file_nblock < file_ndatablockptrs then
  { //prepare the partial block
	out("write: in the correct test\n");
    for i = block_offset to 512 - 1  do
    //{ byte i of (filebuf + file_currentdatablock) := pattern }
    { out("%s", ! (filebuf + file_currentdatablock + i)) }

    x := devctl(dc_disc_read, fs ! fs_discnum, filebuf ! file_thisblockn,
			1, filebuf + file_currentdatablock);
    if x <> 1 do
	  outs("Write file failed!! "); 
    //update this block
	filebuf ! file_datablockptrN +:= 1;
    filebuf ! file_thisblockn := filebuf ! (file_datablockptr1 + (filebuf ! file_datablockptrN));
    //fill the fullblocks
	for i = 0 to fullblocks - 1 do
	{ for i = 0 to 512 - 1 do
      { out("%s", ! (filebuf + file_currentdatablock + i)) };
	  x := devctl(dc_disc_read, fs ! fs_discnum, filebuf ! file_thisblockn,
					1, filebuf + file_currentdatablock); 
	  if x <> 1 do
	    outs("write file failed!!");	
      filebuf ! file_datablockptrN +:= 1;
	  filebuf ! file_thisblockn := filebuf ! (file_datablockptr1+(filebuf ! file_datablockptrN));
    for i = 0 to remain - 1 do
    {  out("%s", ! (filebuf + file_currentdatablock + i)) }
	x := devctl(dc_disc_read, fs ! fs_discnum, filebuf ! file_thisblockn,
					1, filebuf + file_currentdatablock);
	if x <> 1 do
	  outs("write file failed!!\n") } }
  else
    out("a");

  outs("write file compeleted!!\n") } 

let read_ui(fs) be
{ let filename = vec rde_namesize/4+2,
	  filebuf, len, pos, pattern;
  outs("file name? ");
  ins(filename, rde_namesize);
  filebuf := open(fs, filename, 'w');//open file
  if filebuf = nil then
  { out("failed: %s\n", last_error);
	return }
  outs("read from position(nth bytes)? ");
  pos := inno();
  filebuf := lseek(fs, filebuf, pos);//reposit the file
  outs("how many bytes to read? ");
  len := inno();
  read(fs, filebuf, len);	 //write the pattern to the file
  outs("read %d bytes finished!", len) }

let deletefile_ui(fs) be
{ }

/* usage instructions*/
let show_usage() be
{ outs("\n\n Hello, this is a sensible file system which support\n");
  outs("    Support the following operations(commands):\n");
  outs(" \tformat --format a physical disc\n");
  outs(" \tload   --load a ready to use disc\n");
  outs(" \ttouch  --create a blank file\n");
  outs(" \tmkdir  --create a directory\n");
  outs(" \tcd     --change directory\n");
  outs(" \tls     --list directory contents\n");
  outs(" \tfind   --find file by name in current directory\n");
  outs(" \twrite  --write content to file\n");
  outs(" \tshow   --read content from file\n");
  //outs(" \tdelete --delete a file\n");
  outs(" \tq      --read content from file\n");
}

/*start function*/
let start() be
{ manifest { heapsize = 10240 }
  let heap = vec heapsize,
      cmd = vec 20,
      fs = vec sizeof_fs;
  init(heap, heapsize);
  fs ! fs_discnum := 0;
  show_usage();

  while fs ! fs_discnum = 0 do
  { outs("> ");
    ins(cmd, 20);
    test cmd %streq "format" then
      format(fs)
    else test cmd %streq "load" then
      load(fs)
    else test cmd %streq "q" then
      break
    else
      out("unrecognised command '%s'\nsay format, load, or q\n", cmd) }
  
  while true do
  { outs("rui-sdfs> ");
    ins(cmd, 20);
    //test cmd %streq "dir" then
    test cmd %streq "ls" then
      listroot(fs)
    else test cmd %streq "touch" then
      makefile_ui(fs)
    else test cmd %streq "find" then
      findfile_ui(fs)
	else test cmd %streq "write" then
	  write_ui(fs)
	else test cmd %streq "cat" then
	  read_ui(fs)
	else test cmd %streq "mkdir" then
	  makedir_ui(fs)
    else test cmd %streq "cd" then
	  chdir_ui(fs)
    else test cmd %streq "delete" then
      deletefile_ui(fs)
    else test cmd %streq "q" then
      break
    else
      out("unrecognised command '%s'\n\tsay ls, touch, find, delete, write, cat, mkdir, cd or exit\n", cmd) }
  write_blockmap(fs);
  write_rootdir(fs);
  write_inodetable(fs);
  write_superblock(fs) }
