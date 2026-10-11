# Modular Builder 0.2.0

Build modular structures directly in the Godot 4.7 editor. The panel appears at the bottom of the 3D editor. Dimensions are shown in meters; one Godot 3D unit equals one meter.

## Install and try the demo

Open this repository as a Godot project to explore `addons/modular_builder_en/demo/Demo.tscn`. After Godot finishes importing the assets, enable **Modular Builder (English)** in **Project > Project Settings > Plugins**. The demo and its five textures are contained in `addons/modular_builder_en/demo/`.

To use the plugin in an existing project, extract the ZIP at the project root so it creates only `addons/modular_builder_en/`, then enable **Modular Builder (English)** in **Project > Project Settings > Plugins**. Open a 3D scene to use the editor panel. The demo remains inside the addon folder and can be removed if you do not need it.

## Build

Click **Add ModularBuilderPiece** to create a structure container and its first foundation. Green tools choose square or triangular foundations; a green `+` on a free edge attaches another foundation. Red tools place walls and triangular gables between vertices. Yellow tools place square floors using opposite diagonal vertices or triangular floors using three vertices. Wall segments crossing several foundations are split at intermediate foundation vertices so each segment can be textured separately.

Blue markers show connection vertices; selected points turn yellow. Enable **Only show points on selected pieces** to reduce clutter, or **Simplify vertices** to show points at the middle of a piece's thickness. The separate vertex tools merge markers and create, move, or remove manual connection points. Manual vertices belong to their selected piece or detail and do not deform its mesh.

The blue roof and stairs tools create gable, shed, and pyramid roofs and stairs. Gable roofs use two gable peaks or diagonal top corners of opposite walls. Shed roofs use a low point and a diagonally opposite high point; pyramid roofs use two diagonal points at the same height. The Inspector lets you adjust roof width and rise, stair width, and step count. Walls can be placed on other walls or floors. **Center walls** and **Center** for gables align them with supporting walls.

Pink detail tools place windows, doors, hatches, pillars, fences, and parapets. Windows, doors, and hatches can be openings alone or openings with separately editable and textured objects. Pillars connect two vertices; `Alt+click` one vertex to create a vertical pillar from it. The **Center** option aligns a pillar with the supporting piece. Fences have two rails; parapets have one thicker rail. Their height and intermediate post count are editable.

Building pieces start with **Symmetric dimensions** enabled. Turn it off to edit width, height, and depth independently. **Thickness** continues to control the relevant dimension for walls, floors, and foundations. Select a piece in the Scene tree to edit its material and dimensions, or use the rotation button to rotate it by 90 degrees. The active creation tool remains selected until you click it again or choose another tool. `Esc` clears the current points; `Ctrl+Z` undoes placements and vertex edits.

## Collision, modules, and export

Pieces have no collision by default. Select the `ModularBuilderPiece` container and use **Add general collision** to generate or update one concave static collision shape for the structure. Connection markers and internal contact faces are excluded.

Save a selected structure as a reusable `.tscn` module, or insert a saved module into the open scene. For a finished structure, **Export** combines visible meshes into one `MeshInstance3D`, preserving material surfaces and UVs. Choose **New scene** for an independent `.tscn`, or **Copy in this scene** to add a sibling of the editable `ModularBuilderPiece`. The original remains editable.

## Files and license

The English plugin lives in `addons/modular_builder_en/`. Editor code is split into UI, scene actions, detail placement, vertex editing, and viewport interaction. Geometry generation, mesh baking, roof/pillar placement, and vertex simplification have separate scripts.

The original plugin code, icons, and documentation are dedicated to the public domain under [CC0 1.0](LICENSE). The bundled demo textures are example project assets; the CC0 dedication in this repository's license does not automatically cover them. Check their provenance and permission before redistributing the textures separately.

## AI usage disclosure

Generative AI (OpenAI ChatGPT/Codex) assisted with GDScript implementation and revisions, debugging, translation from Portuguese to English, and documentation. Michel Savadim defined the requirements and reviewed and tested the project.
