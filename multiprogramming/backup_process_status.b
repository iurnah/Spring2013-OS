menifest
{ num_of_process = 2 }

menifest	//process task queue
{ pid = 0,
  proc_pdbr = 1,
  proc_sp = 2,
  proc_fp = 3,
  proc_pc = 4
  proc_flags = 5
  size_of_queue = 6 }

task_queue = newvec(size_of_queue * num_of_process)

let backup_process_status(pid) be
{ let curr_process = task_queue ! (pid * size_of_queue);
  let pflags, psp, pfp, ppdbr, ppc; //is necessary?
  assembly
  { LOAD	R1, SP
	STORE	R1, [<psp>]
	LOAD	R2, FP
	STORE	R2, [<pfp>]
	LOAD	R3, PC
	STORE	R3, [<ppc>]
    GETSR	R3, $FLAGS
    STORE	R3, [<flags>]
	GETSR	R4, $PDBR
	STORE	R4, [<ppdbr>]
	//Todo: what others?
  }

  curr_process ! proc_pdbr := ppdbr; 
  curr_process ! proc_sp := psp;
  curr_process ! proc_fp := pfp;
  curr_process ! proc_pc := ppc;
  curr_process ! proc_flags := pflags;

}

let resume_process_status(pid) be
{ let curr_process = taks_queue ! (pid * size_of_queue);
  let pflags = curr_process ! proc_flags,
      psp = curr_process ! proc_sp,
      pfp = curr_process ! proc_fp,
      ppdbr = curr_process ! proc_pdbr,
      ppc = curr_process ! proc_pc;

  assembly
  { LOAD	SP, [<psp>]
	load	fp, [<pfp>] 
    load	r1, [<ppdbr>]
	setsr	r1, $pdbr
	load	r2, [<pflags>]
	setsr	r2, $flags
	//Todo: here need handle the vm?
	load	pc, [<ppc>]
	flagsj	r1, pc
  }

}

// pc, fp, sp, FLAGS, PDBR, SYSSP, SP(SP==SYSSP, if in system mode)
