FROM jlesage/baseimage-gui:alpine-3.10

# Define software versions.
ARG JMKVPROPEDIT_VERSION=1.4.3
ARG MKVTOOLNIX_VERSION=44.0.0
ARG MEDIAINFO_VERSION=19.09

# Define software download URLs.
ARG JMKVPROPEDIT_URL=https://github.com/BrunoReX/jmkvpropedit/archive/v${JMKVPROPEDIT_VERSION}.tar.gz
ARG MKVTOOLNIX_URL=https://mkvtoolnix.download/sources/mkvtoolnix-${MKVTOOLNIX_VERSION}.tar.xz
ARG MEDIAINFO_URL=https://github.com/MediaArea/MediaInfo/archive/v${MEDIAINFO_VERSION}.tar.gz

ENV JMKVPROPEDIT_VERSION=${JMKVPROPEDIT_VERSION}

# Define working directory.
WORKDIR /tmp

# Install dependencies.
RUN add-pkg \
        boost-system \
        boost-regex \
        boost-filesystem \
        libmagic \
        libmatroska \
        libebml \
        flac \
        qt5-qtmultimedia \
        mesa-dri-swrast \
        openjdk7-jre \
        # For MediaInfo
        libmediainfo \
        qt5-qtsvg \
        && \
    add-pkg cmark-dev --repository http://dl-cdn.alpinelinux.org/alpine/edge/community


# Compile and install JMkvpropedit.
RUN \
    # Install packages needed by the build.
    add-pkg --virtual build-dependencies \
        apache-ant \
        openjdk8 \
        curl \
        && \
    # Download sources.
    echo "Downloading JMkvpropedit package..." && \
    export JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk && \
    mkdir jmkvpropedit && \
    curl -# -L ${JMKVPROPEDIT_URL} | tar xz --strip 1 -C jmkvpropedit && \
    # Compile.
    cd jmkvpropedit && \
    ant -buildfile build.xml jar && \
    # Install
    mv dist/JMkvpropedit.jar /defaults/JMkvpropedit.jar && \
    cd ../ && \
    # Cleanup.
    del-pkg build-dependencies && \
    rm -rf /tmp/* /tmp/.[!.]*

# Install MKVToolNix.
RUN \
    # Install packages needed by the build.
    add-pkg --virtual build-dependencies \
        curl \
        patch \
        imagemagick \
        build-base \
        ruby-rake \
        ruby-json \
        qt5-qtbase-dev \
        qt5-qtmultimedia-dev \
        boost-dev \
        file-dev \
        zlib-dev \
        libmatroska-dev \
        flac-dev \
        libogg-dev \
        libvorbis-dev \
        docbook-xsl \
        gettext-dev \
        && \

    # Download the MKVToolNix package.
    echo "Downloading MKVToolNix package..." && \
    curl -# -L ${MKVTOOLNIX_URL} | tar xJ && \

    # Remove embedded profile from PNGs to avoid the "known incorrect sRGB
    # profile" warning.
    find mkvtoolnix-${MKVTOOLNIX_VERSION} -name "*.png" -exec convert -strip {} {} \; && \

    # Compile MKVToolNix.
    cd mkvtoolnix-${MKVTOOLNIX_VERSION} && \
    env LIBINTL_LIBS=-lintl ./configure \
        --prefix=/usr \
        --mandir=/tmp/mkvtoolnix-man \
        --disable-update-check \
        && \
    rake -j8 && \
    rake install && \
    strip /usr/bin/mkv* && \
    cd .. && \

    # Cleanup.
    del-pkg build-dependencies && \
    rm -rf /tmp/* /tmp/.[!.]*

# Compile and install MediaInfo.
RUN \
    # Install packages needed by the build.
    add-pkg --virtual build-dependencies \
        build-base \
        curl \
        qt5-qtbase-dev \
        libmediainfo-dev \
        && \
    # Download sources.
    echo "Downloading MediaInfo package..." && \
    mkdir mediainfo && \
    curl -# -L ${MEDIAINFO_URL} | tar xz --strip 1 -C mediainfo && \
    # Compile.
    cd mediainfo/Project/QMake/GUI && \
    /usr/lib/qt5/bin/qmake && \
    make -j$(nproc) install && \
    cd ../../../../ && \
    # Install
    strip -v /usr/bin/mediainfo-gui && \
    cd ../ && \
    # Cleanup.
    del-pkg build-dependencies && \
    rm -rf /tmp/* /tmp/.[!.]*

# Maximize only the main/initial window.
RUN \
    sed-patch 's/<application type="normal">/<application type="normal" title="JMkvpropedit ${JMKVPROPEDIT_VERSION}">/' \
        /etc/xdg/openbox/rc.xml

# Add files.
COPY rootfs/ /

# Set environment variables.
ENV APP_NAME="JMkvpropedit" \
    S6_KILL_GRACETIME=8000

# Define mountable directories.
VOLUME ["/config"]
VOLUME ["/storage"]

# Metadata.
LABEL \
      org.label-schema.name="jmkvpropedit" \
      org.label-schema.description="Docker container for JMkvpropedit" \
      org.label-schema.version="$DOCKER_IMAGE_VERSION" \
      org.label-schema.vcs-url="https://github.com/jlesage/docker-jmkvpropedit" \
      org.label-schema.schema-version="1.0"