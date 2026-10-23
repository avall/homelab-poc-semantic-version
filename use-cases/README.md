# Use cases

Scripts that exercise the release rules end to end on GitHub. Each script prints its plan and asks for confirmation (pass `--yes` to skip it). They push branches, open PRs, merge them and wait for the workflows, so they are **remote writes**.

- Run them **in order, on a fresh repository** (no tags), after the one-time setup in the root README. Later versions depend on earlier ones.
- Jira keys `CK-9001` ... `CK-9016` and `CK-905x` are **fake**: they only satisfy the `subjectPattern` of `pr-title`.
- Each PR changes one file under `use-cases/playground/` (a small real change). The title, not the change, decides the bump.
- Work happens in temporary git worktrees (`$WORK_ROOT`, default under `$TMPDIR`), so your checkout is not switched.
- Cases 11, 12 and 14 need tag `1.0.0` (case 01) and run the `hotfix-start` workflow with `gh workflow run`.
- Requirements: `gh` (authenticated with repo scope), `git`, and `gh stack` for case 08.

## Expected sequence

| # | Script | PR title | Base | Expected result |
|---|---|---|---|---|
| 01 | `01-first-release.sh` | `feat: CK-9001 add hello endpoint` | `master` | **1.0.0** (first release is always 1.0.0) |
| 02 | `02-patch-fix.sh` | `fix: CK-9002 return plain text content type` | `master` | **1.0.1** |
| 03 | `03-perf-patch.sh` | `perf(hello): CK-9003 cache the greeting response` | `master` | **1.0.2** |
| 04 | `04-minor-feat.sh` | `feat(hello): CK-9004 add greeting language header` | `master` | **1.1.0** |
| 05 | `05-no-release.sh` | `docs:` / `chore:` / `test:` / `refactor(hello):` `CK-905x ...` | `master` | no tag (4 runs, "no relevant changes") |
| 06 | `06-invalid-titles.sh` | `CK-9006`, `Feature: ...`, `feat add ...`, `docs: document ...` (no key), then `docs: CK-9006 document the PR title rules` | `master` | `pr-title` fails 4 times, passes after `gh pr edit --title`; no tag |
| 07 | `07-breaking-major.sh` | `feat(api)!: CK-9007 remove the deprecated greeting parameter` | `master` | **2.0.0** |
| 08 | `08-stacked-prs.sh` | `fix: CK-9008 ...` + `feat: CK-9008 ...` (gh stack) | `master` | **2.1.0**, one release for both PRs |
| 09 | `09-revert-patch.sh` | `revert: CK-9009 restore whitespace in the greeting` | `master` | **2.1.1** |
| 10 | `10-guard-edited-subject.sh` | `fix: CK-9010 handle empty greeting` merged with `--subject "fix: CK-9010 edited in the merge dialog"`, then `fix: CK-9010 fix forward ...` | `master` | guard fails, no tag; fix forward gives **2.1.2** |
| 11 | `11-hotfix-line.sh` | `hotfix-start` with `base_tag=1.0.0`, `fix: CK-9011 handle null greeting on production 1.0.0`, then port `fix: CK-9011 port ...` | `hotfix/1.0.0`, then `master` | **1.0.1-hotfix.1** (Latest unchanged), then **2.1.3** on `master` |
| 12 | `12-feat-on-hotfix.sh` | `feat: CK-9012 add a feature on the 1.0.0 hotfix line` | `hotfix/1.0.0` | `pr-title` fails, PR blocked and closed, no tag |
| 13 | `13-dependabot-style.sh` | `build(deps): bump example-lib from 1.0.0 to 1.1.0` + label `dependencies` | `master` | `pr-title` passes (validation skipped), no tag |
| 14 | `14-concurrent-hotfixes.sh` | `fix: CK-9014 ...` and `fix: CK-9015 ...` open at the same time, then `hotfix-start` with `base_tag=1.0.1-hotfix.2` | `hotfix/1.0.0` | **1.0.1-hotfix.2**, **1.0.1-hotfix.3**; `hotfix-start` reuses the line and prints `1.0.1-hotfix.4` |
| 15 | `15-snapshot.sh` | `test: CK-9016 snapshot simulation`, two pushes, closed without merge | `master` | `0.0.0-CK-9016-SNAPSHOT` printed twice, then its `DELETE`; no tag |

Final tags: `1.0.0 1.0.1 1.0.2 1.1.0 2.0.0 2.1.0 2.1.1 2.1.2 1.0.1-hotfix.1 2.1.3 1.0.1-hotfix.2 1.0.1-hotfix.3`.

## How to verify each case

