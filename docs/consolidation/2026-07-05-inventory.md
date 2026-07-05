# MicDrop Consolidation Inventory — 2026-07-05

Consolidates the MicDrop project into its `X:\Repos\MicDrop` home per the DRVI Charter
[Project Consolidation Workflow](../../../drvi-charter/workflows/project-consolidation.md) and
[Data Classification & Placement Standard](../../../drvi-charter/standards/data-classification.md) (D-037).

**Bottom line:** MicDrop is the tidiest case in the consolidation set. The repo is self-consistent,
publish-ready, and free of secrets. The Drive reference folder holds a **single** artifact — the raw
ChatGPT-generated logo image — which is **byte-identical** to the repo's committed
`assets/logo-source.png`. There are **no chat exports, no seeds, no ChatRips** in Drive, so the
reconciliation surface is near-zero: nothing raw to distill, no lost-feature risk, no identity drift.
The only judgment call is whether the 2.27 MB raw source image belongs in-repo (it is a build input)
or in Drive only (it is raw evidence) — flagged below, not acted on. **No spec was rewritten; no file
deleted.**

## Sources inventoried

| Source | Tier | Location | Nature |
|---|---|---|---|
| Repo (tracked) | S | `X:\Repos\MicDrop` — 24 files: `*.ps1`, `README.md`, `docs/`, `tests/`, `.github/`, `assets/`, `config.example.json`, `LICENSE` | current canonical truth; clean `main`, up to date with `origin` |
| Drive reference folder | R | `G:\My Drive\DRVI\DRVI Projects\MicDrop\` | **one file**: `ChatGPT Image Jun 6, 2026, 03_34_33 PM.png` (2.27 MB) — raw AI logo source |
| GitHub | (courier) | `DevenRose/MicDrop` | remote mirror of the repo |

**Provenance link:** the Drive image and `assets/logo-source.png` share md5 `a39bc7041f9112fd4aaa240305f73469`
— the same file. `assets/Build-Assets.ps1` reads `logo-source.png` to regenerate every derived asset
(`logo-banner`, `logo` 1024/512/256, `favicon-32/16`), so the committed copy is the build input; the
Drive copy is the archived raw evidence.

## What already reconciles (no action)

- **Product identity holds.** Repo, README, and `docs/` all describe the same product: a Windows tray
  tool that stereo-locks (A2DP) a Bluetooth headset by disabling the HFP PnP node, with a one-click
  mic restore. No drift between what the docs claim and what the code does.
- **Docs match code.** The FxSound feature saga visible in the commit history
  (auto re-pin → device-change self-heal reverted for "restart storms" → manual **"Fix silent
  headset"** tray restart) has landed consistently in both code and docs:
  `MicDrop.Core.ps1` (`Resolve-MicDropManageFxSound`, `Restart-MicDropFxSound`), `MicDrop-Tray.ps1`
  (the "Fix silent headset (restart FxSound)" menu item), `config.example.json` (`manageFxSound`),
  and `README.md` / `docs/how-it-works.md` all agree. No stale or contradictory documentation.
- **No raw planning material to distill.** Drive carries no ChatRips, seeds, or multi-model exports —
  so unlike RagRouter there is no reservoir of undistilled decisions or lost features to recover.

## Findings

### F1 — TIERING JUDGMENT: raw logo source is both committed (S) and archived (R) — Captain call (leftovers pass)
`assets/logo-source.png` (2.27 MB raw ChatGPT image) is the genuine step-3-vs-4 ambiguity the standard
names: it is **raw AI evidence** (leans R — a human generated it, its exact copy sits in Drive) *and* a
**build input** `Build-Assets.ps1` reads to regenerate assets (leans S — a build reads it). Current
state keeps it in **both** homes. This is not a violation (the derived assets are legitimately S; the
source is legitimately archived in R), but it is a 2.27 MB binary duplicated across repo and Drive.
**Decision for the leftovers pass (OQ-9):** keep `logo-source.png` in-repo as the canonical build
input (and treat the Drive copy as redundant evidence), **or** drop it from the repo and have
`Build-Assets.ps1` regenerate from the Drive copy when needed. Not touched — flagged.

### F2 — STANDARDS GAP: no lean `AGENTS.md` in the repo
Per [`repo-standards`](../../../drvi-charter/standards/repo-standards.md) each DRVI project repo carries
its own lean `AGENTS.md` that references the Charter by pointer. MicDrop has none. Not created here
(authoring repo governance is out of this inventory's scope, G3). **Flagged** for a follow-up so the
repo joins the cross-tool governance switchboard.

### F3 — REGISTRY: MicDrop is "Needs review / Likely project" — business-boundary review pending
`drvi-charter/organization/project-registry.md` and `repo-registry.md` both list MicDrop with
"Needs business-boundary review." This consolidation confirms the repo home and Drive home but does
**not** settle whether MicDrop is a standalone DRVI product vs. a candidate — that remains a Captain
call. No registry edit made from this repo (the registries live in the Charter repo; one session, one
home — D-033).

## Placement / tiering (applied on this branch where safe)

| Artifact | Tier | Action |
|---|---|---|
| `*.ps1` (Core, Tray, Toggle, Install, Uninstall, Build-Assets) | S | Correct — tracked source. No change. |
| `README.md`, `docs/*.md`, `tests/*` | S | Correct — tracked. No change. |
| `LICENSE`, `.github/`, `config.example.json` | S | Correct — tracked. No change. |
| `assets/` derived images (banner, logo, 512/256, favicons) | S | Correct — build products, tracked. No change. |
| `assets/logo-source.png` | S / R | Committed build input **and** archived in Drive R (identical). Disposition = F1 (leftovers pass). Not touched. |
| Drive `ChatGPT Image Jun 6…png` | R | Already in Drive evidence vault. Leave in place. |
| Personal `config.json` | L | Correctly gitignored; not present locally. No secret in it by design. |
| `.gitignore` | S | **Already correct** — ignores personal `config.json` + OS/editor cruft; **no blanket `*.json`** anti-pattern. Nothing to fix. |
| Secrets (K) | — | **None found** anywhere in repo, Drive, or config. |
| Local caches (L) | — | None present (no `.venv`, `node_modules`, `dist`, ChatRips). |

## Open items for Captain
1. **F1** — `logo-source.png`: keep in-repo as build input, or drop and regenerate from the Drive copy? (leftovers pass / OQ-9)
2. **F2** — add a lean `AGENTS.md` pointer to the MicDrop repo (follow-up task).
3. **F3** — settle MicDrop's business boundary (standalone product vs. candidate); update Charter registries.

## Provenance
All findings trace to `X:\Repos\MicDrop` (git ls-files, working tree) and
`G:\My Drive\DRVI\DRVI Projects\MicDrop\`. md5 provenance link confirmed 2026-07-05
(Claude Opus 4.8, local). No raw chat exports existed to reconcile.
