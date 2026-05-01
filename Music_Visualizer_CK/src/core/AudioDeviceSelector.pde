/**
 * AudioDeviceSelector
 *
 * Lists available audio *input* devices from Java's AudioSystem. Used when
 * switching from file playback to real-time capture (F10 toggle, F1/F2 cycle).
 *
 * To capture another app's *output* (YT/Spotify/foobar) the OS must expose a
 * loopback as a capture device:
 *   - Linux (PulseAudio/PipeWire): pick "Monitor of <sink>" entry. If absent,
 *       `pactl load-module module-loopback` or set monitor as default source.
 *   - Windows: enable "Stereo Mix" in Sound settings, or install VB-Cable /
 *       VoiceMeeter and route app output to it.
 *   - macOS: install BlackHole (free) or Loopback (paid); route app to it.
 * Java's AudioSystem then sees the loopback as a normal input mixer.
 */
import javax.sound.sampled.*;
import java.util.ArrayList;
import java.util.List;

class AudioDeviceSelector {
  ArrayList<String> deviceNames;
  ArrayList<Mixer.Info> mixerInfos;
  int selectedIndex = 0;
  boolean initialized = false;

  AudioDeviceSelector() {
    this.deviceNames = new ArrayList<String>();
    this.mixerInfos = new ArrayList<Mixer.Info>();
    this.initialized = false;
  }

  /**
   * Enumerate all available audio input devices using Java's AudioSystem.
   * Called once during setup or when user requests device refresh.
   */
  void refresh() {
    deviceNames.clear();
    mixerInfos.clear();
    
    try {
      Mixer.Info[] allMixers = AudioSystem.getMixerInfo();
      if (allMixers == null || allMixers.length == 0) {
        println("[AudioDeviceSelector] No audio devices found");
        return;
      }

      for (Mixer.Info info : allMixers) {
        try {
          Mixer mixer = AudioSystem.getMixer(info);
          // Check if this mixer has input lines (can record audio)
          javax.sound.sampled.Line.Info[] lineInfos = mixer.getTargetLineInfo();
          if (lineInfos != null && lineInfos.length > 0) {
            deviceNames.add(info.getName());
            mixerInfos.add(info);
          }
        } catch (Exception e) {
          println("[AudioDeviceSelector] Error checking device " + info.getName() + ": " + e.getMessage());
        }
      }

      initialized = true;
      println("[AudioDeviceSelector] Found " + deviceNames.size() + " audio input devices:");
      for (int i = 0; i < deviceNames.size(); i++) {
        println("  [" + i + "] " + deviceNames.get(i));
      }
    } catch (Exception e) {
      println("[AudioDeviceSelector] Failed to enumerate devices: " + e.getMessage());
    }
  }

  /**
   * Select a device by index.
   */
  void selectDevice(int index) {
    if (index >= 0 && index < deviceNames.size()) {
      selectedIndex = index;
      println("[AudioDeviceSelector] Selected device: " + deviceNames.get(index));
    } else {
      println("[AudioDeviceSelector] Invalid device index: " + index);
    }
  }

  /**
   * Get the currently selected device name.
   */
  String getSelectedDeviceName() {
    if (selectedIndex >= 0 && selectedIndex < deviceNames.size()) {
      return deviceNames.get(selectedIndex);
    }
    return "Default";
  }

  /**
   * Get the currently selected mixer info.
   */
  Mixer.Info getSelectedMixerInfo() {
    if (selectedIndex >= 0 && selectedIndex < mixerInfos.size()) {
      return mixerInfos.get(selectedIndex);
    }
    return null;
  }

  /**
   * Get the currently selected device index.
   */
  int getSelectedIndex() {
    return selectedIndex;
  }

  /**
   * Get the number of available devices.
   */
  int getDeviceCount() {
    return deviceNames.size();
  }

  /**
   * Cycle to next device.
   */
  void selectNext() {
    selectedIndex = (selectedIndex + 1) % max(1, deviceNames.size());
    println("[AudioDeviceSelector] Cycled to device: " + getSelectedDeviceName());
  }

  /**
   * Cycle to previous device.
   */
  void selectPrevious() {
    selectedIndex = (selectedIndex - 1 + max(1, deviceNames.size())) % max(1, deviceNames.size());
    println("[AudioDeviceSelector] Cycled to device: " + getSelectedDeviceName());
  }
}

