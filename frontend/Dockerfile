# SocialHub frontend (Flutter Web) — production image (Milestone 6.2)
#
# Builds the web bundle with the pinned SDK, then serves the static output
# from nginx. The runtime image contains no Dart toolchain — just the
# compiled assets and a web server.

# ---- builder ----
FROM ghcr.io/cirruslabs/flutter:3.22.3 AS builder
WORKDIR /app

# Resolve packages first, cached against the manifests alone.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# The API the built app talks to is baked in at compile time via
# --dart-define (see core/network/api_client.dart). Passed as a build arg so
# each environment's image points at its own backend; defaults to localhost
# for a build with no arg supplied.
ARG API_BASE_URL=http://localhost:3000
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# ---- runtime ----
FROM nginx:1.27-alpine AS runtime

# Replace the default site with one that serves the SPA correctly.
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80
