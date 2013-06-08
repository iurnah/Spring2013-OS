// multi
import "io"

/* Doc: http://rabbit.eng.miami.edu/class/een521/hardware-2a.pdf
 *
 */


manifest
{
 // process queue
  first_page=0, //page directory
  status=1 //running, waiting, paused
  stack_user_addr=2,
  stack_sys_addr=3,
  size_of_process_struct=4
}

manifest
{ iv_none = 0, iv_memory = 1, iv_pagefault = 2, iv_unimpop = 3,
  iv_halt = 4, iv_divzero = 5, iv_unwrop = 6, iv_timer = 7,
  iv_privop = 8, iv_keybd = 9, iv_badcall = 10, iv_pagepriv = 11,
  iv_debug = 12, iv_intrfault = 13 }

let ivec = table 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

let next_free_page

let next_virtual_page // page from the kernel perspective that 

let get_next_virtual_page() be
{
let x := next_virtual_page;
next_virtual_page +=1;
resultis x;
}

// array containing pointers to processes structures
let process_list = vec 10*size_of_process_struct;
let next_process_entry =0;

let set_handler(int, fn) be
  if int >= 0 /\ int <= 13 then
    ivec ! int := fn

let int_enable() be
 assembly
 { LOAD R1, [<ivec>]
   SETSR R1, $INTVEC
   LOAD R1, 0
   SETFL R1, $IP }

let int_disable() be
  assembly
  { LOAD R1, 1
    SETFL R1, $IP }

let set_timer(t) be
  assembly
  { LOAD  R1, [<t>]pdir
    SETSR R1, $TIMER }

let kbhandler(intcode, address, info) be
{ let c = 0, v = vec 3;
  out("interrupt %d (%x, %d) ", intcode, address, info);
  assembly
  { load  r1, [<v>]
    load  r2, $terminc
    store r2, [r1+0]
    load  r2, 1
    store r2, [r1+1]
    load  r2, <c>
    store r2, [r1+2]
    peri  r2, r1 }
  out("character %x '%c'\n", c, c);
  ireturn }


let load_program_from_tape(tape, page) be
{ let tmp = vec 128;
  let x;
  let index=0;

  /* load tape */
  x := devctl(DC_TAPE_LOAD, 1, tape, 'R');
  x := devctl(DC_TAPE_CHECK, 1);
  if x <> 'R' then resultis nil;

  while true do
  { x := devctl(DC_TAPE_READ, 1, tmp);
    //out("Tape read %s\n", tmp);
    if x <= 0 then break;
    for j = 0 to x-1 do
    { byte index of page := byte j of tmp; 
      index +:= 1; }
   }
  x := devctl(DC_TAPE_UNLOAD, 1);

//  out("load_program_from_tape read %s\n", page);

  resultis 1
}


let create_process(filename) be
{
// *** function create process ***
// allocate a 3 pages for the new program
//    initialize the page directory memory page
//    load first program code in the code page
//    inilialize the stack
// add process informations to a system structure (info= page directory of the process)
let code_vm_addr;
let stack_vm_addr;
let pdir_vm_addr;
let pdir_ph_addr;
let code_ph_addr;
let stack_ph_addr;

pdir_vm_addr := get_next_virtual_page();
code_vm_addr := get_next_virtual_page();
stack_vm_addr := get_next_virtual_page();

pdir_ph_addr := vm_map(pdir_vm_addr, -1); //  page dir
code_ph_addr := vm_map(code_vm_addr, -1); //  code dir
stack_ph_addr := vm_map(stack_vm_addr, -1); //  stack dir

//let non_vm_map(pdir, vpage, ppage) be
non_vm_map(pdir_vm_addr, 0, code_ph_addr); // process code
non_vm_map(pdir_vm_addr, 1, stack_ph_addr); // process stack

// read executable code
load_program_from_tape(filename, code_vm_addr);

// initialize the stack
//stack_vm_addr!2046 := 0; 
stack_vm_addr!2047 := 0; 


manifest
{
 // process queue
  first_page=0, //page directory
  status=1 //running, waiting, paused
  stack_user_addr=2,
  stack_sys_addr=3,
  size_of_process_struct=4
}

manifest
{
  running=0,
  paused=1
}


// initialize process structure
process_list!next_process_entry!first_page := pdir_vm_addr;
process_list!next_process_entry!status := running;
process_list!next_process_entry!stack_user_addr := 1;
process_list!next_process_entry!stack_sys_addr := stack_vm_addr;

}

// Context switch must coded here
let backup_process_state() be
{

}

let restore_process_state() be
{

}

let timhandler() be
{ outch('*');
  // TODO: Call context switch
  set_timer(100000);
  ireturn }

