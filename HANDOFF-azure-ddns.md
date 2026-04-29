# HANDOFF — azure-ddns publishing handoff (web → local)

> **Delete this file after reading.** It's throwaway cold-start context for
> a single local Claude Code session. Once read and acted on, remove it:
>
> ```bash
> git rm HANDOFF-azure-ddns.md && \
>   git commit -m "remove consumed azure-ddns handoff" && \
>   git push origin main
> ```

**Audience:** a fresh Claude Code session running locally on the user's
dev machine, with normal `git` + `gh` CLI access (not the GitHub MCP-only
sandbox the prior session was confined to).

**Why a handoff:** the prior session was a web Claude Code instance with
GitHub MCP scoped to two repos and no `gh` CLI. It got the `azure-ddns`
repo extracted, populated, CI'd, and release-workflowed, but cannot
create GitHub releases, trigger workflows, or delete branches. Those
final steps are yours.

---

## State as of 2026-04-29

### `fnrhombus/azure-ddns` (public, on GitHub)

- **main HEAD before this handoff:** `e7072751` "readme: document
  azure-ddns-git companion package"
- **Layout:**
  ```
  .github/
    FUNDING.yml                       # github + buy_me_a_coffee, both fnrhombus
    workflows/
      ci.yml                          # shellcheck/bash-n/systemd-analyze/namcap
      release.yml                     # validate / publish-stable / publish-git
  aur/
    azure-ddns/PKGBUILD               # release flavor; CI fills sha256sums
    azure-ddns-git/PKGBUILD           # VCS flavor; pkgver() via git describe
  bin/azure-ddns                      # the script
  systemd/azure-ddns.{service,timer}
  dispatcher.d/90-azure-ddns          # NetworkManager hook
  azure-ddns.env.template             # /etc/azure-ddns.env template
  LICENSE                             # MIT
  README.md
  .gitignore                          # makepkg artifacts
  ```
- **Repo secrets configured** (user confirmed): `AUR_USERNAME`, `AUR_EMAIL`,
  `AUR_SSH_PRIVATE_KEY` (ed25519 dedicated key, pubkey on AUR account).
- **Repo visibility:** public.
- **Orphan branch:** `claude/azure-ddns-handoff-CFdaF` still exists.
  It's a strict subset of main's content (6 of main's files, no shared
  history). Safe to delete. The web session couldn't because no
  delete-branch MCP tool existed.

### `fnrhombus/arch-setup` (untouched by the prior session)

- The user explicitly directed: **don't write to arch-setup until
  authorized**.
- Pending work for arch-setup (user must give green light first):
  1. Write `HANDOFF-BACK-azure-ddns.md` at repo root per the format
     described in `TODO-azure-ddns-handoff.md` §"What goes in
     HANDOFF-BACK-azure-ddns.md".
  2. `git rm TODO-azure-ddns-handoff.md` (input is consumed).
  3. `git rm -r staged-azure-ddns/` (now redundant — its content is
     upstream).
  4. Single commit, push straight to `main` (user said no feature branches).

---

## Your job, in order

### 1. Verify CI baseline

```bash
gh run list --repo fnrhombus/azure-ddns --limit 5
```

Expected state: at least one `release` workflow run from commit `818e604`
(the commit that added release.yml — its own paths filter caught it).
That run almost certainly **failed** because secrets weren't set yet.
There may also be a `ci` workflow run from `e7072751` (the README update).

### 2. Publish v0.1.0 (the most important step)

This is the cleanest end-to-end smoke test of the whole pipeline.

```bash
gh release create v0.1.0 \
    --repo fnrhombus/azure-ddns \
    --title 'v0.1.0 — initial release' \
    --target main \
    --generate-notes
```

That triggers `release.yml → publish-stable`, which:
1. `sed`s `pkgver=0.1.0` into `aur/azure-ddns/PKGBUILD`.
2. Runs `updpkgsums` to fill in real `sha256sums` (replacing `SKIP`).
3. Test-builds the package inside an Arch container.
4. Pushes the resulting PKGBUILD + `.SRCINFO` to
   `ssh://aur@aur.archlinux.org/azure-ddns.git`.

Watch live:

```bash
gh run watch --repo fnrhombus/azure-ddns
```

If the run fails at any step:
- **`updpkgsums` step**: usually means the GitHub release tarball isn't
  yet visible to the Arch container (race). Re-run from Actions UI.
