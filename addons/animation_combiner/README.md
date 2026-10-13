# Animation Combiner - Godot Addon

A Godot 4.5+ editor addon that provides a dockable GUI for combining multiple FBX animations into a single GLTF/GLB file using Blender.

## Features

- **Dockable & Floatable UI**: The panel can be docked anywhere in the Godot editor or used as a floating window
- **Multiple Animations**: Add as many animation FBX files as you need
- **Texture Conflict Detection**: Automatically detects and warns about conflicting textures between files
- **GLTF/GLB Export**: Supports both GLTF and GLB output formats
- **Persistent Settings**: Remembers your file paths and settings between sessions

## Requirements

- Godot 4.5 or higher
- Blender installed on your system (3.0 or higher recommended)
- FBX files with compatible rigs (e.g., Mixamo animations)

## Installation

1. Copy the `addons/animation_combiner` folder to your Godot project's `addons/` directory
2. Copy `main.py` to a location accessible by the addon (by default it looks in the Blender installation directory)
3. Open your project in Godot
4. Go to `Project > Project Settings > Plugins`
5. Enable the "Animation Combiner" plugin

## Usage

### Basic Workflow

1. **Set Blender Path (Optional)**:
   - If Blender is not in your system PATH, click "Browse" next to "Blender Executable"
   - Select your Blender executable (e.g., `/usr/bin/blender`)
   - Leave empty if Blender is accessible via system PATH

2. **Select Base Model**:
   - Click the drop zone to browse for a file
   - This file should contain your character mesh, skeleton, and optionally textures

3. **Add Animations**:
   - Click "Add Animations" to select one or more animation FBX files
   - Each animation will appear in the list
   - Use "Remove" buttons to remove individual animations
   - Use "Clear All" to remove all animations at once

4. **Set Output Path**:
   - Enter the output file path manually, or
   - Click "Browse" to select a save location
   - Use `.gltf` extension for GLTF format or `.glb` for GLB format

5. **Export**:
   - Click "Export Combined GLTF" to start the process
   - The status label will show progress and any warnings
   - Check Godot's console for detailed output

### Texture Conflicts

If the addon detects materials with the same name across different files, it will:
- Display a warning in the status label
- Print detailed conflict information to the console
- Still complete the export (Blender will handle the conflict by renaming)

### Tips

- **Mixamo Workflow**: This addon works great with Mixamo characters and animations
  - Download your character with T-pose or idle animation as the base model
  - Download additional animations separately
  - Make sure all use the same rig structure

- **File Organization**: Keep your FBX files organized in folders:
  ```
  project/
  ├── characters/
  │   └── character_base.fbx
  └── animations/
      ├── idle.fbx
      ├── walk.fbx
      └── run.fbx
  ```

- **Batch Processing**: You can select multiple animation files at once when clicking "Add Animations"

## Python Script Command Line Usage

You can also use the Python script directly from the command line:

```bash
blender --background --python main.py -- \
    --model character.fbx \
    --animations idle.fbx walk.fbx run.fbx \
    --output combined.glb
```

With JSON output for programmatic use:
```bash
blender --background --python main.py -- \
    --model character.fbx \
    --animations idle.fbx walk.fbx \
    --output combined.gltf \
    --json-output
```

## Troubleshooting

### "Blender not found" error
- Make sure Blender is installed
- Set the Blender executable path in the addon settings
- Test Blender from terminal: `blender --version`

### "Animation file not found" error
- Check that all FBX file paths are correct
- The script will automatically try adding `.fbx` extension if missing

### No animations in exported file
- Verify your animation FBX files actually contain animation data
- Check Blender console output for warnings

### Texture conflicts
- Review the console output to see which textures conflict
- Consider renaming materials in your FBX files before import
- Blender will handle conflicts by automatically renaming duplicates

## File Structure

```
addons/animation_combiner/
├── plugin.cfg                      # Plugin metadata
├── animation_combiner_plugin.gd    # Main plugin script
├── animation_combiner_dock.gd      # Dock panel logic
├── animation_combiner_dock.tscn    # UI scene
├── settings.cfg                    # Saved settings (auto-generated)
└── README.md                       # This file
```

## License

This addon is provided as-is. Feel free to modify and distribute as needed.

## Credits

Uses Blender's Python API (bpy) for FBX import and GLTF export.
