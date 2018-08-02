## mini-decoder.js

Simple raw video frame decoder for JavaScript using openh264 and libvpx libraries.

This work is based on [https://github.com/kazuki/video-codec.js](https://github.com/kazuki/video-codec.js).

### Build

We use Docker to build:
```bash
docker build -f Dockerfile -t builder .
```

Get the build artefacts:
```bash
docker run --rm -ti --init -v $PWD:/opt/output builder
```

The Docker container will copy `openh264_decoder.js`, and `libvpx_decoder.js` into your current working directory.

### Install

Simply copy `mini-decoder.js`, `openh264_decoder.js`, and `libvpx_decoder.js`
into your project. Then, you can feed raw frames into it using

```javascript
decodeAndRenderH264('videoFrame' /*your canvas*/,
                    640 /*frame's width*/,
                    640 /*frame's height*/,
                    rawData /*frame's rawData*/));

```

```javascript
decodeAndRenderVPX('videoFrame' /*your canvas*/,
                   640 /*frame's width*/,
                   640 /*frame's height*/,
                   rawData /*frame's rawData*/),
                   'VP80' /*if rawData is encoded using VP8, otherwise 'VP90'*/);

```

