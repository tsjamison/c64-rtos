# RTOS BASIC API tests

BASIC programs that exercise `USR(0)`–`USR(14)`. Each program prints one `pass` or `fail` line per check and a total at the end.

## Running

The built programs are in `release/` next to `rtos`: `test1` to `test7` and `knownbugs`. Each one starts with `load"rtos",8,1`, so `rtos` must be on device 8, the same way `demo` works.

```
load"test1",8
run
```

You need an REU. Test 5's second part needs at least 10 tasks (a 512KB REU), and skips itself on smaller REUs.

To rebuild a PRG without VS64:

```
python3 src/tests/bas2prg.py src/tests/test1.bas release/test1
```

`bas2prg.py --check file.bas` only reports problems: lines out of order, lines over 80 screen characters and unbalanced quotes.

## The tests

| Program | Covers | Checks |
| --- | --- | --- |
| `test1` | `USR(0)`, `(2)`, `(3)`, `(5)`, `(6)`, `(8)`, `(11)`, `(12)`, `(13)`, `(14)` with a single task | Task ID, max tasks, task state, FORBID/PERMIT nesting, old priority and co-op returned, signal set returned, queue byte counts, a full 255-byte queue, byte order |
| `test2` | `USR(1)`, `USR(4)`, `USR(14)` | Parent and child return values, child's copy of the parent's variables, a task ending itself, ending another task, a freed slot reused |
| `test3` | `USR(9)` | 1s and 5s sleeps timed with the CIA TOD clock, timer signal returned, other tasks running during a sleep, `USR(9),0` yielding, two sleepers waking in order |
| `test4` | `USR(7)`, `USR(8)` | Wait state, signals outside the mask not waking, the waking signal returned, a pending signal ending a wait at once, unmatched signals kept, yield, application signal 8 |
| `test5` | `USR(10)` | Any bit set, AND mask, EOR mask. Part 2 runs WAITM in task 2 and task 9 at once (the old `POKER0` overflow) |
| `test6` | `USR(11)`, `USR(12)` between tasks | Consumer waiting on an empty queue, partial reads, two producers whose writes must arrive whole |
| `test7` | `USR(2)`, `USR(3)`, `USR(5)`, `USR(6)` | A higher priority starving lower ones, equal priority in separate co-ops sharing time, one co-op running one task, the co-opted state, FORBID stopping pre-emption |
| `knownbugs` | Open issues 1–4 from the analysis doc | A menu; each choice reproduces one issue and prints `done` or `intact` once it's fixed |

`knownbugs` choices 1, 3 and 4 hang the machine while their issue is open. Reset after each.

## How the tests work

- **Shared mailbox.** Tasks report results by poking `$CF00–$CF3F` (`mb`), which is above the RTOS and is not swapped per task. The harness fills it with 255 at the start, so 255 means "not reported yet".
- **Keeper task.** Tests 2–7 start a busy task (`gosub 9100`) so a sleeping task always has another task to switch to. Without it, open issue 1 would hang any test that sleeps.
- **Predictable children.** `gosub 9600` finds the slot the next `USR(1)` will use, so the parent knows the child's ID, and gives that slot its own co-op and priority 0. Children are therefore pre-emptive and don't start with stale settings from an earlier task (open issues 3 and 5).
- **Timeouts.** Waits on a mailbox byte (`gosub 9400`) or a task state (`gosub 9500`) give up after about 5 seconds, so a broken call shows up as a `fail` and not a hang.
- **Harness copies.** Lines 8999 onwards are the same in every program. `harness.bas` is the master copy; paste changes into each test.

Keep `USR` calls in their own assignment (`s=usr(14),c:ok=s=2`). Comparing directly (`ok=usr(14),c=2`) makes BASIC read `c=2` as the parameter.
