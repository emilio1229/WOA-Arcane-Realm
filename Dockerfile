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

# Git LFS pointers are small text stubs, not usable assets. Remove any unresolved
# pointer file (including textures) before import so Godot doesn't try to decode it.
RUN find . -type f -not -path './.git/*' -exec sh -c 'for f do if head -c 64 "$f" | grep -q "version https://git-lfs.github.com/spec/v1"; then echo "Removing unresolved Git LFS pointer: $f"; rm -f "$f"; fi; done' sh {} +

# Some exported OBJ material libraries still point at the six shared trim textures
# even when those texture files were Git LFS placeholders and have been removed.
# Strip only those missing texture-map directives so the OBJ materials remain usable
# with their authored diffuse colors instead of failing resource loading at startup.
RUN find . -type f -name '*.mtl' -exec sed -i -E '/^[[:space:]]*map_(Kd|Bump|Ka|Ks)[[:space:]]+T_Trim_(Metal|Furniture|Cloth)_(BaseColor|Normal)\.png[[:space:]]*$/d' {} +

RUN mkdir -p build
# Verify the addon texture source files are present before Godot starts importing resources.
RUN test -s addons/simplegrasstextured/images/motion.png \
    && test -s addons/simplegrasstextured/images/wind_pattern.png \
    && test -s addons/real-controller/HumanAnimations_ColorPalette.png
# Editor plugins are authoring tools and are not needed to import/export the playable game.
# Some bundled addons initialize editor-only UI during headless imports and emit script errors
# (for example empty toolbar-button arrays or missing editor color conversions). Disable only
# their editor-plugin registration for this container build; runtime autoloads and game assets remain intact.
RUN sed -i '/^\[editor_plugins\]/,/^\[/ { /^enabled=/s/.*/enabled=PackedStringArray()/; }' project.godot
RUN set +e; godot --headless --path . --editor --import --quit > /tmp/godot-import.log 2>&1; result=$?; cat /tmp/godot-import.log; if [ "$result" -ne 0 ]; then echo "GODOT_IMPORT_FAILED exit=$result"; exit "$result"; fi
RUN if grep -E 'SCRIPT ERROR:|Parse Error:' /tmp/godot-import.log; then echo 'Godot asset import reported a script parse/runtime error.'; exit 1; fi
RUN set +e; godot --headless --path . --quit-after 5 > /tmp/godot-runtime.log 2>&1; result=$?; cat /tmp/godot-runtime.log; if [ "$result" -ne 0 ]; then echo "GODOT_RUNTIME_FAILED exit=$result"; exit "$result"; fi
RUN if grep -E 'SCRIPT ERROR:|Parse Error:' /tmp/godot-runtime.log; then echo 'Godot runtime smoke test reported a script parse/runtime error.'; exit 1; fi
RUN godot --headless --path . --export-release "Web" build/index.html

# Serve the exported game as a static website. Railway injects PORT at runtime.
FROM nginx:1.28-alpine
ENV PORT=8080
COPY deploy/nginx.conf /etc/nginx/default.conf.template
COPY --from=game-build /project/build/ /usr/share/nginx/html/
EXPOSE 8080
CMD ["sh", "-c", "envsubst '${PORT}' < /etc/nginx/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
