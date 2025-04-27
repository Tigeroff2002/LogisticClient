FROM ghcr.io/cirruslabs/flutter:3.16.9 AS buil

RUN git config --global --add safe.directory '*' && \
    chmod -R 777 /sdks/flutter

WORKDIR /app
COPY . .

RUN flutter pub get && \
    flutter build web --release --web-renderer html --base-href / 

FROM nginx:stable-alpin
COPY --from=build /app/build/web/ /usr/share/nginx/html/

EXPOSE 80
EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]