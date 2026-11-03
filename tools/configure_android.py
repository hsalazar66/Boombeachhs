"""Configure Godot's local editor paths, never committing a keystore."""
import json
import os
from pathlib import Path

config = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
settings_dir = config / "godot"
settings_dir.mkdir(parents=True, exist_ok=True)
java = os.environ["JAVA_HOME"]
sdk = os.environ["ANDROID_HOME"]
keystore = os.environ["ANDROID_DEBUG_KEYSTORE"]
# This file is generated on the runner before the first editor invocation.
settings = settings_dir / "editor_settings-4.6.tres"
settings.write_text(
    '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    f'export/android/java_sdk_path = {json.dumps(java)}\n'
    f'export/android/android_sdk_path = {json.dumps(sdk)}\n'
    f'export/android/debug_keystore = {json.dumps(keystore)}\n'
    'export/android/debug_keystore_user = "androiddebugkey"\n'
    'export/android/debug_keystore_pass = "android"\n'
)
print("Godot Android SDK paths configured.")
