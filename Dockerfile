# WOA Arcane Realm is a 2D pixel-art browser RPG.
# Serve the game and its committed runtime assets from the same web root.
FROM nginx:1.28-alpine
ENV PORT=8080
COPY deploy/nginx.conf /etc/nginx/default.conf.template
COPY playtest-2d/index.html /usr/share/nginx/html/index.html
# Isolated Phaser 4 preview route; keep the existing Godot/game entry point at / unchanged.
COPY web/index.html /usr/share/nginx/html/phaser-preview/index.html
COPY web/story-layer.js /usr/share/nginx/html/phaser-preview/story-layer.js
COPY web/story-data.js /usr/share/nginx/html/phaser-preview/story-data.js
COPY web/canonical-story.js /usr/share/nginx/html/phaser-preview/canonical-story.js
COPY assets/ /usr/share/nginx/html/assets/
# Separate UI-only preview; the existing game entry point remains unchanged.
COPY activity-preview/ /usr/share/nginx/html/activity-preview/
EXPOSE 8080
CMD ["sh", "-c", "envsubst '${PORT}' < /etc/nginx/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
