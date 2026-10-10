# Build the Godot project into a browser-playable WebAssembly/WebGL game.
FROM barichello/godot-ci:4.7.2 AS game-build
WORKDIR /project
RUN apt-get update \
    && apt-get install -y --no-install-recommends libfontconfig1 git git-lfs ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY . .
# Railway's source archive contains Git LFS pointer files, not the model binaries.
# Fetch the real assets from the public repository before Godot imports them.
RUN git lfs install \
    && git clone --depth 1 https://github.com/emilio1229/WOA-Arcane-Realm.git /tmp/woa-lfs \
    && git -C /tmp/woa-lfs lfs pull \
    && cp -a /tmp/woa-lfs/assets/. /project/assets/ \
    && rm -rf /tmp/woa-lfs
RUN set -eu; \
    mkdir -p build; \
    godot --headless --path . --editor --quit; \
    godot --headless --path . --quit-after 5 > /tmp/godot-runtime.log 2>&1 || { cat /tmp/godot-runtime.log; exit 1; }; \
    cat /tmp/godot-runtime.log; \
    if grep -E 'SCRIPT ERROR:|Parse Error:|ERROR:' /tmp/godot-runtime.log; then \
      echo 'Godot runtime smoke test reported engine or script errors.'; \
      exit 1; \
    fi; \
    godot --headless --path . --export-release "Web" build/index.html

# Serve the exported game as a static website. Railway injects PORT at runtime;
# the default keeps local runs and CI smoke tests on port 8080.
FROM nginx:1.28-alpine
ENV PORT=8080
COPY deploy/nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=game-build /project/build/ /usr/share/nginx/html/
EXPOSE 8080
