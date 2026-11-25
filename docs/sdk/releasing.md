# Releasing the Dart SDK to pub.dev

Two packages are published, **in this order**:

1. **`puls3_client`.** The API client that Serverpod generates from
   `puls3_server`.
2. **`puls3_sdk`.** The SDK developers install. It depends on `puls3_client`
   by version, because pub.dev does not accept a path dependency.

Inside this repository both are workspace members. `puls3_sdk` depends on
`puls3_client: ^0.1.0`, and the workspace still resolves it to
`../puls3_client`, so local development and CI never download it.

## Versions

Both packages use [semantic versioning](https://semver.org), and each has a
`CHANGELOG.md` with one section per release.

- **`puls3_client`** gets a new version whenever `serverpod generate` changes
  `puls3_client/lib`, that is, whenever an endpoint or a model changed on the
  server:
  - while it is `0.x`, a change that removes or renames anything is a **minor**
    bump (`0.1.0` → `0.2.0`);
  - an addition is a **patch** bump.
- **It pins the exact Serverpod version** of the server it was generated from
  (`serverpod_client: 4.0.4`, not `^4.0.4`). Serverpod's own client packages
  pin the same way, because the generated protocol has to match the server.
  `dart pub publish --dry-run` reports these pins as warnings, and CI accepts
  them.
- **`puls3_sdk`** gets a new version when its own API or behaviour changes,
  and when it needs a new `puls3_client`. After a minor bump of the client
  (`0.2.0`), update its constraint (`puls3_client: ^0.2.0`). In `0.x`, a caret
  allows only patch releases.
- **Every published version gets a git tag** on the commit it was published
  from: `puls3_client-v0.1.0`, `puls3_sdk-v0.1.0`. The format
  `<package>-v<X.Y.Z>` is the one
  [ADR-0015](../adr/0015-branching-and-artifact-versioning.md) sets for every
  published SDK; the npm package uses the prefix `sdk-ts`
  ([releasing-npm.md](releasing-npm.md)).

A published client must match the server that is deployed. Publish a new
`puls3_client` after the server change is deployed, not before.

## Who publishes

Publishing needs a pub.dev account with upload rights to both packages.
**The maintainers decide one of these:**

- **A verified publisher** (recommended). The packages then show the publisher
  instead of a person. It needs a domain the team controls, verified in
  Google Search Console (for example `puls3.org`), and the maintainers added as
  members.
- **The maintainers' own accounts** as uploaders. This is simpler at first,
  and the packages can move to a verified publisher later.

Nobody publishes from CI, and no pub.dev credential belongs in this
repository.

## Steps

From a clean checkout of the commit to publish, with the workspace resolved
(`dart pub get` at the root):

```bash
# 1. Check both packages. CI runs the same checks on every PR.
(cd puls3_client && dart pub publish --dry-run)   # only the Serverpod pin warnings
(cd puls3_sdk && dart pub publish --dry-run)      # "Package has 0 warnings."

# 2. Publish the client first, then the SDK.
(cd puls3_client && dart pub publish)
(cd puls3_sdk && dart pub publish)

# 3. Tag the commit with the published versions.
git tag puls3_client-v0.1.0
git tag puls3_sdk-v0.1.0
git push origin puls3_client-v0.1.0 puls3_sdk-v0.1.0
```

`dart pub publish` asks the publisher to sign in to pub.dev and confirm. A
version can never be published twice, and a published version can only be
retracted, not deleted. So check the dry runs, the `CHANGELOG.md` entries and
the `version` fields first.

## After the first release

- **Install instructions.** The SDK README and
  [`quickstart.md`](quickstart.md) switch from a path dependency to
  `dart pub add puls3_sdk`.
- **A check from outside the repo.** In a new Dart project outside the repo,
  run `dart pub add puls3_sdk`, then the catalog example against the public
  testnet server.
