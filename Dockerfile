# WOA Arcane Realm browser build — 3D world is the production entry point.
FROM nginx:1.28-alpine
ENV PORT=8080
COPY deploy/nginx.conf /etc/nginx/default.conf.template
# Serve the new 3D experience at / instead of the retired 2D Phaser page.
COPY web/3d-preview.html /usr/share/nginx/html/index.html
COPY web/data/canonical-story-manifest.json /usr/share/nginx/html/data/canonical-story-manifest.json
# Retain source art folders for future licensed 3D asset integration.
COPY assets/ /usr/share/nginx/html/assets/
COPY web/assets/ /usr/share/nginx/html/assets/
EXPOSE 8080
CMD ["sh", "-c", "envsubst '${PORT}' < /etc/nginx/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
