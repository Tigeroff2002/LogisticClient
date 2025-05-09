FROM ghcr.io/cirruslabs/flutter:3.16.9 AS build

RUN git config --global --add safe.directory '*' && \
    chmod -R 777 /sdks/flutter

WORKDIR /app
COPY . .

RUN flutter pub get && \
    flutter build web --release --web-renderer html --base-href / 

FROM nginx:stable-alpine
COPY --from=build /app/build/web/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]