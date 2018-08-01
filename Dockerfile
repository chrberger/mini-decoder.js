# Copyright (C) 2018  Christian Berger
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

FROM chrberger/javascript-libcluon-builder:latest
MAINTAINER Christian Berger "christian.berger@gu.se"

# Set the env variable DEBIAN_FRONTEND to noninteractive
ENV DEBIAN_FRONTEND noninteractive

# Install necessary tools.
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends \
        npm \
        wget \
        zip
RUN npm install typescript -g

ADD . /opt/sources
WORKDIR /opt/sources

RUN cd ts && \
    echo "Retrieving es6-promise.d.ts v4.2.4 from https://github.com/stefanpenner/es6-promise." && \
    wget https://raw.githubusercontent.com/stefanpenner/es6-promise/314e4831d5a0a85edcb084444ce089c16afdcbe2/es6-promise.d.ts && \
    echo "Retrieving emscripten.d.ts v1.3.0 from https://github.com/DefinitelyTyped/DefinitelyTyped." && \
    wget https://raw.githubusercontent.com/DefinitelyTyped/DefinitelyTyped/1.3.0/emscripten/emscripten.d.ts

# Use Bash by default from now.
SHELL ["/bin/bash", "-c"]

# Build openh264_decoder.js.
RUN source /opt/emsdk/emsdk_env.sh && \
    cd /opt/sources && \
    cd ts && \
    patch -p1 < ../patches/emscripten.d.ts.patch && \
    cd /opt/sources && \
    cd codecs/openh264 && \
    patch -p1 < ../../patches/openh264-v1.8.0.patch && \
    emmake make libopenh264.a && \
    cd /opt/sources && \
    mkdir build && cd build && \
    tsc --out .openh264_decoder.js ../ts/openh264_decoder.ts && \
    emcc -o /tmp/openh264_decoder.js -O3 --llvm-lto 1 --memory-init-file 0 -s BUILD_AS_WORKER=1 -s TOTAL_MEMORY=67108864 -s NO_FILESYSTEM=1 -s EXPORTED_FUNCTIONS="['_malloc']" -s EXPORTED_RUNTIME_METHODS="['setValue', 'getValue']" -I /opt/sources/codecs/openh264/codec/api/svc -s EXPORTED_FUNCTIONS="['_WelsCreateDecoder','_WelsInitializeDecoder','_WelsDecoderDecodeFrame','_SizeOfSBufferInfo']" --post-js .openh264_decoder.js /opt/sources/codecs/openh264/libopenh264.a ../bindings/openh264.c

# When running a Docker container based on this image, simply copy the results to /opt/output.
CMD cp /tmp/openh264_decoder.js /opt/output/
