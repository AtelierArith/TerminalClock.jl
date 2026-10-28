# Local TagBot compatibility action

This repository maintains a narrow compatibility patch until upstream supports omitting the redundant release target for an existing tag.

The official TagBot 1.25.15 image is pinned by digest. Its normal input defaults, dependencies and command (`python -m tagbot.action`) remain in use. A build-time patch first verifies the exact SHA-256 of the upstream `tagbot/action/repo.py`. It then validates that non-draft tags peel to the registered commit and omits the redundant `target_commitish` only from the subsequent TagBot Release call. Draft behavior and the generated release-note body, draft and latest flags remain unchanged. Omitting the target may change GitHub's displayed branch/compare metadata; the existing tag still selects the registered source commit. Unexpected source, missing tags and mismatched targets fail closed.

This needs no new token or repository permissions. It is nevertheless a custom, locally maintained TagBot patch, not an upstream supported configuration. Upstream upgrades require reviewing and regenerating the source hash and patch; they cannot silently apply.

## Tests and maintenance

The read-only TagBot compatibility CI compiles and exercises the patched upstream method, builds the actual pinned container, imports its patched module, and verifies the inherited command. Integration release behavior is verified separately by running TagBot after merge.

To update upstream, review the upstream changes, image digest, source hash, patch anchors and tests together. Remove this local action once an official version provides equivalent existing-tag behavior. Do not substitute a mutable upstream image.

No package source, version, registry entry, or tag target changes are required. This is not a manual Release API path.

## Upstream references

- https://github.com/JuliaRegistries/TagBot/blob/87cc4cc2b4639f6c743f5772f376a32914060732/tagbot/action/repo.py#L1589-L1666
- https://docs.github.com/en/rest/releases/releases#create-a-release
