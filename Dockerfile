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
        unzip \
        zip
RUN npm install typescript -g

ADD . /opt/sources
WORKDIR /opt/sources

RUN cd ts && \
    wget https://raw.githubusercontent.com/chrberger/es6-promise/314e4831d5a0a85edcb084444ce089c16afdcbe2/es6-promise.d.ts && \
    wget https://raw.githubusercontent.com/chrberger/depericated-DefinitelyTyped/1.3.0/emscripten/emscripten.d.ts && \
    cd /opt && \
    wget https://dl.google.com/closure-compiler/compiler-20200719.zip && \
    unzip compiler-20200719.zip


# Use Bash by default from now.
SHELL ["/bin/bash", "-c"]

# Patch ts/emscripten.d.ts
RUN cd ts && \
    patch -p1 < ../patches/emscripten.d.ts.patch

# Build openh264_decoder.js.
RUN source /opt/emsdk/emsdk_env.sh && \
    cd /opt/sources && \
    cd codecs/openh264 && \
    patch -p1 < ../../patches/openh264-v1.8.0.patch && \
    emmake make libopenh264.a && \
    cd /opt/sources && \
    mkdir -p build && cd build && \
    tsc --out .openh264_decoder.js ../ts/openh264_decoder.ts && \
    emcc -o /tmp/openh264_decoder.js \
         -O3 --llvm-lto 1 --memory-init-file 0 \
         -s BUILD_AS_WORKER=1 -s TOTAL_MEMORY=67108864 \
         -s NO_FILESYSTEM=1 \
         -s EXPORTED_FUNCTIONS="['_malloc']" \
         -s EXPORTED_RUNTIME_METHODS="['setValue', 'getValue']" \
         -I /opt/sources/codecs/openh264/codec/api/svc \
         -s EXPORTED_FUNCTIONS="['_WelsCreateDecoder','_WelsInitializeDecoder','_WelsDecoderDecodeFrame','_SizeOfSBufferInfo']" \
         --post-js .openh264_decoder.js \
         /opt/sources/codecs/openh264/libopenh264.a ../bindings/openh264.c && \
    java -jar /opt/closure-compiler-v*.jar --js /tmp/openh264_decoder.js --js_output_file /tmp/openh264_decoder.js.2 && \
    mv /tmp/openh264_decoder.js.2 /tmp/openh264_decoder.js

# Build vpx_decoder.js.
RUN source /opt/emsdk/emsdk_env.sh && \
    cd /opt/sources && \
    cd codecs/libvpx && \
    patch -p1 < ../../patches/libvpx-992d9a0.patch && \
    emconfigure ./configure \
                --disable-multithread \
                --target=generic-gnu \
                --disable-docs \
                --disable-examples && \
    emmake make libvpx_g.a && \
    cd /opt/sources && \
    mkdir -p build && cd build && \
    tsc --out .libvpx_decoder.js ../ts/libvpx_decoder.ts && \
    emcc -o /tmp/libvpx_decoder.js \
         -O3 --llvm-lto 1 --memory-init-file 0 \
         -s BUILD_AS_WORKER=1 -s TOTAL_MEMORY=67108864 \
         -s NO_FILESYSTEM=1 \
         -s EXPORTED_FUNCTIONS="['_malloc']" \
         -s EXPORTED_RUNTIME_METHODS="['setValue', 'getValue']" \
         -I /opt/sources/codecs/libvpx/vpx \
         -s EXPORTED_FUNCTIONS="['_vpx_codec_vp8_dx','_vpx_codec_vp9_dx','_vpx_codec_dec_init2','_allocate_vpx_codec_ctx','_vpx_codec_dec_init_ver','_vpx_codec_decode','_vpx_codec_get_frame']" \
         --post-js .libvpx_decoder.js \
         /opt/sources/codecs/libvpx/libvpx_g.a ../bindings/libvpx.c && \
    java -jar /opt/closure-compiler-v*.jar --js /tmp/libvpx_decoder.js --js_output_file /tmp/libvpx_decoder.js.2 && \
    mv /tmp/libvpx_decoder.js.2 /tmp/libvpx_decoder.js

# When running a Docker container based on this image, simply copy the results to /opt/output.
CMD cp /tmp/openh264_decoder.js /tmp/libvpx_decoder.js /opt/output/

