import "io"

manifest             // fs = file system
{ fs_discnum = 0,       // which disc drive
  fs_nblocks = 1,       // total number of blocks
  fs_rootstart = 2,
  fs_rootsize = 3,
  fs_firstfree = 4,
  fs_rootdir = 5,       // pointer to in-memory copy
  fs_discname = 6,      // pointer to string
  fs_sbupdated = 7,     // when last written to disc
  sizeof_fs = 8 }

manifest             // rde = root directory entry
{ rde_name = 0,
  rde_namesize = 23,
  rde_status = byte 23,
     rdes_free = 0,
     rdes_exists = 1,
  rde_firstblock = 6,
  rde_length = 7,
  sizeof_rde = 8 }

manifest             // fi = file information, the useful information
                     //      from a directory entry
{ fi_status = 0,
  fi_number = 1,
  fi_firstblock = 2,
  fi_length = 3,
  sizeof_fi = 4 }

manifest             // sb = superblock, exactly as on disc
{ sb_discname = 0,
     sb_discnamesize = 32,
  sb_rootstart = 8,
  sb_rootsize = 9,
  sb_firstfree = 10,
  sb_updated = 11 }

manifest             // file = open file, information used by higher level
                     // functions open, read, write, close. Includes buffer space
{ file_mode = 0,          // 'R' or 'W'
  file_filesys = 1,       // pointer to the fs object
  file_thisblockn = 2,    // which disc block we're working on
  file_remaining = 3,     // bytes remaining unread/unwritten in file
  file_position = 4,      // current position within the 512 byte buffer
  file_buffer = 5,        // pointer to the buffer
  sizeof_file = 6 + 128 }

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

let strdup(s) be             // copy of a string, but in heap memory
{ let len = strlen(s)/4 + 1;
  let r = newvec(len);
  for i = 0 to len-1 do
    r ! i := s ! i;
  resultis r }

let streq(a, b) be           // are two strings equal?
{ let i = 0;
  while true do
  { let ca = byte i of a, cb = byte i of b;
    if ca <> cb then resultis false;
    if ca = 0 then resultis true;
    i +:= 1 } }

let zstr_to_nzstr(src, dst, size) be
           // copy a string
              // from src, a normal zero terminated string
              // to dst, (size) bytes long, may not be zero terminated
{ let len = 0;
  while len<size do
  { let c = byte len of src;
    if c = 0 then break;
    byte len of dst := c;
    len +:= 1 }
  while len<size do
  { byte len of dst := 0;
    len +:= 1 } }

let nzstr_to_zstr(src, dst, size) be
           // copy a string
              // from src, (size) bytes long, may not be zero terminated
              // to dst, as a normal zero terminated string
{ let len = 0;
  while len<size do
  { let c = byte len of src;
    if c = 0 then break;
    byte len of dst := c;
    len +:= 1 }
  byte len of dst := 0 }

let write_superblock(fs) be
           // convert the in-memory information about the whole file system
           // into the on-disc superblock format, and write it
{ let b = vec 128, r;
  for i = 0 to 127 do
    b ! i := 0;
  zstr_to_nzstr(fs ! fs_discname, b + sb_discname, sb_discnamesize);
  b ! sb_rootstart := fs ! fs_rootstart;
  b ! sb_rootsize := fs ! fs_rootsize;
  b ! sb_firstfree := fs ! fs_firstfree;
  fs ! fs_sbupdated := seconds();
  b ! sb_updated := fs ! fs_sbupdated;
  r := devctl(dc_disc_write, fs ! fs_discnum, 0, 1, b);
  if r<0 then out("write_superblock dc_disc_write error %d\n", r);
  resultis r }

let read_superblock(fs) be
         // read the supoerblock from disc, and convert the useful information
         // into the right format for the in-memory fs object
{ let b = vec 128, r;
  r := devctl(dc_disc_read, fs ! fs_discnum, 0, 1, b);
  if r<0 then
  { out("read_superblock dc_disc_read error %d\n", r);
    resultis r }
  fs ! fs_discname := newvec(sb_discnamesize/4+1);
  nzstr_to_zstr(b + sb_discname, fs ! fs_discname, sb_discnamesize);
  fs ! fs_rootstart := b ! sb_rootstart;
  fs ! fs_rootsize := b ! sb_rootsize;
  fs ! fs_firstfree := b ! sb_firstfree;
  fs ! fs_sbupdated := b ! sb_updated;
  resultis r }

