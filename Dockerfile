FROM debian:bookworm-slim as build

ENV DEBIAN_FRONTEND="noninteractive"

# Install libraries needed to compile box
RUN dpkg --add-architecture armhf \
 && apt-get update \
 && apt-get install -y --no-install-recommends --no-install-suggests git wget curl cmake python3 build-essential gcc-arm-linux-gnueabihf libc6-dev-armhf-cross libc6:armhf libstdc++6:armhf ca-certificates 

WORKDIR /root

# Build box86
RUN git clone https://github.com/ptitSeb/box86 \
 && mkdir box86/build \
 && cd box86/build \
 && cmake .. -DRPI4ARM64=1 -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo \
 && make -j$(nproc) \
 && make install DESTDIR=/box 

# Build box64
RUN git clone https://github.com/ptitSeb/box64 \
 && mkdir box64/build \
 && cd box64/build \
 && cmake .. -DRPI4ARM64=1 -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo \
 && make -j$(nproc) \
 && make install DESTDIR=/box

FROM debian:bookworm-slim

# Copy compiled box86 and box64 binaries
COPY --from=build /box /

# Install libraries needed to run box
RUN dpkg --add-architecture armhf \
 && apt-get update \
 && apt-get install --yes --no-install-recommends wget curl libc6:armhf libstdc++6:armhf ca-certificates 

# `cabextract` is needed by winetricks to install most libraries
# `xvfb` is needed in wine to spawn display window because some Windows program can't run without it (using `xvfb-run`)
# If you are sure you don't need it, feel free to remove
RUN apt install -y cabextract xvfb

# Clean up
RUN apt-get -y autoremove \
 && apt-get clean autoclean \
 && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists

# Install wine, wine64, and winetricks
COPY install-wine.sh /
RUN bash /install-wine.sh \
 && rm /install-wine.sh

# Install box wrapper for wine
COPY wrap-wine.sh /
RUN bash /wrap-wine.sh \
 && rm /wrap-wine.sh

# Add user and group
RUN groupadd group \
  && useradd -m -g group user \
  && usermod -a -G audio user \
  && usermod -a -G video user \
  && chsh -s /bin/bash user \
  && echo 'User Created'

# Initialise wine
RUN mv /root/wine /home/user/ \
  && su user -c 'wine wineboot' \
  \
  # wintricks
  && su user -c 'winetricks -q msls31' \
  && su user -c 'winetricks -q ole32' \
  && su user -c 'winetricks -q riched20' \
  && su user -c 'winetricks -q riched30' \
  && su user -c 'winetricks -q win7' \
  \
  # Clean
  && rm -fr /home/user/{.cache,tmp}/* \
  && rm -fr /tmp/* \
  && echo 'Wine Initialized'

ENTRYPOINT ["bash", "-c"]
CMD ["bash"]
