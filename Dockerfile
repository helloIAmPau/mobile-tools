# syntax=docker/dockerfile:1
# Android tooling requires glibc; backend images retain Alpine.
FROM node:24.21.0-bookworm AS tooling
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk-headless curl unzip libgl1 libpulse0 libnss3 libnspr4 libasound2 \
    libx11-6 libxcomposite1 libxcursor1 libxdamage1 libxi6 libxtst6 libxrandr2 \
    libxkbcommon0 libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*
ENV ANDROID_HOME=/opt/android \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    PATH=/opt/android/cmdline-tools/latest/bin:/opt/android/platform-tools:/opt/android/emulator:/opt/maestro/bin:$PATH
RUN curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip -o /tmp/android.zip \
    && echo '4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583  /tmp/android.zip' | sha256sum -c - \
    && mkdir -p /opt/android/cmdline-tools \
    && unzip -q /tmp/android.zip -d /opt/android/cmdline-tools \
    && mv /opt/android/cmdline-tools/cmdline-tools /opt/android/cmdline-tools/latest \
    && rm /tmp/android.zip \
    && yes | sdkmanager --licenses >/dev/null
RUN sdkmanager 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' \
    'ndk;27.1.12297006' 'cmake;3.22.1' 'emulator' 'system-images;android-36;google_apis;x86_64'
# Transitive Android libraries also compile against build-tools 35.
RUN sdkmanager 'build-tools;35.0.0'
RUN curl -fsSL https://github.com/mobile-dev-inc/Maestro/releases/download/cli-2.11.0/maestro.zip -o /tmp/maestro.zip \
    && unzip -q /tmp/maestro.zip -d /opt \
    && rm /tmp/maestro.zip
LABEL org.opencontainers.image.source="https://github.com/helloIAmPau/mobile-tools" \
    org.opencontainers.image.description="Node, Java, Android SDK/emulator and Maestro for native Android development"
ENV HOME=/state/home \
    GRADLE_USER_HOME=/state/gradle \
    ANDROID_AVD_HOME=/state/avd \
    ANDROID_SERIAL=emulator-5554 \
    MAESTRO_CLI_NO_ANALYTICS=1 \
    MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true
WORKDIR /source
COPY --chmod=755 develop.sh /usr/local/bin/mobile-develop
CMD ["mobile-develop"]

FROM tooling AS test
COPY tests/ /tests/
CMD ["bash", "/tests/e2e/android.sh"]

FROM tooling AS runtime
