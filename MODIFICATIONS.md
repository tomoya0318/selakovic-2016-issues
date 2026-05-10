# Modifications relative to upstream

This repository is a fork of https://github.com/marijaselakovic/JavaScriptIssuesStudy
(upstream commit `c2f63062aab6e76513696a3962e37d57b39dccad`). It is used by
[MB-Scanner](https://github.com/tomoya0318/MB-scanner)'s equivalence checker
(`mbs check-equivalence`) to evaluate optimization patches under sandboxed
execution.

## What changed

**Only addition: `package.json` + `pnpm-lock.yaml` declaring the SUT libraries'
own npm dependencies.** The upstream dataset ships each `<lib>_before/` /
`<lib>_after/` (the library under study) but does **not** bundle the libraries'
own npm dependencies, so server-side issues fail at `require('<npm-dep>')` and
cannot be executed. We add a `package.json` (the dependency closure declared in
each `<lib>_before/package.json` / required by each `<lib>_before.js`) at each
issue (or shared per category) so the deps can be installed offline-reproducibly
via `pnpm install --frozen-lockfile`.

`node_modules/` is intentionally **not** committed (`.gitignore`d) — running
`scripts/install-vendor-deps.sh` from the fork root regenerates it from the
lockfiles. This keeps the repo small and avoids platform-specific issues with
committed `node_modules` (symlinks, permissions, etc.).

**No issue content was changed** — `*.js` patch files, `Description.md`,
`Confirmed.md`, the set of issues, and the directory structure are byte-identical
to upstream.

## Layout (10 vendor locations)

The placement strategy follows version-conflict avoidance: package.json is
placed per-issue when SUT versions differ across issues, and shared at a parent
when they don't.

| location | SUT library (version) | dependencies declared |
|---|---|---|
| `serverIssues/ChalkIssues/issues/issue_27a/` | chalk ~1.x (single-file `chalk_before.js`) | ansi-styles@2.2.1, escape-string-regexp@1.0.5, strip-ansi@3.0.1, supports-color@2.0.0, has-ansi@2.0.0 |
| `serverIssues/ChalkIssues/issues/issue_27b/` | chalk ~1.x | (same as 27a) |
| `serverIssues/ChalkIssues/issues/issue_28/` | chalk@0.4.0 (per-issue: `ansi-styles` etc. major-conflict with 27a/27b) | ansi-styles@1.1.0, escape-string-regexp@1.0.5, has-ansi@0.1.0, strip-ansi@0.3.0, supports-color@0.2.0 |
| `serverIssues/CheerioIssues/` (shared, 8 issues) | cheerio@0.13.1 | htmlparser2@3.4.0, underscore@1.5.2, entities@0.3.0, CSSselect@0.4.1 |
| `serverIssues/MochaIssues/issues/issue_763/` | mocha@1.8.2 | commander@0.6.1, growl@1.7.0, jade@0.26.3, diff@1.0.2, debug@4.4.3, mkdirp@0.3.3, ms@0.3.0 |
| `serverIssues/RequestIssues/issues/issue_403/` | request@2.12.1 | form-data@0.0.10, mime@1.2.11 |
| `serverIssues/RequestIssues/issues/issue_1165/` | request@2.45.1 (`optionalDependencies` omitted) | bl@0.9.5, caseless@0.6.0, forever-agent@0.5.2, form-data@0.1.4, json-stringify-safe@5.0.1, mime-types@1.0.2, node-uuid@1.4.8, qs@1.2.2, tunnel-agent@0.4.3 |
| `serverIssues/Socket.ioIssues/issues/issue_573/` | socket.io@0.8.5 | socket.io-client@0.8.5, policyfile@0.0.4, redis@0.6.6 |
| `serverIssues/Socket.ioIssues/issues/issue_689/` | socket.io@0.8.7 | socket.io-client@0.8.7, policyfile@0.0.4, redis@0.6.7 |
| `clientServerIssues/BackboneIssues/` (shared, 4 issues: 707/1097/1766/2858) | backbone@0.5.3–1.1.0 | underscore@1.13.8 (satisfies all backbone ranges: `>=1.1.2` / `>=1.3.1` / `>=1.4.3`) |

Why the placement varies:
- **Per-issue when versions conflict:** chalk@1 (27a/27b) and chalk@0.4 (28) need
  different majors of `ansi-styles` etc.; request@2.12 (403) and request@2.45
  (1165) have non-overlapping dep sets; socket.io has patch-level differences
  (0.8.5 vs 0.8.7).
- **Shared when versions don't conflict:** all 8 cheerio issues use cheerio@0.13.1
  with identical deps; all 4 backbone issues are satisfied by underscore@1.13.8.
- Node's directory-based module resolution walks upward, so a `node_modules/` at
  any ancestor of the issue dir is resolvable from the issue.

## Not changed (known-unrunnable, left as-is)

These issues fail for reasons unrelated to npm-dep vendoring; vendoring deps
would not help them. They remain runnable in name only.

- `clientIssues/EmberIssues/issues/issue_9991`: Ember 1.x's internal AMD loader
  requires `jquery` as a registered AMD module (not an npm package), so vendoring
  npm deps does not help. Needs an Ember-specific bootstrap; out of scope.
- `clientIssues/ReactIssues/issues/issue_934`: inline `<script>` is JSX (needs a
  parser plugin + transpilation). Not a dependency issue.
- `clientServerIssues/MomentIssues/issues/issue_1785`: patch spans two files
  (`Gruntfile.js` + `moment.js`). Not a dependency issue.

## How to install (one-time after clone or submodule update)

```bash
# from the fork root:
./scripts/install-vendor-deps.sh
```

This runs `pnpm install --frozen-lockfile` in each of the 10 locations above,
regenerating `node_modules/` from the committed lockfiles. Requires `pnpm` in
`PATH` (`npm i -g pnpm` or `corepack enable`).

## How to regenerate the lockfiles (rarely needed)

If a dep needs adjusting:

```bash
cd <issue-or-shared-dir>
# edit dependencies in package.json
pnpm install --lockfile-only       # update pnpm-lock.yaml without touching node_modules/
git add package.json pnpm-lock.yaml
```

The dependency lists come from each `<lib>_before/package.json`'s `dependencies`
field (directory-form libs) or the bare `require()` calls in `<lib>_before.js`
(single-file libs).

## Reproducibility notes

- The lockfiles pin every transitive dep by `integrity` hash, so as long as the
  packages remain on the npm registry the install is byte-reproducible.
- Long-term archival (against npm package un-publishing or registry outage) is
  out of scope for this fork; a future `nix` derivation in MB-Scanner will
  provide content-addressable cache.

## Provenance

Layout, version selections, and version-conflict strategy follow MB-Scanner's
ADR-0017 ("equivalence-sandbox SUT dependency resolution — lockfile-vendored
fork"). See the MB-Scanner repository for the decision record.
