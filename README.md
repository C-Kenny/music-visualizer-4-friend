# Music Visualizer for a Friend

### What?
2D Music Visualizer, made using [Processing 3.](https://processing.org/)


### Current State?

With sound: [Music Visualizer with Controller Overlay](https://music-visualizer-4-friend.s3-ap-southeast-2.amazonaws.com/music_visualizer_controller.mp4)


Without sound:

![MusicVisualizerCK](output/current_output_animated.gif)


### How to run development build?

This visualizer relies on [processing-java](https://github.com/processing/processing/wiki/Command-Line) to be installed.

```
$ which processing-java
/usr/local/bin/processing-java
```

Once that has been setup, you can run:

`$ ./run.sh`

which will launch the visualizer.

### How to run user Visualizer app?




### Why?

One of my friends passed away, we used to play a lot of Halo together. This music visualizer is dedicated to him, and we use his Halo 3 Emblem as inspiration.

![Halo3Emblem](media/h3_emblem.jpg)


### Required Libraries:

- [Handy. Used to make lines look 'hand-drawn'](https://github.com/gicentre/handy)
- [Game Control Plus. Used to handle Xbox 360 controller input](http://lagers.org.uk/gamecontrol/)
- [Minim. Used by the computer to listen to the music + break into frequencies/decibels](http://code.compartmental.net/tools/minim/)

### Resources:

- [Music Visualizer source code on GitHub](https://github.com/C-Kenny/music-visualizer-4-friend)
- [GitHub Issue tracker for repo](https://github.com/C-Kenny/music-visualizer-4-friend/issues)

### Credits:

- ttaM for the incredible help on the Bezier Curves (fins)!