import "io"

manifest
{ total_block_sz = 6000,
  bytes_per_block = 512,
  words_per_block = 128,
  first_data_block = 10,
  fnamelen = 6,
  root_dir_bn = 4,
  sizeof_dirent = 8,
  dirent_name = 0,
  dirent_status = byte 23,
  dirent_fb = 6,
  dirent_sz = 7 }

static { n = 0, m = 0 }//n is the total directory entry, m is the total disc block occupied

//string input function
let ins(string, veclen) be
{ let max = (veclen-1)*4;
  let length = 0;
  while length < max do
  { let c = inch();
    if c = '\n' then break;
    byte length of string := c;
    length +:= 1 }
  byte length of string := 0;
  resultis string }

//string copy function
let strcpy(dst, src) be
{ let i = 0;
  while true do
  { let c = byte i of src;
    if c = 0 then 
    { byte i of dst := 0;
      break }
    byte i of dst := c;
    i +:= 1 } }

//set the directory entry function
let set_entry(buffer, n, name, st, b1, len) be
{ let eptr = buffer + n * sizeof_dirent;
  strcpy(eptr + dirent_name, name);
  dirent_status of eptr := st;
  eptr ! dirent_fb := b1;
  eptr ! dirent_sz := len }

// fills a 512 byte buffer with as many copies of the
// alphabet as will fit, but starts from the given letter
// instead of 'a', so we can make many recognisably
// different patterns. Then writes it to block b of the disc.
let fill_block(b, letter) be
{ let buffer = vec 128;
  let x;
  x := devctl(DC_DISC_WRITE, 1, b, 1, buffer);
  out("status of write to block %d: %d\n", b, x) }

//initialization
let diskinit() be
{ let b = vec words_per_block,x;  	// 128 words buffer
    for i = 0 to 127 do b ! i := 0; 	//initialize buffer
    for i = 0 to 99 do			//initialize 100 blocks for the disc
      x := devctl(DC_DISC_WRITE, 1, i, 1, b);//write to disk
    if x = 1 then 
       out("Disk 1 initialized!!! total available blocks = 100\n") }

//list root dir
let list() be
{ let b = vec words_per_block,x;  
  x := devctl(DC_DISC_READ, 1, root_dir_bn, 1, b);
  out("name           st     fd     len\n");
  for i = 0 to 15 do
  { let eptr = b + i * sizeof_dirent;
    let name = eptr;
    let st = dirent_status of eptr;
    let fb = eptr ! dirent_fb;
    let len = eptr ! dirent_sz;
    if st = 0 then loop;
    out("'%s'    %d      %d     %d\n", name, st, fb, len) } }

let tape_to_file(tapename, filename) be
{
  let b = vec words_per_block;
  let contents = vec words_per_block;
  let file_sz, x;
  let total_block;
  let blocks_count = 0;

  out("loading '%s' ...\n", tapename);
  x := devctl(DC_TAPE_LOAD, 1, tapename, 'R');
  out("load status = %d\n",x);
  x := devctl(DC_TAPE_CHECK, 1);
  if x <> 'R' then finish;

  while true do 
  {
   x := devctl(DC_TAPE_READ, 1, contents);
   file_sz +:= x;
   test x <= 0 then
      break
   else{
      blocks_count +:= 1;
      x := devctl(DC_DISC_WRITE, 1, first_data_block + m, 1, contents);
      m +:= 1 }}

  out("tape '%s' succesfully loaded into filesystem!\n", tapename);

  x := devctl(DC_DISC_READ, 1, root_dir_bn, 1, b);
  set_entry(b, n, filename, 1, first_data_block + m-blocks_count, file_sz);
  x := devctl(DC_DISC_WRITE, 1, root_dir_bn, 1, b);
  n +:= 1;

  out("file entry updated!! (file size = %d) \n", file_sz);
  file_sz := 0 } //set the file_sz value back to zero for next file creation


//create a new file
let newfile(newname, tapename) be
{ 
  let b = vec words_per_block, x;
  
//  might not need this entry, just for create entry.
  x := devctl(DC_DISC_READ, 1, root_dir_bn, 1, b);

  set_entry(b, n, newname, 1, first_data_block + m, 0); //
  x := devctl(DC_DISC_WRITE, 1, root_dir_bn, 1, b);
  out("file entry created!! (file size is unkown = 0) \n");
  tape_to_file(tapename, newname) }

//true if string1 = string2 otherwise false
let match(str1, str2) be
{ let i = 0;
  while true do
  { let ch1 = byte i of str1;
    let ch2 = byte i of str2;
    if ch1 <> ch2 then break;
    i +:= 1;
    if  ch1 = 0 /\  ch1 = ch2 then
      resultis true }
  resultis false }

