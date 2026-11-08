# RTOS BASIC API tests

BASIC programs that exercise `USR(0)`–`USR(14)`. Each program prints one `pass` or `fail` line per check and a total at the end.

## Running

The built programs are in `release/` next to `rtos`: `test1` to `test9` and `knownbugs`. Each one starts with `load"rtos",8,1`, so `rtos` must be on device 8, the same way `demo` works.

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
| `test8` | Scheduler and co-op owners | A lone task waking from a sleep and a yield, and showing running (2) afterwards; a co-op mate not cutting in after a lone yield; a busy owner blocking its mate (7); a pre-empted owner showing 8; ending or moving the owner freeing the co-op |
| `test9` | Open-issue checks | The FORBID count leaking into another task across a wait; a reused slot inheriting the old task's timer, signals and priority; a queue signal with an empty queue; two waiting `USR(12)` calls keeping their own lengths; `USR(12),0` overwriting strings |
| `knownbugs` | Issues a test can't check safely | A menu: FORK with no free slot, `USR(200)`, a task ID past the arrays, a co-op over 15, idle screen blanking. Each choice says what fixed and open look like |

Most `knownbugs` choices hang or crash the machine while their issue is open. Reset after each.

### Expected failures with the Nov 8 code

These checks target open issues in the analysis doc, so they should fail until the issue is fixed:

| Program | Failing checks | Open issue |
| --- | --- | --- |
| `test8` | "re-picked after sleep/yield: running (2)", "mate co-opted (7) after lone yield", "mate waits until task 0 waits" | 1: a re-picked task stays READY without its co-op |
| `test9` | "usr(2) count doesn't leak to others" | 5: FORBID carries across a wait |
| `test9` | "new task doesn't get old priority", "no stale timer or signal wakes it" | 4: stale settings in a reused slot |
| `test9` | "woken on empty queue, waits again", "then gets hi", "first waiter gets all 10 bytes", "second waiter gets its xy", "usr(12),0 leaves strings alone" | 2: `USR(12)` overruns and shares `DEQUEUE_L` |

Run `test9` last in a session: while `USR(12),0` still overruns, its final check can corrupt strings.

## How the tests work

- **Shared mailbox.** Tasks report results by poking `$CF00–$CF3F` (`mb`), which is above the RTOS and is not swapped per task. The harness fills it with 255 at the start, so 255 means "not reported yet".
- **Keeper task.** Most tests start a busy task (`gosub 9100`) so a sleeping task always has another task to switch to. Parts of tests 8 and 9 run without it on purpose: test 8 checks a task running alone, and in test 9 a busy task would hog the CPU while FORBID leaks.
- **Predictable children.** `gosub 9600` finds the slot the next `USR(1)` will use, so the parent knows the child's ID, and gives that slot its own co-op and priority 0. Children are therefore pre-emptive and don't start with stale settings from an earlier task (open issue 4). `gosub 9650` finds the slot without changing it; test 9 uses it to check what a reused slot inherits.
- **Timeouts.** Waits on a mailbox byte (`gosub 9400`) or a task state (`gosub 9500`) give up after about 5 seconds, so a broken call shows up as a `fail` and not a hang.
- **Harness copies.** Lines 8999 onwards are the same in every program. `harness.bas` is the master copy; paste changes into each test.

Keep `USR` calls in their own assignment (`s=usr(14),c:ok=s=2`). Comparing directly (`ok=usr(14),c=2`) makes BASIC read `c=2` as the parameter.
