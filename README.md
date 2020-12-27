# Music Visualizer for a Friend

### What?
Music Visualizer, starting with a 2D representation. Written in Processing 3.


### Current State?

With sound: https://streamable.com/dhv39

Without sound:

![MusicVisualizerCK](output/current_output_animated.gif)




### Why?

One of my friends passed away, we used to play a lot of Halo together. This music visualizer is dedicated to him, and we use his Halo 3 Emblem as inspiration.

![Halo3Emblem](media/h3_emblem.jpg)


### Ideas?

- Feel free to submit pull requests of code improvements/features.
- Create a GitHub issue, and I'll look into developing it.

### Required Libraries:

- Handy
- Game Control Plus
- Minim

### Resources:

- [Music Visualizer source code on GitHub](https://github.com/C-Kenny/music-visualizer-4-friend)
- [GitHub Issue tracker for repo](https://github.com/C-Kenny/music-visualizer-4-friend/issues)

### Credits:

- ttaM for the incredible help on the Bezier Curves (fins)!
- [Minim, for audio library](http://code.compartmental.net/minim/)
- [Processing 3, for providing a platform to create with](https://processing.org/)
- [Handy, for the sketch style render option](https://www.gicentre.net/handy/using/)


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


