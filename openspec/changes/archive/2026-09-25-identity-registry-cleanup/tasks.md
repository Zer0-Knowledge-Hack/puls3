# Tasks: identity-registry-cleanup

- [x] Trim header to one short line
- [x] Trim DataKey variant docs to bare variants
- [x] Trim redundant fn docs, keep auth/error/event/TTL
- [x] Harden root `.gitignore` (secrets/env/keys/logs)
- [x] Harden `contracts/.gitignore` (env/identities)
- [x] Verify `stellar contract build`
- [x] Verify `cargo test -p identity-registry`
- [x] Verify `cargo clippy --all-targets -- -D warnings`
- [x] Verify `cargo fmt --all -- --check`
