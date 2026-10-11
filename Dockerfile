# Build the Godot project into a browser-playable WebAssembly/WebGL game.
# The world and story props are generated in main.gd. Imported GLB files were
# optional visual overrides, but the repository only contained Git LFS pointer
# stubs; omit that asset dependency so a clean Railway checkout can build.
FROM barichello/godot-ci:4.7.2 AS game-build
WORKDIR /project
RUN apt-get update \
    && apt-get install -y --no-install-recommends libfontconfig1 ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY . .

# GitHub LFS pointers are plain-text placeholders, not importable 3D models.
# Remove only unresolved pointer stubs; keep real model files if the LFS payloads
# are available in a local or properly configured checkout.
RUN find . -type f \\( -name '*.fbx' -o -name '*.glb' -o -name '*.gltf' -o -name '*.blend' \\) -exec sh -c 'for f do if head -c 64 "$f" | grep -q "version https://git-lfs.github.com/spec/v1"; then echo "Removing unresolved Git LFS pointer: $f"; rm -f "$f"; fi; done' sh {} +

RUN mkdir -p build
RUN set +e; godot --headless --path . --editor --quit > /tmp/godot-import.log 2>&1; result=$?; cat /tmp/godot-import.log; if [ "$result" -ne 0 ]; then echo "GODOT_IMPORT_FAILED exit=$result"; exit "$result"; fi
RUN if grep -E 'SCRIPT ERROR:|Parse Error:|ERROR:' /tmp/godot-import.log; then echo 'Godot asset import reported engine or asset errors.'; exit 1; fi
RUN set +e; godot --headless --path . --quit-after 5 > /tmp/godot-runtime.log 2>&1; result=$?; cat /tmp/godot-runtime.log; if [ "$result" -ne 0 ]; then echo "GODOT_RUNTIME_FAILED exit=$result"; exit "$result"; fi
RUN if grep -E 'SCRIPT ERROR:|Parse Error:|ERROR:' /tmp/godot-runtime.log; then echo 'Godot runtime smoke test reported engine or script errors.'; exit 1; fi
RUN godot --headless --path . --export-release "Web" build/index.html

# Serve the exported game as a static website. Railway injects PORT at runtime.
FROM nginx:1.28-alpine
ENV PORT=8080
COPY deploy/nginx.conf /etc/nginx/default.conf.template
COPY --from=game-build /project/build/ /usr/share/nginx/html/
EXPOSE 8080
CMD ["sh", "-c", "envsubst '${PORT}' < /etc/nginx/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
