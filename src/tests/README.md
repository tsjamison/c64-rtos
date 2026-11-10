# RTOS BASIC API tests

BASIC programs that exercise `USR(0)`–`USR(14)`. Each program prints one `pass` or `fail` line per check and a total at the end.

## Running

The built programs are in `release/` next to `rtos`: `test1` to `test9` and `knownbugs`. Each one starts with `load"rtos",8,1`, so `rtos` must be on device 8, the same way `demo` works.

```
load"test1",8
run
```

You need an REU. Test 5's second part needs at least 10 tasks (a 512KB REU), and skips itself on smaller REUs.

## Running headless

`tools/c64run.py` runs a program from `release/` in VICE without a screen: PAL `x64sc`, 1MB REU, warp mode, with `release/` as drive 8. It types `load"<name>",8` and `run`, reads the C64 screen through VICE's remote monitor about once a second, and prints it as text when `passed,` appears. Each test takes about 10 seconds.

```
bash tools/setup-vice.sh                 # once per session: unpacks 64tass and VICE into ~/opt
python3 tools/c64run.py test1            # one test
python3 tools/c64run.py --all            # test1..test9 and a summary
python3 tools/c64run.py knownbugs --keys '3\n' --until error
python3 tools/c64run.py knownbugs --keys '1\n' --until error --regs
```

`--regs` prints the CPU registers at the end, and `--mon CMD` runs any VICE monitor command (for example `--mon "m d011 d011"`). `--drive DIR` uses another folder as drive 8. The setup script needs `archive.ubuntu.com` allowed and the C64 ROMs in `tools/roms` (not in git).

To rebuild a PRG without VS64:

```
python3 src/tests/bas2prg.py src/tests/test1.bas release/test1
```

`bas2prg.py --check file.bas` only reports problems: lines out of order, lines over 80 screen characters and unbalanced quotes.

## The tests

| Program | Covers | Checks |
| --- | --- | --- |
| `test1` | `USR(0)`, `(2)`, `(3)`, `(5)`, `(6)`, `(8)`, `(11)`, `(12)`, `(13)`, `(14)` with a single task | Task ID, max tasks, task state, FORBID/PERMIT nesting, old priority and co-op returned, signal set returned, queue byte counts, a full 255-byte queue, byte order |
| `test2` | `USR(1)`, `USR(4)`, `USR(14)` | Parent and child return values, child's copy of the parent's variables, a task ending itself, ending another task, a freed slot reused, a child starting with its parent's priority and co-op |
| `test3` | `USR(9)` | 1s and 5s sleeps timed with the CIA TOD clock, timer signal returned, other tasks running during a sleep, `USR(9),0` yielding, two sleepers waking in order |
| `test4` | `USR(7)`, `USR(8)` | Wait state, signals outside the mask not waking, the waking signal returned, a pending signal ending a wait at once, unmatched signals kept, yield, application signal 8 |
| `test5` | `USR(10)` | Any bit set, AND mask, EOR mask. Part 2 runs WAITM in task 2 and task 9 at once (the old `POKER0` overflow) |
| `test6` | `USR(11)`, `USR(12)` between tasks | Consumer waiting on an empty queue, partial reads, two producers whose writes must arrive whole |
| `test7` | `USR(2)`, `USR(3)`, `USR(5)`, `USR(6)` | A higher priority starving lower ones, equal priority in separate co-ops sharing time, one co-op running one task, the co-opted state, FORBID stopping pre-emption, other tasks pre-empting each other while a forbidden task sleeps |
| `test8` | Scheduler and co-op owners | A lone task waking from a sleep and a yield, and showing running (2) afterwards; a co-op mate not cutting in after a lone yield; a busy owner blocking its mate (7); a pre-empted owner showing 8; ending or moving the owner freeing the co-op |
| `test9` | Open-issue checks | The FORBID count leaking into another task across a wait, or outliving a task that ends while forbidden; a reused slot inheriting the old task's timer, signals and priority; a queue signal with an empty queue; two waiting `USR(12)` calls keeping their own lengths; `USR(12),0` overwriting strings |
| `knownbugs` | Issues a test can't check safely | A menu: FORK with no free slot, `USR(200)`, a task ID past the arrays, a co-op over 15, the idle border stripes. Each choice says what fixed and open look like |

Most `knownbugs` choices hang or crash the machine while their issue is open. Reset after each.

### Results with the Nov 9 code

Run headless in VICE on Nov 9 after the issue 4 and 5 fixes (see "Running headless" below): 88 of 92 checks pass. `test1`–`test8` pass in full. `test9` fails the 4 queue checks, which target open issue 2 (queues are being redesigned): "woken on empty queue, waits again", "then gets hi", "first waiter gets all 10 bytes" and "second waiter gets its xy".

`knownbugs` on the same day:

| Choice | Result |
| --- | --- |
| 1 FORK with no free slot | `?OUT OF MEMORY`, then READY with interrupts on (I flag clear): no freeze |
| 2 `USR(200)` | `?ILLEGAL QUANTITY ERROR`: fixed (issue 7) |
| 3 `USR(8),200,1` | "no error: still open" |
| 4 `USR(6),0,16` | `?ILLEGAL QUANTITY ERROR`: fixed |
| 5 Idle border stripes | Border stripes while task 0 sleeps alone, screen stays on (`$D011` = `$1B`): fixed, the RTOS no longer blanks the screen |

Run `test9` last in a session: while `USR(12),0` still overruns, its final check can corrupt strings.

## How the tests work

- **Shared mailbox.** Tasks report results by poking `$CF00–$CF3F` (`mb`), which is above the RTOS and is not swapped per task. The harness fills it with 255 at the start, so 255 means "not reported yet".
- **Keeper task.** Most tests start a busy task (`gosub 9100`) so a sleeping task always has another task to switch to. Parts of tests 8 and 9 run without it on purpose: test 8 checks a task running alone, and in test 9 a busy task would hog the CPU while FORBID leaks.
- **Predictable children.** A forked child starts with its parent's priority and co-op. `gosub 9600` finds the slot the next `USR(1)` will use, so the parent knows the child's ID (`nx`), and sets `cn`, the co-op to give it (its own by default). Right after the fork, `gosub 9640` moves the child to co-op `cn` at priority 0, so children are pre-emptive. The child can't run before that, because it starts in the parent's co-op. A test that wants a child in another co-op sets `cn` between the two calls. `gosub 9650` finds the slot without any of this; test 9 uses it to check what a reused slot starts with.
- **Timeouts.** Waits on a mailbox byte (`gosub 9400`) or a task state (`gosub 9500`) give up after about 5 seconds, so a broken call shows up as a `fail` and not a hang.
- **Harness copies.** Lines 8999 onwards are the same in every program. `harness.bas` is the master copy; paste changes into each test.

Keep `USR` calls in their own assignment (`s=usr(14),c:ok=s=2`). Comparing directly (`ok=usr(14),c=2`) makes BASIC read `c=2` as the parameter.
