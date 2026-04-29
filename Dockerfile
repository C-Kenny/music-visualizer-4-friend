FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    GSETTINGS_BACKEND=memory \
    SKETCHBOOK_LIBS=/root/sketchbook/libraries \
    PATH=/opt/processing/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates wget unzip bash \
      openjdk-17-jre \
      xvfb x11vnc xauth \
      pulseaudio pulseaudio-utils alsa-utils \
      libgl1-mesa-dri libglu1-mesa libgl1 libegl1 \
      libxrender1 libxtst6 libxi6 libxrandr2 libxcursor1 libxinerama1 libxext6 \
      libfreetype6 libfontconfig1 \
      gsettings-desktop-schemas dbus-x11 \
      procps net-tools \
    && glib-compile-schemas /usr/share/glib-2.0/schemas/ \
    && rm -rf /var/lib/apt/lists/*

# Processing 4.5.2 portable
RUN wget -q https://github.com/processing/processing4/releases/download/processing-1313-4.5.2/processing-4.5.2-linux-x64-portable.zip \
        -O /tmp/p.zip \
    && unzip -q /tmp/p.zip -d /opt \
    && mv /opt/Processing /opt/processing \
    && chmod +x /opt/processing/bin/Processing \
    && ln -sf Processing /opt/processing/bin/processing \
    && rm /tmp/p.zip

WORKDIR /app
COPY Music_Visualizer_CK/libraries /app/Music_Visualizer_CK/libraries
COPY scripts/ci-install-libs.sh /app/scripts/ci-install-libs.sh
RUN bash /app/scripts/ci-install-libs.sh

COPY . /app
RUN chmod +x /app/run.sh /app/docker-entrypoint.sh

EXPOSE 8080 8081 5900
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["run"]
