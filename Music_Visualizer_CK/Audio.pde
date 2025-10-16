import ddf.minim.*;
import ddf.minim.analysis.*;

class Audio {
  Minim minim;
  AudioPlayer player;
  BeatDetect beat;
  FFT fft;

  Audio(PApplet applet, String songToVisualize, int bandsPerOctave) {
    minim = new Minim(applet);
    player = minim.loadFile(songToVisualize);
    player.loop();
    beat = new BeatDetect();
    fft = new FFT(player.bufferSize(), player.sampleRate());
    fft.logAverages(22, bandsPerOctave);
  }

  void forward() {
    fft.forward(player.mix);
  }

  void play() {
    player.play();
  }

  void pause() {
    player.pause();
  }

  void skip(int time) {
    player.skip(time);
  }

  float getGain() {
    return player.getGain();
  }

  void setGain(float gain) {
    player.setGain(gain);
  }

  void stop() {
    minim.stop();
  }
}