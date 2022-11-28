FROM openjdk:11-stretch

#####
# Install development tools
RUN apt-get update && apt-get install -y make build-essential gradle maven curl python3-pip

# Android emulator requires this
RUN apt-get install -y libpulse0 libgl1 libxcomposite1 libxcursor1 libasound2

# Headless chrome requirements
RUN apt-get install -y fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatspi2.0-0 libgtk-3-0 libnspr4 libnss3 libx11-xcb1 libxss1 libxtst6 lsb-release xdg-utils

RUN build_deps="curl" && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ${build_deps} ca-certificates && \
  curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git-lfs && \
  git lfs install && \
  DEBIAN_FRONTEND=noninteractive apt-get purge -y --auto-remove && \
  rm -r /var/lib/apt/lists/*

#####
# Install android SDK
RUN mkdir /data
ENV TERM="dumb" \
  ANDROID_HOME="/android" \
  ANDROID_SDK_ROOT="/android" \
  ANDROID_CMAKE_REV="3.6.4111459"

ENV PATH="${ANDROID_HOME}/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

RUN dpkg --add-architecture i386 && \
  apt-get update && \
  apt-get install -yq libc6:i386 libstdc++6:i386 zlib1g:i386 libncurses5:i386 expect --no-install-recommends

RUN mkdir android && cd android && \
  wget -q "https://dl.google.com/android/repository/commandlinetools-linux-9123335_latest.zip" && \
  unzip commandlinetools-linux-9123335_latest.zip && \
  cd cmdline-tools && mkdir latest && \
  mv NOTICE.txt latest/ && \
  mv source.properties latest/ && \
  mv lib latest/ && \
  mv bin latest/

RUN yes | sdkmanager --licenses

RUN echo yes | sdkmanager "build-tools;33.0.1" && \
  sdkmanager "platforms;android-27" && \
  sdkmanager "platforms;android-28" && \
  sdkmanager "add-ons;addon-google_apis-google-23" && \
  sdkmanager "extras;android;m2repository" && \
  sdkmanager "extras;google;m2repository" && \
  sdkmanager --update && \
  printf "y\ny\ny\ny\ny\n" |sdkmanager --licenses && \
  rm $ANDROID_HOME/commandlinetools-linux-9123335_latest.zip

RUN yes | sdkmanager "system-images;android-25;google_apis;arm64-v8a"
RUN yes | sdkmanager --install 'cmake;'$ANDROID_CMAKE_REV \
  && yes | sdkmanager --install 'ndk;20.0.5594570'

ENV ANDROID_NDK_HOME="${ANDROID_HOME}/ndk/20.0.5594570"

RUN mkdir -pv ${ANDROID_HOME}/ndk-bundle/toolchains/mips64el-linux-android/prebuilt/linux-x86_64

RUN sdkmanager emulator --channel=3

RUN echo no | ${ANDROID_HOME}/cmdline-tools/latest/bin/avdmanager create avd -f --abi google_apis/arm64-v8a -n test -k "system-images;android-25;google_apis;arm64-v8a"

# Generate debug key
RUN keytool -genkey -noprompt -dname "O=alexandrainstituttet" -v -keystore /android/debug.keystore\
  -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000

RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
  apt-get autoremove -y && \
  apt-get clean

#####
# Install nodejs
RUN groupadd --gid 1000 node \
  && useradd --uid 1000 --gid node --shell /bin/bash --create-home node

ENV NODE_VERSION 10.16.3

RUN ARCH="x64" && dpkgArch="$(dpkg --print-architecture)" \
  # gpg keys listed at https://github.com/nodejs/node#release-keys
  && set -ex \
  && for key in \
  94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
  FD3A5288F042B6850C66B31F09FE44734EB7990E \
  71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
  DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
  C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
  B9AE9905FFD7803F25714661B63B535A4C206CA9 \
  77984A986EBC2AA786BC0F66B01FBB92821C587A \
  8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
  4ED778F539E3634C779C87C6D7062848A1AB005C \
  A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
  B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
  gpg --batch --keyserver hkp://keyserver.ubuntu.com --recv-keys "$key" || \
  gpg --batch --keyserver hkp://keys.openpgp.org --recv-keys "$key" || \
  gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs

ENV YARN_VERSION 1.17.3

RUN set -ex \
  && for key in \
  6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
  gpg --batch --keyserver hkp://keyserver.ubuntu.com --recv-keys "$key" || \
  gpg --batch --keyserver hkp://keys.openpgp.org --recv-keys "$key" || \
  gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://github.com/yarnpkg/yarn/releases/download/v$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fsSLO --compressed "https://github.com/yarnpkg/yarn/releases/download/v$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz

#####
# Install angular cli
ENV ANGULAR_CLI_VERSION 8.3.5

RUN npm i -g @angular/cli@${ANGULAR_CLI_VERSION}

#####
# Install cordova
ENV CORDOVA_VERSION 9.0.0

WORKDIR "/tmp"

RUN npm i -g --unsafe-perm cordova@${CORDOVA_VERSION}

RUN npm i -g cordova-paramedic@0.5.0

#####
# Install Ionic
ENV IONIC_VERSION 5.2.3

RUN apt-get update && apt-get install -y git bzip2 openssh-client && \
  npm i -g --unsafe-perm ionic@${IONIC_VERSION} && \
  ionic --no-interactive config set -g daemon.updates false && \
  rm -rf /var/lib/apt/lists/* && apt-get clean

#####
# Hack to make cordova work with new android tools
# https://stackoverflow.com/questions/60819186/cordova-fails-to-find-android-home-environment-variable

RUN mkdir ${ANDROID_HOME}/tools
RUN ln -s ${ANDROID_HOME}/cmdline-tools/latest/bin ${ANDROID_HOME}/tools/bin