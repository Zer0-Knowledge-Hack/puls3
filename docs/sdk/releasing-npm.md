# Releasing the TypeScript SDK to npm

`@puls3_org/sdk` (`puls3_sdk_ts/`) is published to npm **with provenance** (#302),
which only a CI run can produce: the registry records which repository,
commit and workflow built each version. So, unlike the Dart packages
([`releasing.md`](releasing.md)), its versions after the first are published
by `.github/workflows/publish-sdk-ts.yml` when a tag `sdk-ts-vX.Y.Z` is
pushed. No npm token is stored anywhere: npm "trusted publishing" trusts the
workflow's GitHub OIDC identity.

## Versions

Semantic versioning, with one `CHANGELOG.md` section per release. While the
version is `0.x`, a change that removes or renames anything is a **minor**
bump, and an addition is a **patch** bump. Every published version has the
tag `sdk-ts-vX.Y.Z`, and the workflow refuses a tag that does not match
`package.json`.

## One-time setup

1. **The npm organization.** Sign in to npmjs.com as `hello@puls3.org`, turn
   on two-factor authentication with an authenticator app, keep the recovery
   codes where the maintainers can reach them, and create the organization
   `puls3_org` (the `@puls3_org` scope; `@puls3` belongs to another npm
   organization). Add at least two maintainers as owners.
2. **The GitHub environment.** In Settings > Environments, create `npm` with
   required reviewers, so a pushed tag waits for a maintainer's approval.
3. **Tag protection.** Add a tag ruleset for `sdk-ts-v*`, so only maintainers
   can create it: anyone who can push such a tag can start a release.

## First publish

npm only lets a trusted publisher be added to a package that exists, so the
first version is published from a maintainer's machine, from a clean
checkout of the commit to publish:

```bash
npm login                                  # hello@puls3.org, with 2FA
cd puls3_sdk_ts
npm ci && npm run check && npm test && npm run build
npm publish --access public
git tag sdk-ts-v0.1.0 && git push origin sdk-ts-v0.1.0
```

This first version has no provenance. Then, on the package's settings page
on npmjs.com:

- **Trusted publisher:** GitHub Actions, organization `Zer0-Knowledge-Hack`,
  repository `puls3`, workflow `publish-sdk-ts.yml`, environment `npm`. The
  fields are case-sensitive and npm checks them only at the next publish. A
  new trusted publisher that does not publish within 2 days expires.
- **Publishing access:** "Require two-factor authentication and disallow
  tokens".

## Every release after that

1. In a pull request, bump `version` in `puls3_sdk_ts/package.json` and add
   its `CHANGELOG.md` section.
2. After it merges, tag the merge commit and push the tag:

   ```bash
   git tag sdk-ts-v0.1.1 <merge commit>
   git push origin sdk-ts-v0.1.1
   ```

3. Approve the run in the `npm` environment. The workflow checks, tests,
   builds and publishes.
4. Check the version on npmjs.com (it shows the provenance), and install it
   in a project outside the repository: `npm install @puls3_org/sdk`.

A published version cannot be deleted or published again. To withdraw one,
deprecate it (`npm deprecate @puls3_org/sdk@0.1.1 "<why>"`) and release a fix.
