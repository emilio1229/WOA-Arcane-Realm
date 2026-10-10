# Build the Godot project into a browser-playable WebAssembly/WebGL game.
FROM barichello/godot-ci:4.7.2 AS game-build
WORKDIR /project
RUN apt-get update \
    && apt-get install -y --no-install-recommends libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*
COPY . .
RUN mkdir -p build \
    && godot --headless --path . --editor --quit \
    && godot --headless --path . --export-release "Web" build/index.html

# Serve the exported game as a static website. Railway injects PORT at runtime;
# the default keeps local runs and CI smoke tests on port 8080.
FROM nginx:1.28-alpine
ENV PORT=8080
COPY deploy/nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=game-build /project/build/ /usr/share/nginx/html/
EXPOSE 8080
