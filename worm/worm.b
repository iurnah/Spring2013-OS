import "io"

let gets(s) be
{ let i=0;
  while true do
  { let c = inch();
    if c='\n' then break;
    byte i of s := c;
    i+:=1 }
  byte i of s := 0 }
 
let f() be
{ let line = vec 10;
  gets(line);
  for i = 0 to 11 do
  { out("byte i = %d\t line = %08x\t !line = %08x\n", i, line ! i, line+i) } }
    
let start () be
{ let a, b;
  f();
  out("not overwrite the return address\n") }