let halt_handler(intcode, address, info) be
{ out("HALT at %x\n", address);
  assembly { halt } }


let non_vm_map(pdir, vpage, ppage) be
{ let ptn = vpage >> 11,
  pn = vpage bitand 0b11111111111;
  let pt = pdir ! ptn;
  out("non_vm_map(%x, %x, %x)\n", pdir, vpage, ppage);

  test ppage = -1 then // Allocate new page
  { ppage := next_free_page << 11;
    next_free_page +:= 1 }
  else
    ppage <<:= 11;

  test (pt bitand 1) = 0 then // is page taken?
  {
    pt := next_free_page << 11;
    for i = 0 to 2047 do
      pt ! i := 0;
    next_free_page +:= 1;
    out(" PD[%x] := %x\n", ptn, pt bitor 1);
    pdir ! ptn := pt bitor 1;
  }
  else
    pt neqv:= 1;
    
  pt ! pn := ppage bitor 1;
  out(" %x[%x] := %x\n", pt, pn, ppage bitor 1)} 



let vm_map(vpage, ppage) be
{ let pdir, ptn = vpage >> 11, pn = vpage bitand 0b11111111111, entry, ptpa;
  out("vm_map(%x (%x, %x), %x)\n", vpage, ptn, pn, ppage);
  if ppage = -1 thenpdir
  { ppage := next_free_page;
    next_free_page +:= 1 }
    assembly
    { getsr r1, $PDBR
      store r1, [<pdir>]
      add r1, [<ptn>]
      phload r2, r1
      store r2, [<entry>] }
    out(" PD[%x] is %x\n", ptn, entry);
    if (entry bitand 1) = 0 then
      {
        entry := (next_free_page >> 11) bitor 1;
        assembly
        { load r1, [<pdir>]
          add r1, [<ptn>]
          load r2, [<entry>]
          phstore r2, r1 }
        out(" PD[%x] = %x\n", ptn, entry)
      }
    ptpa := entry neqv 1;
    entry := (ppage << 11) bitor 1;
    assembly
    { load r1, [<ptpa>]
      add r1, [<pn>]
      load r2, [<entry>]
      phstore r2, r1 }
    out(" %x[%x] = %x\n", ptpa, pn, entry);
  resultis pn<<11;
}

let page_fault_handler(intcode, address, info, pc) be
{ let ptn = address >> 22, pn = (address >> 11) bitand 0b11111111111;
  vm_map(address >> 11, -1);
  pc -:= 1;
  ireturn } 

let twotimes(x) be
{ let sptr, prev;
  if x = 0 then resultis 0;
  prev := twotimes(x-1);
  resultis prev+2 }

let start() be
{ let pdir = 6 << 11; //page directory, vpage 6
  let a, b, addr, page,
  syssp = 0xBFFFFFFF, // system stack
  sp = 0x7FFFFFFF,    // user stack
  code_page_needed = (! 0x101) >> 11;
  next_free_page := 7;
  out("end of code is at %x, cpn %d\n", ! 0x101, code_page_needed);
  set_handler(iv_timer, timhandler);
  set_handler(iv_keybd, kbhandler);
  set_handler(iv_pagefault, page_fault_handler);
  set_handler(iv_halt, halt_handler);
  int_enable();
  set_timer(100000);
  for i = 0 to 2047 do
    pdir ! i := 0;
  for i = 0 to code_page_needed do
    non_vm_map(pdir, i, i);
  non_vm_map(pdir, sp >> 11, sp >> 11);
  non_vm_map(pdir, syssp >> 11, -1);


  /* Put code on page */
  non_vm_map(pdir, 4, 4);
  addr := 4<<11;
  page := !addr;
  load_program_from_tape("simple_executable.exe", !addr);
  assembly
  { load r1, [<addr>]
    break
    jump r1 }


//  load_program_from_tape("a.tape", addr);
//  out("read %s\n", addr);
//  non_vm_map(pdir, 5, 5);
//  load_program_from_tape("simple_executable2.exe", 5<<11);


// switch to virtual adressing
  assembly
  { load r2, sp
    load r3, fp
    load sp, [<syssp>]
    load r1, [<pdir>]
    setsr r1, $pdbr
    getsr r1, $flags
    sbit r1, $vm
    cbit r1, $sys
    flagsj r1, pc
    //flagsj r1, [<addr>]
    load sp, r2
    load fp, r3 }

next_virtual_page := 15;


// *** function create process ***
// allocate a 3 pages for the new program
//    initialize the page directory memory page
//    load first program code in the code page
//    inilialize the stack
// add process informations to a system structure (info= page directory of the process)

// call the function create process for the 2 tapes

// 



  a := 1000;


  b := twotimes(a);
  out("twotimes(%d) = %d\n", a, b) } 
_
