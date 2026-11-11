"""Check upgrade behavior in temporary folders with all system commands mocked."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from migrate_legacy import LEGACY_AGENT, LEGACY_SERVICE, LEGACY_SUPPORT, migrate


class MigrationTests(unittest.TestCase):
    def test_upgrade_preserves_settings_and_disables_old_startup(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            old = home / "Library/Application Support" / LEGACY_SUPPORT / "config.json"
            old.parent.mkdir(parents=True)
            old.write_text('{"custom": "settings"}')
            destination = home / "new/config.json"
            destination.parent.mkdir()
            agent = home / "Library/LaunchAgents" / LEGACY_AGENT
            service = home / "LaunchDaemons" / LEGACY_SERVICE
            for path in (agent, service):
                path.parent.mkdir(parents=True)
                path.write_text("old startup entry")
            with patch("migrate_legacy.subprocess.run") as run:
                migrate(home, 501, destination, system_launch_dir=service.parent)
                self.assertEqual(run.call_count, 3)
                self.assertEqual(run.call_args_list[0].args[0][:3], ["/bin/launchctl", "bootout", "system"])
            self.assertEqual(destination.read_text(), old.read_text())
            self.assertTrue(old.exists())
            for path in (agent, service):
                self.assertFalse(path.exists())
                self.assertTrue(path.with_suffix(".plist.disabled").exists())
            destination.write_text("new settings")
            with patch("migrate_legacy.subprocess.run"):
                migrate(home, 501, destination, system_launch_dir=service.parent)
            self.assertEqual(destination.read_text(), "new settings")

    def test_fresh_install_does_not_create_configuration(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            destination = home / "config.json"
            with patch("migrate_legacy.subprocess.run") as run:
                migrate(home, 501, destination, system_launch_dir=home / "daemons")
                self.assertEqual(run.call_count, 1)
            self.assertFalse(destination.exists())


if __name__ == "__main__":
    unittest.main()
