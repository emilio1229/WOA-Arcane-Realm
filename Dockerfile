# WOA Arcane Realm is a 2D pixel-art browser RPG.
# Serve the game and its committed runtime assets from the same web root.
FROM nginx:1.28-alpine
ENV PORT=8080
COPY deploy/nginx.conf /etc/nginx/default.conf.template
COPY web/index.html /usr/share/nginx/html/index.html
# Phaser browser RPG is the main game entry point. Keep legacy Godot and old prototypes out of the served root.
COPY web/story-layer.js /usr/share/nginx/html/story-layer.js
COPY web/story-data.js /usr/share/nginx/html/story-data.js
COPY web/canonical-story.js /usr/share/nginx/html/canonical-story.js
COPY web/player-systems.js /usr/share/nginx/html/player-systems.js
COPY web/world-systems.js /usr/share/nginx/html/world-systems.js
COPY web/controls.js /usr/share/nginx/html/controls.js
COPY assets/ /usr/share/nginx/html/assets/
# Separate UI-only preview; the existing game entry point remains unchanged.
COPY activity-preview/ /usr/share/nginx/html/activity-preview/
EXPOSE 8080
CMD ["sh", "-c", "envsubst '${PORT}' < /etc/nginx/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
