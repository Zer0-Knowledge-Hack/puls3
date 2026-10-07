# Build from the project root with:
# docker build -f puls3_server/Dockerfile .

# Build stage
FROM dart:3.12.2 AS build

# Create a minimal workspace that preserves locked server dependency versions.
WORKDIR /app
COPY pubspec.lock .
COPY puls3_domain puls3_domain
COPY puls3_server puls3_server
RUN printf '%s\n' \
  'name: _' \
  'environment:' \
  '  sdk: ^3.12.2' \
  'workspace:' \
  '  - puls3_domain' \
  '  - puls3_server' \
  > pubspec.yaml
RUN dart pub get

# Build the server bundle. Serverpod 4 dependencies use Dart build hooks, so
# `dart compile exe` cannot produce a complete runtime artifact anymore.
WORKDIR /app/puls3_server
RUN dart build cli --target bin/main.dart --output build/server

# Add a fallback for the copy of possibly missing directories.
RUN mkdir -p config web migrations

# Final stage
FROM alpine:latest
WORKDIR /app

# Environment variables
ENV runmode=production
ENV serverid=default
ENV logging=normal
ENV role=monolith

# Copy runtime dependencies
COPY --from=build /runtime/ /

# Copy the executable and native libraries emitted by Dart build hooks.
COPY --from=build /app/puls3_server/build/server/bundle/ server/

# Copy configuration files and resources
COPY --from=build /app/puls3_server/config/ config/
COPY --from=build /app/puls3_server/web/ web/
COPY --from=build /app/puls3_server/migrations/ migrations/

# This file is required to enable the endpoint log filter in Insights.
COPY --from=build /app/puls3_server/lib/src/generated/protocol.yaml lib/src/generated/protocol.yaml

# Expose ports
EXPOSE 8080
EXPOSE 8081
EXPOSE 8082

# Define the entrypoint command
ENTRYPOINT ./server/bin/main --mode=$runmode --server-id=$serverid --logging=$logging --role=$role
