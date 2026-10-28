"""Fail-closed compatibility patch for the pinned upstream TagBot 1.25.15."""
import hashlib
import importlib.util
from pathlib import Path

UPSTREAM_SHA256 = "6f0a7552b1b27610e43a51c5f05b43bc18382f17926a28144f9c4d0c4bcb42fe"
TAG_LINE = "            self._git.create_tag(version_tag, sha, log)\n"
CHECKED_TAG = TAG_LINE + '''            # An existing tag, not the default branch, must select the release.
            # Fail closed if a stale/moved tag differs from the registry commit.
            tag_object = self._repo.get_git_ref(f"tags/{version_tag}").object
            for _ in range(16):
                if tag_object.type != "tag":
                    break
                tag_object = self._repo.get_git_tag(tag_object.sha).object
            if tag_object.type != "commit" or tag_object.sha != sha:
                raise Abort("Release tag does not match the registered commit")
'''
TARGET_LINE = "                target_commitish=target,\n"
SAFE_TARGET = "                **({\"target_commitish\": target} if self._draft else {}),\n"

# Recovery is deliberately scoped to the release requested by the maintainer.
# Other historical tags retain upstream skip behavior.
SKIP_LINE = "            if version_tag in tags_cache:\n"
RECOVER_RELEASE = """            if version_tag in tags_cache and (
                version_tag != "v0.4.2"
                or any(r.tag_name == version_tag for r in self._repo.get_releases())
            ):
"""


def patch_source(source: bytes) -> bytes:
    if hashlib.sha256(source).hexdigest() != UPSTREAM_SHA256:
        raise RuntimeError("Unexpected TagBot source; refusing compatibility patch")
    text = source.decode("utf-8")
    if any(text.count(anchor) != 1 for anchor in (TAG_LINE, TARGET_LINE, SKIP_LINE)):
        raise RuntimeError("Unexpected TagBot structure; refusing compatibility patch")
    return (text.replace(TAG_LINE, CHECKED_TAG)
            .replace(TARGET_LINE, SAFE_TARGET)
            .replace(SKIP_LINE, RECOVER_RELEASE).encode("utf-8"))


def main():
    spec = importlib.util.find_spec("tagbot.action.repo")
    if spec is None or spec.origin is None:
        raise RuntimeError("Pinned TagBot module is not installed")
    path = Path(spec.origin)
    patched = patch_source(path.read_bytes())
    compile(patched, str(path), "exec")
    path.write_bytes(patched)
    print("Applied existing-tag compatibility patch to pinned TagBot 1.25.15")


if __name__ == "__main__":
    main()
