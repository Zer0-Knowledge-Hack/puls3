# Toolchain image for the browser E2E of the hire flow (#256, #290).
#
# It runs scripts/e2e-flutter-local.sh on Linux against the sandbox services
# of puls3_server/docker-compose.yaml. The repository is mounted at /repo at
# run time; the image holds tools only, never a key or a password. Every
# download is pinned to an exact version and checked against its SHA-256.
#
# Build and run it with scripts/e2e-flutter-docker.sh.

# debian:bookworm-slim, pinned by digest.
FROM debian@sha256:734a72b3d6142a71993b4bc580ca01d8ca687f77a2c422d96a961d3376b179bc

# Flutter 3.44.4 bundles Dart 3.12.2, the versions CI uses (README, "Build and run").
ARG FLUTTER_VERSION=3.44.4
ARG FLUTTER_SHA256=c853cda0312a162854c481fe6a1bc286d84fbb74bfab7037c39750061dc9b466
# The local seed shells out to the Stellar CLI (`stellar keys`, `contract invoke`).
ARG STELLAR_CLI_VERSION=28.1.0
ARG STELLAR_CLI_SHA256=c1680deee94301d33ada7a17f98411e642a4248c727afbd2e43050d345746462
# Chrome for Testing and the chromedriver of the same build.
ARG CHROME_VERSION=157.0.8103.78
ARG CHROME_SHA256=9223832977a13db3646201b1341c1f9cf08afa3ceae92540116d7b0c062364fb
ARG CHROMEDRIVER_SHA256=0c27ff9aac902d3f7d2d01dde2235c1ff9c320bb8914b3624f4c79d52abacaea

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    PUB_CACHE=/root/.pub-cache \
    FLUTTER_ROOT=/opt/flutter \
    PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/root/.pub-cache/bin:$PATH

# Tools of the run script (bash, curl, psql), Flutter's (git, unzip, xz), the
# Stellar CLI's shared libraries and Chrome's runtime libraries and fonts.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git unzip xz-utils zip procps \
      postgresql-client \
      libdbus-1-3 libudev1 \
      libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
      libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libxfixes3 libxext6 \
      libx11-6 libx11-xcb1 libxcb1 libgbm1 libpango-1.0-0 libcairo2 \
      libasound2 libxshmfence1 libgtk-3-0 libvulkan1 libexpat1 \
      fonts-liberation fonts-noto-color-emoji \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum -c - \
 && tar -xJf /tmp/flutter.tar.xz -C /opt \
 && rm /tmp/flutter.tar.xz \
 && git config --global --add safe.directory /opt/flutter \
 && flutter config --no-analytics --no-cli-animations \
 && dart --disable-analytics \
 && flutter precache --web --no-android --no-ios \
 && flutter --version

RUN curl -fsSL -o /tmp/stellar.tar.gz \
      "https://github.com/stellar/stellar-cli/releases/download/v${STELLAR_CLI_VERSION}/stellar-cli-${STELLAR_CLI_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
 && echo "${STELLAR_CLI_SHA256}  /tmp/stellar.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/stellar.tar.gz -C /usr/local/bin stellar \
 && rm /tmp/stellar.tar.gz \
 && stellar --version

RUN base="https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64" \
 && curl -fsSL -o /tmp/chrome.zip "$base/chrome-linux64.zip" \
 && curl -fsSL -o /tmp/chromedriver.zip "$base/chromedriver-linux64.zip" \
 && echo "${CHROME_SHA256}  /tmp/chrome.zip" | sha256sum -c - \
 && echo "${CHROMEDRIVER_SHA256}  /tmp/chromedriver.zip" | sha256sum -c - \
 && unzip -q /tmp/chrome.zip -d /opt \
 && unzip -q /tmp/chromedriver.zip -d /opt \
 && rm /tmp/chrome.zip /tmp/chromedriver.zip \
 && ln -s /opt/chrome-linux64/chrome /usr/bin/google-chrome \
 && ln -s /opt/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver \
 && google-chrome --version \
 && chromedriver --version

ENV CHROME_EXECUTABLE=/usr/bin/google-chrome \
    CHROMEDRIVER=/usr/local/bin/chromedriver

# A checkout on Windows can turn LF into CRLF; strip it so bash runs the file.
COPY entrypoint.sh /usr/local/bin/e2e-entrypoint
RUN sed -i 's/\r$//' /usr/local/bin/e2e-entrypoint \
 && chmod 0755 /usr/local/bin/e2e-entrypoint

WORKDIR /repo
ENTRYPOINT ["/usr/local/bin/e2e-entrypoint"]
