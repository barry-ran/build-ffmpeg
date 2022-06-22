# build-ffmpeg
minimum set build ffmpeg use actions on mac&linux&windows for [QtScrcpyCore](https://github.com/barry-ran/QtScrcpyCore)(enable h264 decoder, mp4 format, file protocol)

you can custom build params on build.sh

# check ffmpeg codes
```
# list all codecs
ffmpeg -codecs
# list all encoders
ffmpeg -encoders
# view more details on an encoder
ffmpeg -h encoder=libx264
# list all decoders
ffmpeg -decoders
# view more details on an decoder
ffmpeg -h decoder=aac
# list all containers (formats)
ffmpeg -formats
```

# docs
- [ffmpeg CompilationGuide](https://trac.ffmpeg.org/wiki/CompilationGuide)
- [debug ffmpeg](http://ffmpeg.xianwaizhiyin.net/debug-ffmpeg/debug-ffmpeg.html)
- [use msys2 shell on github actions](https://www.lprp.fr/2021/06/compiling-gimp-plugins-for-windows-has-never-been-so-easy-with-msys2/)
- [FFmpeg list all codecs, encoders, decoders and formats](https://write.corbpie.com/ffmpeg-list-all-codecs-encoders-decoders-and-formats/)
- [github action inputs with different types of triggers](https://dev.to/mrmike/github-action-handling-input-default-value-5f2g)