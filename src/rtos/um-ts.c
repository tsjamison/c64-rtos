// This is a pseudo-c file to help better understand
// the assembly code flow in um-ts.asm.
//
// y is a signed index here; MAX_TASKS <= 16.
// coop_owner[c] is the task holding co-op c, or 0xFF when free.

// Entry for voluntary switches (WAIT, SIGNAL, END_TASK, USR(4)).
// Fakes the frame an IRQ would leave: the JSR return address
// is bumped by one (RTI doesn't add 1 like RTS does), then P,
// then A three times standing in for A, X and Y. So Y and X do
// not survive a voluntary switch.
void UM_TS_PROC(void) {
	stack_return_address += 1;
	PHP; PHA; PHA; PHA;
	goto UM_TS;
}

// Can task y run as far as its co-op is concerned?
bool COOP_OK(y) {
	x = coop[y];
	return coop_owner[x] == 0xFF || coop_owner[x] == y;
}

// Task y gives up its co-op, if it holds it.
void COOP_RELEASE(y) {
	x = coop[y];
	if (coop_owner[x] == y)
		coop_owner[x] = 0xFF;
}

void UM_TS(void) {
	FORBID();

	do {	// UM_TS.LOOP
		ntid = 0xFF;
		mxpri = 0;

		// Wake WAITing tasks whose signals have arrived.
		// Whether their co-op lets them run is decided below.
		for (y = MAX_TASKS-1; y >= 0; y--) {
			if (task_state[y] == TS_WAIT && (wait[y] & signal[y]) != 0)
				task_state[y] = TS_READY;
		}

		// If the current task is running and its co-op still
		// lets it, it is the candidate to beat.
		y = tid;
		if (task_state[y] == TS_RUN && COOP_OK(y)) {
			ntid = y;
			mxpri = pri[y];
		}

		// Pick the highest-priority READY task its co-op allows.
		// Starts after tid and stops when it gets back to tid,
		// so tid itself is never a candidate here (open issue 1).
		do {
			y--;			// UM_TS.NEXT
			if (y < 0)
				y = MAX_TASKS-1;
			if (y == tid)
				break;
			if (task_state[y] == TS_READY
			 && pri[y] >= mxpri
			 && COOP_OK(y)) {
				ntid = y;
				mxpri = pri[y];
			}
		} while (1);

		if (ntid == tid)		// y == tid here
			break;			// keep running, goto TS_SWAP_END

		if (ntid == 0xFF) {
			// No task selected to run: blank the screen and
			// look again. FORBID is not called again.
			$D011 = $D011 & 0xEF;
			continue;
		}

		// New task is different from current task.
		// A pre-empted task goes back to READY but keeps its co-op.
		if (task_state[tid] == TS_RUN)
			task_state[tid] = TS_READY;
		task_state[ntid] = TS_RUN;
		coop_owner[coop[ntid]] = ntid;	// new task takes its co-op

		// DO TASK SWAP
		sp0[tid] = S;			// save stack pointer
		SEI;				// IRQs stay off until the CLI below
		XFER_BASIC(XFER_SAVE, tid);	// $0002-$03FF, variables, strings -> REU bank tid
		tid = ntid;
		$D020 = tid;
		XFER_BASIC(XFER_LOAD, tid);	// REU bank tid -> C64
		S = sp0[tid];			// switch to the new task's stack
		break;

	} while (1);

	// TS_SWAP_END
	$D011 = $D011 | 0x10;		// screen back on
	PERMIT();
	CLI;

	// Return into whichever task is now current, through the
	// frame on its stack (an IRQ's, or one UM_TS_PROC made).
	PLA; TAY;
	PLA; TAX;
	PLA;
	RTI;
}