//search filename for file descriptor
let get_fd(filename) be
{ let b = vec 128,x;
  let name = vec 6;
  x := devctl(DC_DISC_READ, 1, root_dir_bn, 1, b);
  if x <> 1 then 
  { out("getting fd failed!!!\n"); 
    finish }
  for i = 0 to 15 do
  { let eptr = b + i * sizeof_dirent;
    let name = eptr;
    let st = dirent_status of eptr;
    let fb = eptr ! dirent_fb;
    let len = eptr ! dirent_sz;
    if st = 0 then loop;
    if match(name, filename) then
      resultis fb } 
   resultis -1 }

//search filename for file len
let get_len(filename) be
{ let b = vec 128,x;
  let name = vec 6;
  x := devctl(DC_DISC_READ, 1, root_dir_bn, 1, b);
  if x <> 1 then 
  { out("getting file length failed!!!\n"); 
    finish }
  for i = 0 to 15 do
  { let eptr = b + i * sizeof_dirent;
    let name = eptr;
    let st = dirent_status of eptr;
    let fb = eptr ! dirent_fb;
    let len = eptr ! dirent_sz;
    if st = 0 then loop;
    if match(name, filename) then
      resultis len } 
   resultis -1 }

//read a file
let read(name) be
{ let b = vec words_per_block;
  let fd = 0;
  let fd_last = 0;
  let len = 0;
  let x;
  fd := get_fd(name);
  len := get_len(name);

  test len rem 512 = 0 then
    fd_last := fd
  else
    fd_last := len / 512 + fd + 1;

  test fd < 0 then
    out("%s does not exist!!!\n", name)
  else test len <= 512 then
  { x := devctl(DC_DISC_READ, 1, fd, 1, b);
    test x<>1 then
      out("read filename aborted!!!\n")
    else
      out("file %s content:\n %s\n", name, b) }
  else 
  { out("file %s content: \n", name);
    while fd_last > fd do
      { x := devctl(DC_DISC_READ, 1, fd, 1, b);
        fd +:= 1;
//        byte x-1 of b := 0;
        out(b) } }
    out("\n\n::rearead file finished!!!\n") }


//write a file
let write() be
{}

//delete a file 
let delete(filename) be 
{ let b = vec words_per_block,x;
  let flag = 0;
  x := devctl(DC_DISC_READ, 1, root_dir_bn, 1, b);
  for i = 0 to 15 do
  { let eptr = b + i * sizeof_dirent;
    let name = eptr;
    let st = dirent_status of eptr;
    let fb = eptr ! dirent_fb;
    let len = eptr ! dirent_sz;
    if st = 0 then loop;
    if match(name, filename) then
    { dirent_status of eptr := 0;
      flag := 1 } } 
  x := devctl(DC_DISC_WRITE, 1, root_dir_bn, 1, b);
  test flag then
    { out("%s deleted!\n", filename);
      flag := 0 }
  else
    out("%s doesn't exist on disk!!!\n", filename) }

//to dispaly the user interfaces
let displayui() be
{
 outs("\n\n   Hello, this is a very simple file system version 0.0\n");
 outs("Following is the operations it now support: \n");
 outs("\t'0'	Initialize the disc\n");
 outs("\t'1'	List the root directory files\n");
 outs("\t'2'	Creating a new file\n");
 outs("\t'3'	Read a file by file name\n");
 outs("\t'4'	Delete a file\n");
 outs("\t'5'	Exit the file system\n");
 outs("please select a operation: ");
}

let start() be 
{
 let newname = vec fnamelen;
 let tapename = vec fnamelen;
 let filename = vec fnamelen;
 let delname = vec fnamelen;
 displayui();

 while true do
  { let op = inno();
    switchon op into
    { case  0 :
	    diskinit();
	    endcase;

      case  1 :
	    list();
	    out("");
	    endcase;

      case  2 :
	    out("Please enter the new file name to create(no more than 23 chars!): \n");
	    ins(newname, fnamelen);
	    out("Please enter the tape name: \n");
	    ins(tapename, fnamelen);
	    newfile(newname, tapename);//param: filename
	    out("");
	    endcase;

      case  3 :
	    out("Please enter the file name to read(no more than 23 chars!): \n");
	    ins(filename, fnamelen);
	    read(filename);
	    out("");
	    endcase;

      case  4 :
            out("Please enter the file name to delete(no more than 23 chars): \n");
            ins(delname, fnamelen);
	    delete(delname);
	    out("");
	    endcase;

      case  5 :
            break;

    }
    outs("please select a operation: ");
  }
} 

