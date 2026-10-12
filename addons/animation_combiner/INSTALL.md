# Quick Installation Guide

## Step 1: Copy Files to Your Godot Project

Copy the entire `addons/animation_combiner` folder to your Godot project:

```
YourGodotProject/
├── addons/
│   └── animation_combiner/    <-- Copy this entire folder here
│       ├── plugin.cfg
│       ├── animation_combiner_plugin.gd
│       ├── animation_combiner_dock.gd
│       ├── animation_combiner_dock.tscn
│       └── README.md
└── ...other project files
```

Also copy `main.py` to a convenient location (it will be referenced by the addon).

## Step 2: Enable the Plugin in Godot

1. Open your Godot project
2. Go to: **Project → Project Settings → Plugins**
3. Find "Animation Combiner" in the list
4. Check the "Enable" checkbox

## Step 3: Configure Blender Path

The addon panel will appear in the top-right dock area. If Blender is not in your system PATH:

1. Click "Browse" next to "Blender Executable"
2. Navigate to your Blender installation
3. Select the Blender executable:
   - **Linux**: Usually `/usr/bin/blender` or `/snap/bin/blender`
   - **Windows**: Usually `C:\Program Files\Blender Foundation\Blender 3.x\blender.exe`
   - **macOS**: Usually `/Applications/Blender.app/Contents/MacOS/Blender`

## Step 4: Update Script Path (if needed)

By default, the addon looks for `main.py` two directories up from the addon folder. If you placed it elsewhere:

1. Open `animation_combiner_dock.gd` in Godot
2. Find the `_get_script_path()` function (near the end)
3. Update the path to point to your `main.py` location

Example:
```gdscript
func _get_script_path() -> String:
    return "/path/to/your/main.py"  # Absolute path
    # or
    return ProjectSettings.globalize_path("res://scripts/main.py")  # Relative to project
```

## Step 5: Test the Setup

1. Place a test FBX file (character model) somewhere accessible
2. Click "Browse" next to "Base Model" and select the file
3. Add at least one animation FBX file
4. Set an output path (e.g., `res://exports/test.glb`)
5. Click "Export Combined GLTF"
6. Check the Godot console for output

## Common Setup Issues

### Plugin doesn't appear in the Plugins list
- Make sure the folder structure is correct: `addons/animation_combiner/plugin.cfg`
- Restart Godot if you just copied the files

### "Scene file not found" error when enabling plugin
- Check that `animation_combiner_dock.tscn` exists in the addon folder
- The path in `animation_combiner_plugin.gd` should be: `res://addons/animation_combiner/animation_combiner_dock.tscn`

### Panel appears but is blank
- Check the Godot console for errors
- Make sure all `.gd` and `.tscn` files are present

### "Script does not inherit from EditorPlugin" error
- Make sure `@tool` is at the top of `animation_combiner_plugin.gd`
- The script must extend `EditorPlugin`

## You're Ready!

Once setup is complete, you can start combining animations. See the main README.md for usage instructions.
