FROM ubuntu:26.04

RUN apt-get update && apt-get install -y bash ca-certificates curl git unzip xz-utils zip libglu1-mesa && rm -rf /var/lib/apt/lists/*

# Node.js と Firebase CLI
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g firebase-tools

# Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:/root/.pub-cache/bin:${PATH}"
RUN flutter config --enable-web

# FlutterFire CLI
RUN dart pub global activate flutterfire_cli