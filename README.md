# MadnessCrashFixes

Cheat Engine table and launcher for **Alice: Madness Returns** (Steam) that fixes several crash bugs. These bugs do seem to exist in vanilla, but were also noticed only when using [MadnessPatch](https://github.com/Wemino/MadnessPatch), possibly due to additional memory pressure of the mod installation, or in the case of Zombie Object it was due to the patch's DisableBackgroundLevelStreaming.
The only pure-vanilla crash I noticed was on clicking "Continue Game", which seems fixed by MadnessPatch, and was not studied further.

## What it fixes

14 patch sites across 10 distinct crash bugs, plus 1 zombie-object kill hook.

| # | Crash | Sites | Root cause | Fix |
|---|-------|:-----:|-----------|-----|
| 1 | Hair curve over-read | 3 | Curve evaluator inner loop runs N+2 iterations, reading 0xB0 bytes past the knot array; crashes when trailing page is decommitted | Single-byte comparison bound fix + upper-level call hook + lower-level code cave that skips the over-read path |
| 2 | Linked-list iterator (op++ / op+=) | 3 | `operator++` and `operator+=` dereference sentinel value `1` as a node pointer | Guard checks in both operators + defense-in-depth call-site guard |
| 3 | Linked-list walk sentinel | 1 | Same sentinel-`1` root cause as #2, but in a different list-walk loop using `[node+0x28]` as next-pointer | Sentinel check; simulate end-of-list so loop exits cleanly |
| 4 | MMX over-read | 1 | `movq mm1,[ecx]` reads 8 bytes via MMX; crashes when buffer ends near page boundary and next page is uncommitted | SEH-guarded read; substitute zero on fault |
| 5 | Vtable corrupt object | 1 | Virtual call on freed/reused object: vtable pointer is garbage, second deref AVs | Validate vtable pointer is in EXE `.rdata` range; skip call if out of range |
| 6 | Header-prefix deref | 1 | `[eax-4]` treated as vtable; crashes when `eax` is page-aligned and previous page is uncommitted | SEH-guarded read; skip virtual call on fault |
| 7 | Corrupted-object low-addr deref | 1 | Inner pointer is garbage (e.g. 0x5DC0); `movzx [edx+ebx*2]` AVs in reserved page region | Low-address sentinel check; substitute zero |
| 8 | Vtable slot garbage | 1 | `[edx+0x278]` loads a method pointer from a corrupt vtable slot; `call eax` jumps into junk | Validate loaded function pointer is in EXE range; skip call + balance stack if bad |
| 9 | Null-this during teardown | 1 | Function receives `this=NULL` during `LoadMap` teardown; three downstream sites AV | Null-check at function entry; skip body via epilogue |
| 10 | Zombie BreakableObject | 1 | Level streaming adds a `GameBreakableActor` collision component to the physics tick list before `InitComponentRBPhys` runs; object is `RF_PendingKill \| RF_AsyncLoading` and never initializes | Hook the not-initialized branch; set `bDeleteMe` on first hit so UE3's own early-out removes it on subsequent ticks |

All patches include diagnostic logging to a ring buffer for post-mortem analysis.

## Files

- **`AliceMadnessReturns.CT`** -- Cheat Engine table with crash fixes and diagnostic logging
- **`launch-alice-cheatengine.ps1`** -- PowerShell launcher: starts game via Steam, waits for process, installs autoattach, launches CE
- **`alice-autoattach.lua`** -- CE autorun script template; stamps in the CT path at launch time, self-deletes after running
- **`img/`** -- Reference screenshots of crash sites

## Usage

### Automatic (recommended)

Run `launch-alice-cheatengine.ps1` from this directory. It will:

1. Launch the game via Steam
2. Wait for `AliceMadnessReturns.exe` to appear
3. Copy the autoattach script to CE's `autorun/custom/` directory
4. Launch Cheat Engine, which auto-attaches and ticks the crash fixes

### Manual

1. Open Cheat Engine and attach to `AliceMadnessReturns.exe`
2. Load `AliceMadnessReturns.CT`, or place it in user's "Documents/My Cheat Tables" for Cheat Engine to find on attach to `AliceMadnessReturns.exe`
3. Tick "Fix Crashes" and "Kill Zombie BreakableObject"

## Requirements

- [Cheat Engine](https://www.cheatengine.org/) (32-bit, `cheatengine-i386.exe`)
- Alice: Madness Returns (Steam build)
- Compatible with [MadnessPatch](https://github.com/Wemino/MadnessPatch)

## How it works

**Hair curve over-read (#1):** The hair physics system uses cubic B-spline curves defined by knot arrays. The vanilla curve evaluator's inner loop runs N+2 iterations, causing a speculative read 0xB0 bytes past the end of the knot array. This usually lands on committed heap memory (harmless), but occasionally hits a decommitted page and crashes. The fix prevents the over-read entirely while preserving the curve evaluation output. A VirtualQuery cache avoids repeated syscalls for the same memory region.

**Linked-list sentinel (#2, #3):** UE3's generic `TList` iterator uses the sentinel value `1` as an end-marker. Both `operator++` and `operator+=` dereference this value as a node pointer, crashing at addresses like `0x00000005`. A separate list-walk loop at `+0xE36F7` uses `[node+0x28]` as its next-pointer and hits the same sentinel. All three sites get guard checks; the call-site at `+0xBE0F63` adds defense-in-depth.

**Worker thread family (#4–#9):** Six crashes in worker threads and GFx helpers, all involving dangling/corrupt pointers or page-boundary over-reads. Each gets a per-site guard: low-address sentinel checks, vtable-range validation against the EXE's `.rdata` section, SEH handlers for unpredictable fault addresses, and null-this checks during `LoadMap` teardown. Skipped calls balance the stack to match the original calling convention (stdcall cleanup).

**Zombie BreakableObject (#10):** A level-streaming race condition specific to Chapter 5's rolling ball puzzle. When transitioning from puzzle 2 to puzzle 3, the async level loader adds a `GameBreakableActor`'s collision component to the physics tick iteration list before its rigid body physics is initialized. The object carries `RF_PendingKill | RF_AsyncLoading` flags — a zombie that will never initialize and never be cleaned up. Vanilla UE3 calls `appError()` and terminates the process. The fix intercepts the not-initialized branch, sets the object's `bDeleteMe` flag, and returns cleanly so UE3's own deletion logic removes it on the next tick.

All patches include diagnostic logging to a ring buffer for post-mortem analysis.

See the images in `img/` for example crash logs.
