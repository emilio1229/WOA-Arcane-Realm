# WOA Arcane Realm is now a 2D pixel-art browser RPG.
# Do not build or launch the legacy Godot/3D project for the deployed game.
FROM nginx:1.28-alpine
ENV PORT=8080
COPY deploy/nginx.conf /etc/nginx/default.conf.template
COPY playtest-2d/index.html /usr/share/nginx/html/index.html
EXPOSE 8080
CMD ["sh", "-c", "envsubst '${PORT}' < /etc/nginx/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
