import "io"

let gets(s) be
{ let i=0;
  while true do
  { let c = inch();
    if c='\n' then break;
    byte i of s := c;
    i+:=1 }
  byte i of s := 0 }
 
let func() be
{ let string = vec 10;
  gets(string);
  for i = 0 to 11 do
  { out("byte i = %d\t string = %08x\t @string = %08x\n", i, string ! i, string+i) } }
  
let start () be
{ func();
  out("Doesn't work\n") }