- **SSH/keyscan step**: bad key registration on AUR side, or wrong key
  in `AUR_SSH_PRIVATE_KEY`. Compare `ssh-keygen -y -f /tmp/key` against
  what's at https://aur.archlinux.org/account/.
- **`makepkg -s` step**: PKGBUILD is broken. Capture the log, paste
  it back and we'll fix.
- **AUR push step**: package name conflict (someone else owns
  `azure-ddns` — unlikely but possible). Handle by renaming `pkgname`
  in `aur/azure-ddns/PKGBUILD` and the workflow.

On success: https://aur.archlinux.org/packages/azure-ddns appears within
~30s.

### 3. Trigger publish-git

If the run from `818e604` is still showing as failed in the Actions tab:

```bash
gh run rerun <run-id> --repo fnrhombus/azure-ddns
```

If there's no failed run, push any one-line commit that touches a
release.yml-watched path (e.g. `bin/azure-ddns`, `systemd/`, `aur/`).
Don't do a noop README edit — README isn't in the paths filter, by
design (README changes shouldn't republish to AUR).

On success: https://aur.archlinux.org/packages/azure-ddns-git appears.

### 4. Smoke-test on a real Arch box (optional but recommended)

```bash
yay -S azure-ddns
sudo cp /etc/azure-ddns.env /etc/azure-ddns.env.bak
sudo "$EDITOR" /etc/azure-ddns.env       # fill in your SP creds
sudo systemctl start azure-ddns.service
sudo journalctl -u azure-ddns -n 20
dig +short A <record>.<zone>
```

Confirm: token mints, PUT succeeds, DNS resolves, last-cache files at
`/var/lib/azure-ddns/{a,aaaa}.last` get written.

If both flavors install cleanly and the daemon updates DNS, the
extraction is fully validated.

### 5. Delete the orphan branch

```bash
git clone git@github.com:fnrhombus/azure-ddns.git /tmp/azure-ddns
cd /tmp/azure-ddns
git push origin --delete claude/azure-ddns-handoff-CFdaF
```

### 6. Delete this handoff file

Once you've worked through the steps above and confirmed everything is
green, delete this file from main:

```bash
cd /tmp/azure-ddns      # or wherever your local clone is
git rm HANDOFF-azure-ddns.md
git commit -m "remove consumed azure-ddns handoff"
git push origin main
```

### 7. (When the user authorizes) close out the arch-setup side

Only after the user explicitly says it's OK to write to arch-setup:

```bash
cd ~/path/to/arch-setup
git checkout main && git pull --ff-only origin main
# write HANDOFF-BACK-azure-ddns.md (template below)
git add HANDOFF-BACK-azure-ddns.md
git rm TODO-azure-ddns-handoff.md
git rm -r staged-azure-ddns/
git commit -m "azure-ddns: extracted to fnrhombus/azure-ddns; report back"
git push origin main
```

#### Template for `HANDOFF-BACK-azure-ddns.md`

```markdown
# Azure DDNS extraction — handoff back

## Outcome
created: fnrhombus/azure-ddns now hosts the extracted DDNS code, with
two AUR flavors published (azure-ddns + azure-ddns-git) and CI wired
to GitHub Actions.

## Repo state
- URL: https://github.com/fnrhombus/azure-ddns
- Visibility: public
- Default branch: main
- File tree: bin/azure-ddns, systemd/azure-ddns.{service,timer},
  dispatcher.d/90-azure-ddns, azure-ddns.env.template, LICENSE,
  README.md, .gitignore, .github/{FUNDING.yml,workflows/{ci,release}.yml},
  aur/{azure-ddns,azure-ddns-git}/PKGBUILD

## Drift between in-arch-setup `metis-ddns/` and upstream `azure-ddns`
Comment-only differences across .service, .timer, dispatcher.
One non-cosmetic addition upstream: AZURE_DDNS_ENV / AZURE_DDNS_CACHE /
AZURE_DDNS_TOKEN_CACHE env-var path overrides in bin/azure-ddns
(test affordance, not a regression). Default values unchanged.
**No logic divergence.**

## Smoke-check results
- bash -n bin/azure-ddns: pass
- bash -n dispatcher.d/90-azure-ddns: pass
- shellcheck: not run on web sandbox; CI runs it on every push/PR
- systemd-analyze verify: not run on web sandbox; CI runs it
- namcap PKGBUILD: not run on web sandbox; CI runs it inside Arch container
- AUR end-to-end: <pass | fail — fill in based on §2/3 outcomes>

## Suggested next-session work for arch-setup
- [ ] Update phase-3-arch-postinstall/postinstall.sh §4d to install
      azure-ddns from AUR (`yay -S azure-ddns`) instead of consuming the
      in-repo metis-ddns/ tree.
- [ ] Delete phase-3-arch-postinstall/metis-ddns/ once §4d is migrated.
- [ ] Adjust env-file path: postinstall currently writes
      /etc/metis-ddns.env; the upstream package expects
      /etc/azure-ddns.env. setup-azure-ddns.sh and any docs/runbook
      references need the same rename.
- [ ] Update setup-azure-ddns.sh's SP_DISPLAY_NAME if the existing
      "metis-ddns" service principal should be renamed to "azure-ddns"
      in Azure (or leave it — it's just a label).

## Things noticed but did NOT fix
- staged-azure-ddns/HANDOFF.md said "keep this repo private until
  verified on a fresh VM"; user opted to flip public earlier. Worth
  documenting in docs/decisions.md.
- The .github/workflows/lint.yml in arch-setup has `staged-azure-ddns`
  in its `ignore_paths`; remove that line in a follow-up commit (the
  directory no longer exists).
```

---

## Decisions baked in (don't relitigate without reason)

- **Two AUR packages** (`azure-ddns` + `azure-ddns-git`) is canonical
  Arch pattern for "stable + rolling". User explicitly chose it after
  asking about npm `@next`/`@latest` analog.
- **`KSXGitHub/github-actions-deploy-aur@v4.1.3`** — most-used,
  actively maintained AUR push action as of 2026-04.
- **PKGBUILD lives at `aur/<flavor>/PKGBUILD`**, not repo root. Root
  PKGBUILD was deleted in commit `c2efd64`.
- **`updpkgsums` runs in CI only.** Repo-side PKGBUILDs use
  `sha256sums=('SKIP')`; CI replaces with real sums before AUR push.
  This means a manual `makepkg -si` from a fresh checkout won't
  integrity-check unless the user runs `updpkgsums` first.
- **`workflow_dispatch` is intentionally NOT in release.yml.** Re-runs
  go through the Actions UI's "Re-run failed jobs" button. Adding
  workflow_dispatch was deferred — open an issue if it'd be useful.
- **Repo is public, single-maintainer, no formal security audit.**
  README says so explicitly.

---

## Things the prior (web) session genuinely couldn't do

- Create GitHub releases (no MCP tool — `gh release create` is your job).
- Trigger or re-run workflows (no MCP tool).
- Read workflow run logs (no MCP tool — `gh run view` works for you).
- Delete branches (no MCP tool — `git push --delete` works for you).
- Run shellcheck/namcap/makepkg locally (sandbox didn't have them
  installed; CI handles all of that).
- Write to fnrhombus/arch-setup (user-imposed restriction).

---

## Quick reference

- **Trigger paths in release.yml:** `bin/**`, `systemd/**`,
  `dispatcher.d/**`, `azure-ddns.env.template`, `aur/**`,
  `.github/workflows/release.yml`. README/LICENSE/etc. don't
  re-publish — by design.
- **AUR action's `test_flags`:** `--clean --cleanbuild --nodeps
  --syncdeps --noconfirm` — builds inside the action's container
  before pushing; abort the AUR push on build failure.
- **AUR package URLs after publish:**
  - https://aur.archlinux.org/packages/azure-ddns
  - https://aur.archlinux.org/packages/azure-ddns-git

---

## If something breaks, debug order

1. `gh run view --log-failed` on the failing workflow run.
2. Compare `aur/azure-ddns/PKGBUILD` against the published
   `https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=azure-ddns`.
3. `makepkg -s` locally inside `archlinux:base-devel` to reproduce
   what CI does.
4. If `updpkgsums` is failing because the release tarball doesn't
   exist yet (race), wait 30s and re-run the workflow.
5. If SSH push is failing, regenerate the AUR deploy key and re-set
   `AUR_SSH_PRIVATE_KEY`.

That's it. Two clicks (release publish + maybe re-run publish-git)
plus a branch deletion get you to a green steady state. Then `git rm`
this file and you're done.
