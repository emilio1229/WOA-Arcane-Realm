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

# Serve the exported game as a static website.
FROM nginx:1.28-alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=game-build /project/build/ /usr/share/nginx/html/
EXPOSE 8080
