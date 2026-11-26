// This is a pseudo-c file to help better understand
// the assembly code flow in um-ts.asm.
//
// y is a signed index here; MAX_TASKS <= 16.
// coop_owner[c] is the task holding co-op c, or COOP_FREE (0xFF).
// ts_enable is the running task's FORBID level; forbid0[t] keeps
// each other task's level while it is switched out.

// Entry for voluntary switches (WAIT, SIGNAL, a queue read that
// frees room, END_TASK, USR(4)). Fakes the frame an IRQ would
// leave: the JSR return address is bumped by one (RTI doesn't add
// 1 like RTS does), then P, then A three times standing in for A,
// X and Y. So A survives a voluntary switch, but X and Y come back
// equal to A.
void UM_TS_PROC(void) {
	stack_return_address += 1;
	PHP; PHA; PHA; PHA;
	goto UM_TS;
}

// Can task y run as far as its co-op is concerned?
bool COOP_OK(y) {
	x = coop[y];
	return coop_owner[x] == COOP_FREE || coop_owner[x] == y;
}

// Task y gives up its co-op, if it holds it.
void COOP_RELEASE(y) {
	x = coop[y];
	if (coop_owner[x] == y)
		coop_owner[x] = COOP_FREE;
}

// Entered with an interrupt frame on the stack: from INT on an IRQ
// while ts_enable is 0 (pre-emption), or from UM_TS_PROC.
void UM_TS(void) {
	FORBID();				// ts_enable++

	for (;;) {	// UM_TS._loop
		ntid = NO_TASK;
		mxpri = 0;

		// 1. Wake WAITing tasks whose signals have arrived.
		// Whether their co-op lets them run is decided below.
		for (y = MAX_TASKS-1; y >= 0; y--) {
			if (task_state[y] == TS_WAIT && (wait[y] & signal[y]) != 0)
				task_state[y] = TS_READY;
		}

		// 2. Pick the next task.
		// If the current task is still RUN and its co-op lets it,
		// it is the candidate to beat, and the scan starts below
		// it. Otherwise (it waited, yielded or ended) the scan
		// starts with tid itself, which counts only if it is
		// READY again: a lone task waking from a sleep or a
		// yield is picked here.
		y = tid;
		if (task_state[y] == TS_RUN && COOP_OK(y)) {
			ntid = y;
			mxpri = pri[y];
			goto next;
		}

		// Scan down from y, wrapping from 0 to MAX_TASKS-1, and
		// stop on getting back to tid, so tid+1 is looked at
		// last. ">=" means that on a tie the task scanned last
		// wins: equal priorities in different co-ops take turns
		// in ascending order (round robin).
		for (;;) {
			if (task_state[y] == TS_READY
			 && pri[y] >= mxpri
			 && COOP_OK(y)) {
				ntid = y;
				mxpri = pri[y];
			}
		next:	y--;			// UM_TS._next
			if (y < 0)
				y = MAX_TASKS-1;
			if (y == tid)
				break;
		}

		if (ntid != NO_TASK)
			break;			// UM_TS._found

		// 3. No task can run: cycle the border colour on every
		// pass, so idle time shows as stripes (task colours are
		// solid), and look again. IRQs are on, so INT keeps
		// counting sleeps and checking WAITMs meanwhile.
		$D020++;
	}

	// 4. A pre-empted task goes back to READY but keeps its co-op.
	// The chosen task becomes RUN and takes its co-op.
	if (task_state[tid] == TS_RUN)
		task_state[tid] = TS_READY;
	task_state[ntid] = TS_RUN;
	coop_owner[coop[ntid]] = ntid;

	if (ntid != tid) {
		// Swap tasks. Each task keeps its own FORBID level
		// (plus the 1 UM_TS added on entry).
		sp0[tid] = S;
		forbid0[tid] = ts_enable;
		SEI;				// IRQs stay off until the CLI below
		XFER_BASIC(XFER_SAVE, tid);	// $0002-$03FF, variables, strings -> REU bank tid
		tid = ntid;
		XFER_BASIC(XFER_LOAD, tid);	// REU bank tid -> C64
		S = sp0[tid];			// now on the new task's stack
		ts_enable = forbid0[tid];
	}

	// TS_SWAP_END
	$D020 = tid;				// border = running task's colour
	PERMIT();				// takes off UM_TS's 1
	CLI;

	// Return into whichever task is now current, through the
	// frame on its stack (an IRQ's, or one UM_TS_PROC made).
	PLA; TAY;
	PLA; TAX;
	PLA;
	RTI;
}
