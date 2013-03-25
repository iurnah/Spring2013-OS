import "io"

manifest
{ total_block_sz = 6000,
  bytes_per_block = 512,
  words_per_block = 128,
  first_data_block = 10,
  root_dir_bn = 4,
  sizeof_dirent = 8,
  dirent_name = 0,
  dirent_status = byte 23,
  dirent_fb = 6,
  dirent_sz = 7 }

static { n = 0 }

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
{ let b = vec words_per_block,x;  
    for i = 0 to 127 do b ! i := 0;
    for i = 0 to 99 do 
      x := devctl(DC_DISC_WRITE, 1, i, 1, b);
    if x = 1 then 
       out("Disk 1 initialized!!! total available blocks = 100\n") }

//list root dir
let list() be
{ let b = vec words_per_block,x;  
  x := devctl(DC_DISC_READ, 1, root_dir_bn, 1, b);
  out("name           st     fd     len\n");
  for i = 0 to 16 do
  { let eptr = b + i * sizeof_dirent;
    let name = eptr;
    let st = dirent_status of eptr;
    let fb = eptr ! dirent_fb;
    let len = eptr ! dirent_sz;
    if st = 0 then loop;
    out("'%s'    %d      %d     %d\n", name, st, fb, len) } }

//create a new file
let newfile() be
{ //static { n = 0 }
  let tapename = vec 6;
  let contents = vec 128;
  let name = vec 6,x;
  let b = vec words_per_block;
  let file_sz;
  outs("type new filename:\n");
  ins(name, 6);
  x := devctl(DC_DISC_READ, 1, root_dir_bn, 1, b);
  if x <> 1 then 
  { out("read entry info failed!!!\n"); 
    finish }  
  set_entry(b, n, name, 1, first_data_block + n, 0); //
  x := devctl(DC_DISC_WRITE, 1, root_dir_bn, 1, b);
  if x = 1 then
    out("New file created!!! Enter the tape name (disk file): \n");
  ins(tapename, 128);
  out("loading '%s' ...\n", tapename);
  x := devctl(DC_TAPE_LOAD, 1, tapename, 'R');
  out("load status = %d\n",x);
  x := devctl(DC_TAPE_CHECK, 1);
  if x <> 'R' then finish;
  x := devctl(DC_TAPE_READ, 1, contents);
  byte x of contents := 0;
  file_sz := x;
  x := devctl(DC_DISC_WRITE, 1, first_data_block + n, 1, contents);
  x := devctl(DC_DISC_READ, 1, root_dir_bn, 1, b);
  set_entry(b, n, name, 1, first_data_block + n, file_sz);
  x := devctl(DC_DISC_WRITE, 1, root_dir_bn, 1, b);
  out("tape '%s' succesfully loaded into filesystem!\n", tapename);
  n +:=1 }  

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

//read a file
let read() be
{ let name = vec 6,x;
  let b = vec words_per_block;
  let fd = 0;
  outs("file name to read:\n");
  ins(name, 6);
  fd := get_fd(name);
  test fd < 0 then
    out("%s does not exist!!!\n", name)
  else
  { x := devctl(DC_DISC_READ, 1, fd, 1, b);
    test x<>1 then
      out("read filename aborted!!!\n")
    else
      out("%s content:\n %s\n", name, b) } }

//write a file
let write() be
{}

//delete a file 
let delete() be 
{ let b = vec words_per_block,x;
  let filename = vec 6;
  let flag = 0;
  outs("file name to delete:\n");
  ins(filename, 6);
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

let start() be 
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
	    newfile();
	    out("");
	    endcase;

      case  3 :
	    read();
	    out("");
	    endcase;

      case  4 :
	    delete();
	    out("");
	    endcase;

      case  5 :
            break;

    }
    outs("please select a operation: ");
  }
} 

