import ast
import os
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from patch_tagbot import patch_source


class Abort(Exception):
    pass


class GithubException(Exception):
    def __init__(self, message="", status=500):
        super().__init__(message)
        self.status = status
        self.data = {}



class CompatibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = Path(os.environ["TAGBOT_UPSTREAM_SOURCE"]).read_bytes()
        patched = patch_source(cls.source)
        compile(patched, "patched_repo.py", "exec")
        tree = ast.parse(patched)
        repo = next(node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == "Repo")
        method = next(node for node in repo.body if isinstance(node, ast.FunctionDef) and node.name == "create_release")
        module = ast.Module(body=[method], type_ignores=[])
        scope = {"GithubException": GithubException, "Abort": Abort, "logger": Mock()}
        exec(compile(module, "patched_create_release.py", "exec"), scope)
        cls.create_release = staticmethod(scope["create_release"])

    def fake_repo(self, draft=False):
        repo = Mock()
        repo._draft = draft
        repo._changelog_format = "custom"
        repo._changelog = None
        repo._commit_sha_of_release_branch.return_value = "other"
        repo._get_version_tag.return_value = "v0.4.2"
        repo._repo.get_releases.return_value = []
        repo._repo.get_git_ref.return_value.object = SimpleNamespace(type="commit", sha="registered")
        return repo

    def test_existing_lightweight_tag_omits_target(self):
        repo = self.fake_repo()
        self.create_release(repo, "v0.4.2", "registered")
        repo._git.create_tag.assert_called_once_with("v0.4.2", "registered", "")
        self.assertNotIn("target_commitish", repo._repo.create_git_release.call_args.kwargs)
        self.assertEqual(repo._repo.create_git_release.call_args.args, ("v0.4.2", "v0.4.2", ""))

    def test_existing_annotated_tag_is_peeled(self):
        repo = self.fake_repo()
        repo._repo.get_git_ref.return_value.object = SimpleNamespace(type="tag", sha="annotated")
        repo._repo.get_git_tag.return_value.object = SimpleNamespace(type="commit", sha="registered")
        self.create_release(repo, "v0.4.2", "registered")
        repo._repo.get_git_tag.assert_called_once_with("annotated")
        self.assertNotIn("target_commitish", repo._repo.create_git_release.call_args.kwargs)

    def test_mismatched_tag_refuses_release(self):
        repo = self.fake_repo()
        repo._repo.get_git_ref.return_value.object.sha = "wrong"
        with self.assertRaises(Abort):
            self.create_release(repo, "v0.4.2", "registered")
        repo._repo.create_git_release.assert_not_called()

    def test_missing_tag_refuses_release(self):
        repo = self.fake_repo()
        repo._repo.get_git_ref.side_effect = GithubException("missing")
        with self.assertRaises(GithubException):
            self.create_release(repo, "v0.4.2", "registered")
        repo._repo.create_git_release.assert_not_called()

    def test_tag_cycle_is_bounded(self):
        repo = self.fake_repo()
        tag = SimpleNamespace(type="tag", sha="cycle")
        repo._repo.get_git_ref.return_value.object = tag
        repo._repo.get_git_tag.return_value.object = tag
        with self.assertRaises(Abort):
            self.create_release(repo, "v0.4.2", "registered")
        self.assertEqual(repo._repo.get_git_tag.call_count, 16)
        repo._repo.create_git_release.assert_not_called()

    def test_draft_retains_target_and_does_not_touch_tag(self):
        repo = self.fake_repo(draft=True)
        self.create_release(repo, "v0.4.2", "registered")
        repo._git.create_tag.assert_not_called()
        repo._repo.get_git_ref.assert_not_called()
        self.assertEqual(repo._repo.create_git_release.call_args.kwargs["target_commitish"], "registered")

    def test_draft_retains_matching_branch_target(self):
        repo = self.fake_repo(draft=True)
        repo._commit_sha_of_release_branch.return_value = "registered"
        repo._release_branch.return_value = "main"
        self.create_release(repo, "v0.4.2", "registered")
        self.assertEqual(repo._repo.create_git_release.call_args.kwargs["target_commitish"], "main")

    def test_existing_release_is_not_recreated(self):
        repo = self.fake_repo()
        repo._repo.get_releases.return_value = [SimpleNamespace(tag_name="v0.4.2")]
        self.create_release(repo, "v0.4.2", "registered")
        repo._git.create_tag.assert_not_called()
        repo._repo.create_git_release.assert_not_called()

    def test_metadata_is_unchanged(self):
        repo = self.fake_repo()
        repo._changelog = Mock()
        repo._changelog.get.return_value = "upstream release notes"
        self.create_release(repo, "v0.4.2", "registered", is_latest=False)
        args, kwargs = repo._repo.create_git_release.call_args
        self.assertEqual(args[2], "upstream release notes")
        self.assertEqual(kwargs, {"draft": False, "make_latest": "false", "generate_release_notes": False})

    def test_nested_annotated_tag(self):
        repo = self.fake_repo()
        repo._repo.get_git_ref.return_value.object = SimpleNamespace(type="tag", sha="outer")
        repo._repo.get_git_tag.side_effect = [
            SimpleNamespace(object=SimpleNamespace(type="tag", sha="inner")),
            SimpleNamespace(object=SimpleNamespace(type="commit", sha="registered")),
        ]
        self.create_release(repo, "v0.4.2", "registered")
        self.assertEqual(repo._repo.get_git_tag.call_count, 2)
        self.assertNotIn("target_commitish", repo._repo.create_git_release.call_args.kwargs)

    def test_non_commit_tag_refuses_release(self):
        repo = self.fake_repo()
        repo._repo.get_git_ref.return_value.object = SimpleNamespace(type="tree", sha="registered")
        with self.assertRaises(Abort):
            self.create_release(repo, "v0.4.2", "registered")
        repo._repo.create_git_release.assert_not_called()

    def test_github_generated_notes(self):
        repo = self.fake_repo()
        repo._changelog_format = "github"
        self.create_release(repo, "v0.4.2", "registered")
        self.assertTrue(repo._repo.create_git_release.call_args.kwargs["generate_release_notes"])
        self.assertEqual(repo._repo.create_git_release.call_args.args[2], "")

    def test_conventional_notes(self):
        repo = self.fake_repo()
        repo._changelog_format = "conventional"
        repo._repo.get_releases.return_value = [SimpleNamespace(tag_name="v0.4.1")]
        repo._generate_conventional_changelog.return_value = "conventional notes"
        self.create_release(repo, "v0.4.2", "registered")
        repo._generate_conventional_changelog.assert_called_once_with("v0.4.2", "registered", "v0.4.1")
        self.assertEqual(repo._repo.create_git_release.call_args.args[2], "conventional notes")

    def test_api_error_propagates(self):
        repo = self.fake_repo()
        error = GithubException("Release creation still forbidden", status=403)
        repo._repo.create_git_release.side_effect = error
        with self.assertRaises(GithubException) as caught:
            self.create_release(repo, "v0.4.2", "registered")
        self.assertIs(caught.exception, error)

    def test_unexpected_source_fails_closed(self):
        with self.assertRaises(RuntimeError):
            patch_source(self.source + b"\n")
        with self.assertRaises(RuntimeError):
            patch_source(patch_source(self.source))


if __name__ == "__main__":
    unittest.main()