let write_rootdir(fs) be
        // write the in-memory copy of the root directory back to disc
{ let r = devctl(dc_disc_write, fs ! fs_discnum, fs ! fs_rootstart, fs ! fs_rootsize, fs ! fs_rootdir);
  if r<0 then out("write_rootdir dc_disc_write error %d\n", r);
  resultis r }

let read_rootdir(fs) be
        // read the root-directory into an in-memory copy.
        // this should only be done once, as it uses newvec to allocate the space
{ let rd = newvec(fs ! fs_rootsize * 128),
      r = devctl(dc_disc_read, fs ! fs_discnum, fs ! fs_rootstart, fs ! fs_rootsize, rd);
  if r<0 then 
  { out("read_rootdir dc_disc_read error %d\n", r);
    freevec(rd) }
  fs ! fs_rootdir := rd;
  resultis r }

let format(fs) be
        // prepare a new disc for its first use, or reformat an old disc
        //    to make it clean and empty again.
        // the user of this function is responsible for providing an empty
        //    fs object to hold the information generated.
{ let d, r, tempstr = vec sb_discnamesize/4+1;
  while true do
  { outs("which disc unit? ");
    d := inno();
    r := devctl(dc_disc_check, d);
    if r>0 then break;
    out("error %d\n", r) }
  out("disc unit %d, %d blocks\n", d, r);
  fs ! fs_discnum := d;
  fs ! fs_nblocks := r;
  out("disc label (max 32 chars)? ");
  fs ! fs_discname := strdup(ins(tempstr, sb_discnamesize/4+1));
  outs("size (in blocks) of root directory? ");
  r := inno();
  fs ! fs_rootstart := 1;
  fs ! fs_rootsize := r;
  fs ! fs_firstfree := 1+r;
  d := newvec(r * 128);
  for i = 0 to r*128-1 do
    d ! i := 0;
  fs ! fs_rootdir := d;
  d := write_superblock(fs);
  unless d<0 do d := write_rootdir(fs);
  if d<0 then
  { freevec(fs ! fs_discname);
    freevec(fs ! fs_rootdir);
    fs ! fs_discnum := 0 } }

let load(fs) be
        // get an already formatted disc ready for use.
        // the user of this function is responsible for providing an empty
        //    fs object to hold the information generated.
{ let d, r, sb = vec 128;
  while true do
  { outs("which disc unit? ");
    d := inno();
    r := devctl(dc_disc_check, d);
    if r>2 then break;
    out("error %d\n", r) }
  fs ! fs_discnum := d;
  fs ! fs_nblocks := r;
  out("disc unit %d, %d blocks\n", d, r);
  r := read_superblock(fs);
  if r<0 then
  { fs ! fs_discnum := 0;
    return }
  out("disc label '%s'\n", fs!fs_discname);
  out("root directory blocks %d to %d\n", fs ! fs_rootstart, fs ! fs_rootstart + fs ! fs_rootsize - 1);
  out("first free block: %d\n", fs ! fs_firstfree);
  r := read_rootdir(fs);
  if r<0 then
  { freevec(fs ! fs_discname);
    fs ! fs_discnum := 0 } }

let listroot(fs) be
{ let entry = fs ! fs_rootdir,
      nentries = fs ! fs_rootsize * 128 / sizeof_rde,
      fname = vec rde_namesize/4+2,
      count = 0;
  for i = 0 to nentries-1 do
  { if rde_status of entry <> rdes_free then
    { nzstr_to_zstr(entry + rde_name, fname, rde_namesize);
      out("%2d %32s %5d %d\n", i, fname, entry ! rde_firstblock, entry ! rde_length);
      count +:= 1 }
    entry +:= sizeof_rde }
  out("%d files\n", count) }

let last_error = nil,
    err_dscfull = "not enough disc space",
    err_dirfull = "directory is full",
    err_notfound = "file not found",
    err_wrongmode = "incorrect mode";

let makefile(fs, fname, length, info)
        // creates an empty file on the filesystem described by fs.
        // length is in bytes
        // returns negative for error, entry number if OK
        // the user of this function is responsible for providing an empty
        //    fi (file information) object to hold the directory entry information.
