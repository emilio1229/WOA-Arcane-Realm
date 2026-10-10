# Uploading large 3D models with Git LFS

This repository is configured to store `.glb`, `.gltf`, `.fbx`, and `.blend` files using Git Large File Storage (LFS). The GitHub website's normal **Add file → Upload files** page cannot upload these large model files directly.

## Windows: easiest route (GitHub Desktop)

1. Install GitHub Desktop: https://desktop.github.com/
2. Open GitHub Desktop and sign in to the GitHub account that can access `emilio1229/WOA-Arcane-Realm`.
3. Choose **File → Clone repository…**, select `emilio1229/WOA-Arcane-Realm`, and clone it to a folder with enough free disk space.
4. Fetch/pull the latest changes so the repository includes the `.gitattributes` file at the project root.
5. Copy your existing `.glb` files into the matching folder under `assets/models/` (for example, `characters`, `environment`, `architecture`, `props`, or `creatures`). Keep your original exports as backups.
6. In GitHub Desktop, review the changed files, enter a summary such as `Add first 3D models`, click **Commit to main**, then click **Push origin**.
7. If Git LFS asks to be installed or initialized, allow it to finish, then retry the push.

## Important limits and notes

- Git LFS is required for the large files; the `.gitattributes` file tells Git which file types to send through LFS.
- GitHub Free currently includes limited LFS storage and monthly download bandwidth. A single 1 GB model uses roughly 1 GB of storage, so upload only the models you need first and check the current quota before sending a large batch.
- Git LFS uploads require a Git client; uploading through the normal GitHub website does not apply LFS tracking automatically.
- Uploading a model stores it in the repository but does not automatically place it into the playable game. The build/deployment pipeline must also retrieve LFS objects before the model can be included in the Godot export.
