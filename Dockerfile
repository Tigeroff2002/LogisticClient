FROM ghcr.io/cirruslabs/flutter:3.16.9 AS build

# Решаем проблемы прав
RUN git config --global --add safe.directory '*' && \
    chmod -R 777 /sdks/flutter

WORKDIR /app
COPY . .

# Сборка с явным указанием базового URL
RUN flutter pub get && \
    flutter build web --release --web-renderer html --base-href / 

FROM nginx:stable-alpine
# Копируем ВСЮ папку build/web
COPY --from=build /app/build/web/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]