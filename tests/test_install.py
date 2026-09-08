"""Offline checks: python3 -B -m unittest discover -s tests -v."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SKILL = (ROOT / "skills/iceberg/SKILL.md").read_bytes()
BEGIN = "<!-- iceberg:begin -->"
END = "<!-- iceberg:end -->"
SKILL_DIRS = {
    "agents": ".agents/skills/iceberg",
    "cursor": ".cursor/skills/iceberg",
    "windsurf": ".windsurf/skills/iceberg",
    "copilot": ".github/skills/iceberg",
}


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="iceberg-test-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.project = self.base / "project with spaces"
        self.project.mkdir()
        self.config = self.base / "codex" / "config.toml"
        self.env = dict(os.environ, CODEX_HOME=str(self.config.parent))

    def run_script(self, name, *args, check=True):
        return subprocess.run(
            ["bash", str(ROOT / name), *args], cwd=self.project,
            env=self.env, text=True, capture_output=True, check=check,
        )

    def write(self, relative, text):
        path = self.project / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def test_all_installs_only_one_hook_and_skills_then_uninstalls(self):
        self.run_script("install.sh", "all")
        self.run_script("install.sh", "all")
        self.assertEqual(self.config.read_text().count("[[hooks.UserPromptSubmit]]"), 1)
        for target in ("cursor", "windsurf", "copilot"):
            self.assertEqual((self.project / SKILL_DIRS[target] / "SKILL.md").read_bytes(), SKILL)
        for path in ("AGENTS.md", ".cursor/hooks.json", ".cursor/rules/iceberg.mdc",
                     ".windsurf/rules/iceberg.md", ".github/copilot-instructions.md"):
            self.assertFalse((self.project / path).exists(), path)
        self.run_script("uninstall.sh")
        self.run_script("uninstall.sh")
        self.assertEqual(list(self.project.iterdir()), [])
        self.assertEqual(self.config.read_text().strip(), "")

    def test_static_targets_migrate_blocks_to_skills(self):
        targets = {
            "agents": "AGENTS.md",
            "windsurf": ".windsurf/rules/iceberg.md",
            "copilot": ".github/copilot-instructions.md",
        }
        for target, path in targets.items():
            with self.subTest(target=target):
                legacy = self.write(path, f"user before\n{BEGIN}\nold rules\n{END}\nuser after\n")
                self.run_script("install.sh", target)
                self.run_script("install.sh", target)
                self.assertEqual(legacy.read_text(), "user before\nuser after\n")
                self.assertEqual((self.project / SKILL_DIRS[target] / "SKILL.md").read_bytes(), SKILL)
        self.assertFalse(self.config.exists())
        self.run_script("uninstall.sh")
        for path in targets.values():
            self.assertEqual((self.project / path).read_text(), "user before\nuser after\n")

    def test_codex_migration_removes_duplicate_but_preserves_user_config(self):
        agents = self.write("AGENTS.md", f"project rules\n{BEGIN}\nold rules\n{END}\n")
        self.write(".codex/hooks.json", '{"command": "iceberg/hooks/inject.sh"}')
        self.config.parent.mkdir()
        self.config.write_text('model = "user-model"\n')
        self.run_script("install.sh", "codex")
        self.assertEqual(agents.read_text(), "project rules\n")
        self.assertFalse((self.project / ".codex/hooks.json").exists())
        self.assertTrue(self.config.read_text().startswith('model = "user-model"\n'))
        self.assertFalse((self.project / ".agents/skills").exists())
        self.run_script("uninstall.sh")
        self.assertEqual(self.config.read_text().strip(), 'model = "user-model"')

    def test_cursor_migration_preserves_other_handlers_and_settings(self):
        other = {"command": "/my/other-hook.sh", "timeout": 10}
        hooks = self.write(".cursor/hooks.json", json.dumps({
            "version": 1, "custom": True,
            "hooks": {
                "sessionStart": [{"command": '"/old repo/hooks/cursor-context.sh"'}, other],
                "postToolUse": [{"command": "/old/hooks/cursor-context.sh"}],
                "stop": [other],
            },
        }))
        rule = self.write(".cursor/rules/iceberg.mdc", "---\ndescription: Iceberg - keep replies short\n---\nold rules\n")
        self.run_script("install.sh", "cursor")
        expected = {"version": 1, "custom": True,
                    "hooks": {"sessionStart": [other], "stop": [other]}}
        self.assertEqual(json.loads(hooks.read_text()), expected)
        self.assertFalse(rule.exists())
        self.run_script("uninstall.sh")
        self.assertEqual(json.loads(hooks.read_text()), expected)

    def test_iceberg_only_legacy_files_leave_no_empty_project_files(self):
        for path in ("AGENTS.md", ".windsurf/rules/iceberg.md", ".github/copilot-instructions.md"):
            self.write(path, f"\n{BEGIN}\nold rules\n{END}\n")
        self.write(".cursor/hooks.json", json.dumps({
            "version": 1,
            "hooks": {"sessionStart": [{"command": "/repo/hooks/cursor-context.sh"}]},
        }))
        self.write(".cursor/rules/iceberg.mdc", "description: Iceberg - keep replies short\n")
        self.run_script("install.sh", "all")
        self.assertFalse((self.project / ".cursor/hooks.json").exists())
        self.run_script("uninstall.sh")
        self.assertEqual(list(self.project.iterdir()), [])

    def test_existing_unmanaged_skill_is_preserved(self):
        path = self.write(".cursor/skills/iceberg/SKILL.md", "my custom skill\n")
        legacy = self.write(".cursor/rules/iceberg.mdc", "description: Iceberg - keep replies short\n")
        result = self.run_script("install.sh", "cursor", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(legacy.exists())  # Do not remove old rules if installation fails.
        self.run_script("uninstall.sh")
        self.assertEqual(path.read_text(), "my custom skill\n")

    def test_uninstall_preserves_other_skill_resources(self):
        self.run_script("install.sh", "agents")
        notes = self.write(".agents/skills/iceberg/notes.md", "user notes\n")
        self.run_script("uninstall.sh")
        self.assertEqual(notes.read_text(), "user notes\n")
        self.assertFalse((notes.parent / "SKILL.md").exists())


class HookTests(unittest.TestCase):
    def test_routing_emits_exactly_one_file(self):
        cases = {
            "hello": "short.md",
            "explain this in detail": "short.md",
            "walk me through a report": "short.md",
            "-a": "long.md",
            "why -a please": "long.md",
            "why\n-a\tplease": "long.md",
            'why "-a"': "long.md",
            "why -abc": "short.md",
            "why --all": "short.md",
            "word-a": "short.md",
            "run git commit -a": "long.md",  # Semantic guard lives in long.md.
        }
        for prompt, filename in cases.items():
            with self.subTest(prompt=prompt):
                result = subprocess.run(
                    ["sh", str(ROOT / "hooks/inject.sh")],
                    input=json.dumps({"prompt": prompt, "metadata": "-a"}),
                    text=True, capture_output=True, check=True,
                )
                self.assertEqual(result.stdout, (ROOT / filename).read_text())

    def test_legacy_cursor_hook_is_inert(self):
        result = subprocess.run(
            ["sh", str(ROOT / "hooks/cursor-context.sh")],
            text=True, capture_output=True, check=True,
        )
        self.assertEqual(json.loads(result.stdout), {})


if __name__ == "__main__":
    unittest.main()
