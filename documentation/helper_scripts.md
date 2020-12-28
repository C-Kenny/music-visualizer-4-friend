
### Getting Vim + Processing 3 working together
- Get Oracle's Java running locally. Processing comes with it's own java installation, we don't want to use this.

  `$ ln -s /usr/lib/jvm/java-8-oracle/jre/bin/java ./java/bin/java`

- Make `processing-java` global:

  `$ sudo ln -s /home/<local_path/processing-3.4/processing-java /usr/local/bin/processing-java`

- Setup `vim-processing` https://github.com/sophacles/vim-processing

  `:make`

### Create video recording (.mp4) of Visualizer using OBS
```
$ obs --startrecording
```

Given that the scene + window capture is setup, this will boot the OBS GUI with
recording started. Use the output (usually in ~/videos) to create a .gif
of the Visualizer.


### Convert OBS captured .mp4 to .gif

```
$ ffmpeg \
  -i music_visualizer_preview.mp4 \
  -r 60 \
  -vf scale=420:-1 \
  music_visualizer_preview.gif
```
