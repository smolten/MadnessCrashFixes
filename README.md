# MadnessCrashFixes

Cheat Engine table and launcher for **Alice: Madness Returns** (Steam) that fixes several vanilla crash bugs.

## What it fixes

| # | Crash | Root cause | Fix |
|---|-------|-----------|-----|
| 1 | Hair curve evaluator | Over-reads knot array by 0xB0 bytes; crashes when trailing page is decommitted | Single-byte comparison bound fix + code cave that skips the over-read path |
| 2-3 | Linked-list iterator | `operator++` / `operator+=` dereferences sentinel value `1` as a node pointer | Guard checks in both operators + defense-in-depth call-site guard |
| 4-6 | Worker thread family | Null-this, vtable garbage, and other race-condition crashes | Per-site null/validity checks with logging |
| 7 | Zombie BreakableObject | Level streaming adds a `GameBreakableActor` collision component to the physics tick list before `InitComponentRBPhys` runs; object is `RF_PendingKill \| RF_AsyncLoading` and never initializes | Hook the not-initialized branch; set `bDeleteMe` on first hit so UE3's own early-out removes it on subsequent ticks |

All patches include diagnostic logging to a ring buffer for post-mortem analysis.

## Files

- **`AliceMadnessReturns.CT`** -- Cheat Engine table with all crash fixes (ID 0) and diagnostic logging
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
2. Load `AliceMadnessReturns.CT`
3. Tick "Fix Crashes" and "Kill Zombie BreakableObject"

## Requirements

- [Cheat Engine](https://www.cheatengine.org/) (32-bit, `cheatengine-i386.exe`)
- Alice: Madness Returns (Steam build)
- Compatible with [MadnessPatch](https://github.com/Wemino/MadnessPatch)

## How it works

The hair physics system uses cubic B-spline curves defined by knot arrays. The vanilla curve evaluator's inner loop runs N+2 iterations, causing a speculative read 0xB0 bytes past the end of the knot array. This usually lands on committed heap memory (harmless), but occasionally hits a decommitted page and crashes. The fix prevents the over-read entirely while preserving the curve evaluation output.

The linked-list crashes occur in UE3's generic `TList` iterator, where the sentinel end-marker value `1` is dereferenced as a node pointer during iteration.

The zombie BreakableObject crash is a level-streaming race condition specific to Chapter 5's rolling ball puzzle. When transitioning from puzzle 2 to puzzle 3, the async level loader adds a `GameBreakableActor`'s collision component to the physics tick iteration list before its rigid body physics is initialized. The object carries `RF_PendingKill | RF_AsyncLoading` flags -- a zombie that will never initialize and never be cleaned up. Vanilla UE3 calls `appError()` and terminates the process. The fix intercepts the not-initialized branch, sets the object's `bDeleteMe` flag, and returns cleanly so UE3's own deletion logic removes it on the next tick.

See the images in `img/` for annotated crash-site diagrams.
