FROM nginx:1.23.3
COPY nginx.conf /etc/nginx/nginx.conf
RUN rm /etc/nginx/conf.d/default.conf
# Uncomment to run in debug mode
# CMD ["nginx-debug", "-g", "daemon off;"]