be
{ let entry = fs ! fs_rootdir,
      nentries = fs ! fs_rootsize * 128 / sizeof_rde;
  for i = 0 to nentries-1 do
  { if rde_status of entry = 0 then
    { let nblocks = (length + 511) / 512;
      if fs ! fs_firstfree + nblocks > fs ! fs_nblocks then
      { last_error := err_dscfull;
        resultis nil }
      zstr_to_nzstr(fname, entry + rde_name, rde_namesize);
      entry ! rde_firstblock := fs ! fs_firstfree;
      fs ! fs_firstfree +:= nblocks;
      entry ! rde_length := length;
      rde_status of entry := rdes_exists;
      info ! fi_status := rdes_exists;
      info ! fi_number := i;
      info ! fi_firstblock := entry ! rde_firstblock;
      info ! fi_length := length;
      resultis info; }
    entry +:= sizeof_rde }
  last_error := err_dirfull;
  info ! fi_status := rdes_free;
  resultis nil }

let makefile_command(fs) be
{ let fname = vec rde_namesize/4+2,
      fi = vec sizeof_fi,
      length;
  outs("file name? ");
  ins(fname, rde_namesize);
  outs("length (in bytes)? ");
  length := inno();
  fi := makefile(fs, fname, length, fi);
  test fi = nil then
    out("FAILED: %s\n", last_error)
  else
    out("   entry %d firstblock=%d length=%d\n",
        fi ! fi_number, fi ! fi_firstblock, fi ! fi_length) }

let findfile(fs, name, info) be
        // find a file that already exists
        // the user of this function is responsible for providing an empty
        //    fi (file information) object to hold the directory entry information.
{ let entry = fs ! fs_rootdir,
      nentries = fs ! fs_rootsize * 128 / sizeof_rde,
      thisname = vec rde_namesize/4+2;
  for i = 0 to nentries-1 do
  { if rde_status of entry <> rdes_free then
    { nzstr_to_zstr(entry + rde_name, thisname, rde_namesize);
      if name %streq thisname then
      { info ! fi_status := rde_status of entry;
        info ! fi_number := i;
        info ! fi_firstblock := entry ! rde_firstblock;
        info ! fi_length := entry ! rde_length;
        resultis info } }
    entry +:= sizeof_rde }
  last_error := err_notfound;
  info ! fi_status := rdes_free;
  resultis nil }

let findfile_command(fs) be
{ let wantname = vec rde_namesize/4+2,
      fi = vec sizeof_fi;
  outs("file name? ");
  ins(wantname, rde_namesize);
  fi := findfile(fs, wantname);
  test fi = nil then
    out("FAILED: %s\n", last_error)
  else
    out("   entry %d firstblock=%d length=%d\n",
        fi ! fi_number, fi ! fi_firstblock, fi ! fi_length) }

let deletefile(fs, name) be
{ let fi = vec sizeof_fi,
      entry;
  fi := findfile(fs, name, fi);
  if fi = nil then
    resultis nil;
  entry := (fs ! fs_rootdir) + sizeof_rde * (fi ! fi_number);
  rde_status of entry := rdes_free;
  resultis 1 }

let deletefile_command(fs) be
{ let e, name = vec rde_namesize/4+2;
  outs("file name? ");
  ins(name, rde_namesize);
  e := deletefile(fs, name);
  if e = nil then
    out("FAILED: %s\n", last_error) }

let open(fs, name, mode) be
{ let info = vec sizeof_fi,
      f;
  if mode = 'r' then mode := 'R';
  if mode = 'w' then mode := 'W';
  if mode <> 'R' /\ mode <> 'W' then
  { last_error := err_wrongmode;
    resultis nil } 
  info := findfile(fs, name, info);
  if info = nil then resultis nil;
  f := newvec(sizeof_file);
  f ! file_mode := mode;
  f ! file_filesys := fs;
  f ! file_thisblockn := info ! fi_firstblock;
  f ! file_remaining := info ! fi_length;
  f ! file_position := mode = 'W' -> 0, 512;
  f ! file_buffer := f + file_buffer + 1;
  resultis f }

let file_flush(f) be
{ if f ! file_mode <> 'W' then return;
  if f ! file_position = 0 then return;
  devctl(dc_disc_write, f ! file_filesys ! fs_discnum, 
                        f ! file_thisblockn, 
                        1, 
                        f ! file_buffer) }

let close(f) be
{ file_flush(f);
  f ! file_mode := 0;
  freevec(f) }

let length(f) = f ! file_remaining

