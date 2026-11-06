# Version tests (layer 1)

`version-bump.sh` checks the release rules with the repository's real `.github/release/releaserc.json` and
`.github/scripts/*.sh`, using the same engine as CI (`semantic-release@25.0.9`). It needs `git`, `jq` and `npx`
(Node 22.14 or later) and takes about a minute.

```bash
bash tests/version-bump.sh          # prints PASS/FAIL per scenario, exits 1 on any failure
bash tests/version-bump.sh --keep   # also keeps the work directory for inspection
```

## Nothing reaches GitHub

The script builds a throwaway repository under `$TMPDIR` whose `origin` is a local bare repository (`file://`).
No branch, pull request, tag or release is ever created on GitHub:

- it refuses to run semantic-release unless `origin` is the `file://` bare repository of the run;
- the test config drops `@semantic-release/github` and sets `repositoryUrl` to that bare repository;
- `GITHUB_TOKEN` and `GH_TOKEN` are unset and the user and system git config are ignored.

Steps marked as released run semantic-release for real against the local bare repository, so the tags and the
channel notes of hotfix releases are the ones CI creates. The `pom.xml` commit (`@semantic-release/git`) is not
part of the test: it does not change the computed version.

## Scenarios

| Scenario | Branch | Expected |
|---|---|---|
| `fix` with no tag at all | `master` | `1.0.0` (semantic-release always starts at 1.0.0) |
| `fix` after baseline tag `0.0.0` | `master` | `0.0.1` |
| `feat` | `master` | `0.1.0` |
| `docs`, `chore`, `ci` | `master` | no release |
| `perf`, `revert` | `master` | patch |
| Merge commit bringing a `fix` and a `feat` | `master` | minor (highest bump wins) |
| `feat!` | `master` | major |
| `BREAKING CHANGE:` footer | `master` | major |
| `fix` on `hotfix/2.0.0` while `master` is at `2.1.0` | `hotfix/2.0.0` | `2.0.1-hotfix.1`, then `2.0.1-hotfix.2` |
| `feat` on `hotfix/2.0.0` | `hotfix/2.0.0` | rejected by `hotfix-guard.sh` |
| Merge of `hotfix/2.0.0` into `master` (`fix` title) | `master` | `2.1.1` |
| `hotfix/2.0.0` updated from `master` | `hotfix/2.0.0` | rejected by `hotfix-guard.sh` |
| `fix` on a branch not named after a production tag | `hotfix/001`, `hotfix/2.0`, `hotfix/v2.0.0` | no release, not treated as a hotfix branch |
| `hotfix/2.0.0` recreated from `2.0.0` or `2.0.1-hotfix.1` after `2.0.1-hotfix.2` | `hotfix/2.0.0` | rejected by `hotfix-guard.sh`: the computed tag already exists |
| `hotfix/2.0.0` recreated from `2.0.1-hotfix.2` | `hotfix/2.0.0` | `2.0.1-hotfix.3` |

Each step follows the CI order: a dry run computes the version, `hotfix-guard.sh` checks it, and only then does a
released step publish.

Not covered here: the snapshot version of a PR, the Maven and docker builds, and the GitHub settings, rulesets and
tokens. Those need the end-to-end run on a sandbox repository (layer 2).