- Tags: `git fetch --tags && git tag --sort=-v:refname`
- Releases: `gh release list` and `gh release view <version>` (notes are built from the PR titles)
- Actions log of the `release` run (`gh run list --workflow release.yml`, then `gh run view <id> --log`):
  - guard: `OK <sha>: <title> (#N)` or `::error::<sha> message differs from its PR title`
  - semantic-release: `Published release X.Y.Z` or `There are no relevant changes, so no new version is released`
  - build job: `IMAGE ghcr.io/avall/homelab-poc-semantic-version:X.Y.Z-oci` and `IMAGE ghcr.io/avall/homelab-poc-semantic-version:X.Y.Z`
  - deploy job: `DEPLOYMENT OF VERSION X.Y.Z completed in the infra`
- `hotfix-start` run (`gh run list --workflow hotfix-start.yml`): `Created line hotfix/1.0.0 ...` or `Reused existing line ...`, and `Next version on merge: ...`.
- `hotfix-release` run (`gh run list --workflow hotfix-release.yml`): `Hotfix version 1.0.1-hotfix.N on line hotfix/1.0.0`, the two `IMAGE` lines and the release URL.
- `snapshot` run (`gh run list --workflow snapshot.yml --branch CK-9016-snapshot`): `[simulated] mvn deploy -> Nexus snapshots: ...` or `[simulated] DELETE ... from Nexus snapshots`.
- The run summary page shows the same lines (`$GITHUB_STEP_SUMMARY`).

## Notes per case

- **01:** the endpoint code is already on `master` from the bootstrap commit; the PR title is what produces 1.0.0. With no tag, semantic-release analyzes the whole history; non-conventional commits (e.g. `Initial commit`) are ignored.
- **06:** each title edit triggers `pr-title` (`edited` event). The script finds the run by its display title, which for `pull_request_target` is the PR title (not verified on this repo yet).
- **08 (gh stack):**
  - Verified from `gh stack merge --help` (v0.2.1): the stack is merged "in a single, all-or-nothing operation" and `--squash` gives one squash commit per PR.
  - Not verified: that this is **one push event** to `master`. If it is, there is one release run whose guard checks both commits and one release with the highest bump (`feat` -> 2.1.0). If GitHub pushes each PR separately, you get **two** runs and two releases (`2.0.1`, then `2.1.0`). The script prints the last release runs so you can tell which happened.
  - Not verified: that GitHub keeps `<PR title> (#N)` as each squash message in a stack merge; the guard reports it if not.
  - `ci.yml` has no branch filter, so the upper PR (base = lower PR branch) also gets the required `build` check.
- **09:** the GitHub "Revert" button titles PRs `Revert "..."`, which fails `pr-title`; rename it to `revert: CK-1234 ...`.
- **10:** the guard checks only the commits of the push (`before..after`). The fix-forward push contains only the new commit, so it passes, and semantic-release releases both fixes since the last tag (the edited commit still starts with `fix:`). If the edited subject had a wrong type, revert it with a correctly titled PR instead.
- **11:** `hotfix-start` creates `hotfix/1.0.0` at the commit of tag `1.0.0` with `POST /repos/{owner}/{repo}/git/refs` (or reuses it). The merge into the line runs `hotfix-release` (not semantic-release), which tags `1.0.1-hotfix.1` with `--latest=false`, so the Latest release does not change. The port uses a cherry-pick branch from `master`; the line is never merged into `master`.
- **12:** the `pr-title` step "Hotfix lines accept only fix, perf and revert" fails, and the required check blocks the merge. The script never tries to merge, so the line stays clean even without rulesets. If it were merged, `hotfix-release` re-checks the title and fails without a tag.
- **13:** `ignoreLabels: dependencies` makes `pr-title` succeed without validation; `pr-title` also listens to `labeled`/`unlabeled` so adding the label re-runs it. `build` type gives no release.
- **14:** both PRs start from the same line commit. The ruleset requires branches to be up to date (`strict_required_status_checks_policy: true`), so after the first merge the second PR is `BEHIND`: `merge_pr` runs `gh pr update-branch` and waits for its checks, which now build CK-9015 together with CK-9014. `hotfix-release` runs one at a time per line (`concurrency`), so the numbers never collide; `hotfix.3` contains `hotfix.1`, CK-9014 and CK-9015. `hotfix-start` with a hotfix tag maps it to its line (`1.0.1-hotfix.2` -> `hotfix/1.0.0`). Numbers assume case 11 ran first.
- **15:** the script waits for each snapshot run before the next push, because `cancel-in-progress: true` would cancel the first run otherwise. The PR title has type `test`; it is closed without merge in any case.