let read(f, ptr, num) be
{ let pos = f ! file_position,
      buf = f ! file_buffer;
  if f ! file_mode <> 'R' then
  { last_error := err_wrongmode;
    resultis -1 }
  if num > f ! file_remaining then
    num := f ! file_remaining;
  for i = 0 to num-1 do
  { if pos = 512 then
    { let bn = f ! file_thisblockn;
      devctl(dc_disc_read, f ! file_filesys ! fs_discnum, bn, 1, buf);
      f ! file_thisblockn := bn + 1;
      pos := 0 }
    byte i of ptr := byte pos of buf;
    pos +:= 1 }
  f ! file_position := pos;
  f ! file_remaining -:= num;
  resultis num }

let write(f, ptr, num) be
{ let pos = f ! file_position,
      buf = f ! file_buffer;
  if f ! file_mode <> 'W' then
  { last_error := err_wrongmode;
    resultis -1 }
  if num > f ! file_remaining then
    num := f ! file_remaining;
  for i = 0 to num-1 do
  { byte pos of buf := byte i of ptr;
    pos +:= 1;
    if pos = 512 then
    { let bn = f ! file_thisblockn;
      devctl(dc_disc_write, f ! file_filesys ! fs_discnum, bn, 1, buf);
      f ! file_thisblockn := bn + 1;
      pos := 0 } }
  f ! file_position := pos;
  f ! file_remaining -:= num;
  resultis num }

let alphafile_command(fs) be
{ let filename = vec rde_namesize/4+2,
      fout, len, al = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  outs("file name? ");
  ins(filename, rde_namesize);
  fout := open(fs, filename, 'W');
  if fout = nil then
  { out("FAILED: %s\n", last_error);
    return }
  len := length(fout);
  out("%d bytes to fill\n", len);
  while len >= 26 do
  { write(fout, al, 26);
    len -:= 26 }
  if len > 0 then
    write(fout, al, len);
  close(fout) }

let showfile_command(fs) be
{ let filename = vec rde_namesize/4+2,
      buffer = vec 26,
      fin, amt;
  outs("file name? ");
  ins(filename, rde_namesize);
  fin := open(fs, filename, 'R');
  if fin = nil then
  { out("FAILED: %s\n", last_error);
    return }
  while true do
  { let amt = read(fin, buffer, 100);
    if amt <= 0 then break;
    byte amt of buffer := 0;
    out("[%s]\n", buffer) }
  close(fin) }

let fillfile_command(fs) be
{ let filename = vec rde_namesize/4+2,
      tapename = vec 51,
      buffer = vec 128,
      fout, len, r;
  outs("file name? ");
  ins(filename, rde_namesize);
  fout := open(fs, filename, 'W');
  if fout = nil then
  { out("FAILED: %s\n", last_error);
    return }
  len := length(fout);
  outs("tape name? ");
  ins(tapename, 200);
  r := devctl(dc_tape_load, 1, tapename, 'R');
  if r < 0 then
  { out("FAILED finding tape, code = %d\n", r);
    return }
  while len >= 0 do
  { let got = devctl(dc_tape_read, 1, buffer),
        towrite = len;
    if got = 0 then
      break;
    if towrite > 512 then
      towrite := 512;
    if towrite > got then
      towrite := got;
    write(fout, buffer, towrite);
    len -:= towrite }
  devctl(dc_tape_unload, 1);
  close(fout) }
                          
let start() be
{ manifest { heapsize = 10240 }
  let heap = vec heapsize,
      cmd = vec 20,
      fs = vec sizeof_fs;
  init(heap, heapsize);
  fs ! fs_discnum := 0;

  while fs ! fs_discnum = 0 do
  { outs("< ");
    ins(cmd, 20);
    test cmd %streq "format" then
      format(fs)
    else test cmd %streq "load" then
      load(fs)
    else test cmd %streq "exit" then
      break
    else
      out("unrecognised command '%s'\nsay format, load, or exit\n", cmd) }

  while true do
  { outs("< ");
    ins(cmd, 20);
    test cmd %streq "dir" then
      listroot(fs)
    else test cmd %streq "make" then
      makefile_command(fs)
    else test cmd %streq "find" then
      findfile_command(fs)
    else test cmd %streq "delete" then
      deletefile_command(fs)
    else test cmd %streq "alpha" then
      alphafile_command(fs)
    else test cmd %streq "show" then
      showfile_command(fs)
    else test cmd %streq "fill" then
      fillfile_command(fs)
    else test cmd %streq "exit" then
      break
    else
      out("unrecognised command '%s'\nsay dir, make, find, delete, alpha, show, fill, or exit\n", cmd) }
  write_rootdir(fs);
  write_superblock(fs) }
