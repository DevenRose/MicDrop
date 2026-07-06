# MicDrop — Known Issues

Status: **known and tracked**, not yet fixed. These are the current blockers to MicDrop being
presentable as a portfolio-grade DRVI asset (D-038 — evidence DRVI conceives and builds useful
things). They are captured honestly here so the repo's record is trustworthy: nothing hidden, each
item repro-and-fix scoped.

All items below are **Captain-reported** from hands-on use. Each still needs a clean reproduction
(exact steps + environment) before a fix, so treat the descriptions as symptoms to reproduce, not
root-cause diagnoses.

## Open issues

### KI-1 — Failing basic functions
- **Symptom:** Core/basic functions of the app are not working reliably (Captain-reported).
- **Impact:** Blocks a clean demo; undermines "it works" as evidence.
- **Next:** Reproduce the specific failing functions (which action, expected vs actual), capture
  logs/environment, then fix. Enumerate each failing function as a sub-item once reproduced.
- **Status:** Open — needs repro.

### KI-2 — Duplicate run-instance
- **Symptom:** A second instance of the app can launch while one is already running (no single-
  instance guard), leading to duplicate/competing instances (Captain-reported).
- **Impact:** Undefined behavior, possible resource/state conflicts; poor first impression in a demo.
- **Next:** Reproduce the double-launch path, then add a single-instance lock (e.g. named
  mutex / lock file / existing-window focus) so a second launch focuses the running instance
  instead of spawning a new one.
- **Status:** Open — needs repro + fix.

## Target

Resolve KI-1 and KI-2 so MicDrop is **presentable as evidence** — a working, single-instance app
that demonstrates DRVI's build capability to potential supporters and investors.
