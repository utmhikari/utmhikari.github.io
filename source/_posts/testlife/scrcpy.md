---
title: 【测试人生】安卓游戏投屏/录屏利器——scrcpy
date: 2020/07/18 17:47:16
categories:
- 测试人生
tags:
- scrcpy
- 安卓
- 游戏录屏
- 手机投屏
- UI自动化测试
---

手机投屏/录屏在测试领域的用途有很多，比如：

- 作为（自动化）测试报告的一部分，记录测试的实时场景
- 投屏到电脑，用于UI自动化测试
- 作为日常测试工作使用

当前手机投屏/录屏的解决方案有两个：STF的[minicap](https://github.com/openstf/minicap)以及Genymobile的[scrcpy](https://github.com/Genymobile/scrcpy)。今天则稍微介绍一下scrcpy，能够兼容各类安卓手机，并且在投屏方面，低延迟与高清晰度兼具。

<!-- more -->

scrcpy，又名screen copy，分为[scrcpy-server](https://github.com/Genymobile/scrcpy/tree/master/server)以及scrcpy-client，server调用安卓内部的接口的获取屏幕信息，然后发送给client，client解码屏幕信息，完成录制/投屏等功能。同时，client也可以接收输入、点击、拖拽信息，通过swipe、input等操作传达给手机，或是发送给scrcpy-server让server进行操作。因此对于手机手残党来说，采用scrcpy投屏日常玩手机是一个不错的选择。

scrcpy的client实现因人而异，主要用于解码视频以及解析用户操作。当前也有许多出色的解决方案，比如：

- 默认[client](https://github.com/Genymobile/scrcpy/tree/master/app)，采用[SDL2](https://www.libsdl.org/index.php)制作
- [QtScrcpy](https://github.com/barry-ran/QtScrcpy)，采用[Qt](https://www.qt.io/cn)制作
- [guiscrcpy](https://github.com/srevinsaju/guiscrcpy)，采用[PyQt5](https://pypi.org/project/PyQt5/)制作

其中实现相对比较完善的方案是QtScrcpy，除了投屏、手机操作周边比较完善之外，还提供自定义屏幕按键/拖拽配置。如果有日常使用后者是自动化用例录制的需求，对QtScrcpy进行二次开发是很好的选择。

在原理方面，scrcpy调用了[MediaCodec](https://developer.android.com/reference/android/media/MediaCodec.html)接口。编码器会不断从[Input Surface](https://developer.android.com/reference/android/view/Surface)中获取屏幕数据，然后进行编码通过socket发送到client中。从官方文档也可以获知，[Surface](https://developer.android.com/reference/android/view/Surface)存储了屏幕数据，采用Surface为编码器传递数据会是更加适宜的选择。scrcpy编码屏幕数据的相关代码如下：

```java
private void internalStreamScreen(Device device, FileDescriptor fd) throws IOException {
    MediaFormat format = createFormat(bitRate, maxFps, codecOptions);
    device.setRotationListener(this);
    boolean alive;
    try {
        do {
            MediaCodec codec = createCodec();
            IBinder display = createDisplay();
            ScreenInfo screenInfo = device.getScreenInfo();
            Rect contentRect = screenInfo.getContentRect();
            // include the locked video orientation
            Rect videoRect = screenInfo.getVideoSize().toRect();
            // does not include the locked video orientation
            Rect unlockedVideoRect = screenInfo.getUnlockedVideoSize().toRect();
            int videoRotation = screenInfo.getVideoRotation();
            int layerStack = device.getLayerStack();

            setSize(format, videoRect.width(), videoRect.height());
            configure(codec, format);
            Surface surface = codec.createInputSurface();
            setDisplaySurface(display, surface, videoRotation, contentRect, unlockedVideoRect, layerStack);
            codec.start();
            try {
                alive = encode(codec, fd);
                // do not call stop() on exception, it would trigger an IllegalStateException
                codec.stop();
            } finally {
                destroyDisplay(display);
                codec.release();
                surface.release();
            }
        } while (alive);
    } finally {
        device.setRotationListener(null);
    }
}

private boolean encode(MediaCodec codec, FileDescriptor fd) throws IOException {
    boolean eof = false;
    MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();

    while (!consumeRotationChange() && !eof) {
        int outputBufferId = codec.dequeueOutputBuffer(bufferInfo, -1);
        eof = (bufferInfo.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0;
        try {
            if (consumeRotationChange()) {
                // must restart encoding with new size
                break;
            }
            if (outputBufferId >= 0) {
                ByteBuffer codecBuffer = codec.getOutputBuffer(outputBufferId);

                if (sendFrameMeta) {
                    // 将编码数据+长度写到socket，发给scrcpy的client
                    writeFrameMeta(fd, bufferInfo, codecBuffer.remaining());
                }

                IO.writeFully(fd, codecBuffer);
            }
        } finally {
            if (outputBufferId >= 0) {
                codec.releaseOutputBuffer(outputBufferId, false);
            }
        }
    }

    return !eof;
}
```

如果只需要单纯实现录屏，采用原生scrcpy-client的no display选项就能够实现。如果用程序控制scrcpy的录屏，建议选择mkv格式录制，并通过`adb shell pkill app_process`杀死scrcpy-server来达到终止录屏的效果。否则可能造成视频损坏。

总之，scrcpy有很多用途值得挖掘，尤其在移动/游戏测试领域，scrcpy未来上应有和minicap相提并论的空间。

最近忙碌，难以抽时间深入研究技术，再加上安卓底层/视频技术方面也是第一次接触，便纯当抛砖引玉。有叙述不妥之处，欢迎指正！
