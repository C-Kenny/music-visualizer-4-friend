class Config {
  String CIRCUIT_TEXT = "CK";
  float PULSE_VALUE;
  float HEART_PULSE;
  int   HEART_COLS;

  float DASH_LINE_SPEED;
  float DASH_LINE_SPEED_LIMIT;
  boolean DASH_LINE_SPEED_INCREASING;

  int HANDY_RENDERERS_COUNT;

  int MIN_HANDY_RENDERER_POSITION;
  int MAX_HANDY_RENDERER_POSITION;
  int CURRENT_HANDY_RENDERER_POSITION;

  boolean APPEAR_HAND_DRAWN;

  boolean DRAW_DIAMONDS;
  boolean DRAW_FINS;
  boolean DRAW_WAVEFORM;
  boolean SHOW_CONTROLLER_GUIDE;  // Toggle with 'h' key

  boolean FIN_REDNESS_ANGRY;
  boolean ANIMATED;

  int LAST_FIN_CHECK;
  float FINS;
  int FIN_REDNESS;

  boolean canChangeFinDirection;

  boolean canChangePlasmaFlow;
  boolean finRotationClockWise;

  float BEZIER_Y_OFFSET;
  float MAX_BEZIER_Y_OFFSET;
  float MIN_BEZIER_Y_OFFSET;

  float WAVE_MULTIPLIER;

  boolean DRAW_TUNNEL;

  int LAST_PLASMA_CHECK;
  boolean PLASMA_INCREMENTING;
  int PLASMA_SIZE;

  int PLASMA_SEED;

  boolean DRAW_PLASMA;
  boolean DRAW_POLAR_PLASMA;

  float DIAMOND_DISTANCE_FROM_CENTER;

  boolean DIAMOND_CAN_CHANGE_CENTER_DISANCE;
  boolean DIAMON_CAN_CHANGE_X_WIDTH;

  float DIAMOND_WIDTH_OFFSET;
  float DIAMOND_HEIGHT_OFFSET;

  float DIAMOND_RIGHT_EDGE_X;
  float DIAMOND_LEFT_EDGE_X;

  float DIAMOND_RIGHT_EDGE_Y;
  float DIAMOND_LEFT_EDGE_Y;

  float MAX_DIAMOND_DISTANCE;
  float MIN_DIAMOND_DISTANCE;

  boolean INCREMENT_DIAMOND_DISTANCE;

  boolean DRAW_INNER_DIAMONDS;

  int CURRENT_BLEND_MODE_INDEX;

  boolean BACKGROUND_ENABLED;

  int bandsPerOctave;

  String SONG_TO_VISUALIZE;

  int STATE;

  float GLOBAL_REDNESS;

  boolean EPILEPSY_MODE_ON;

  boolean SONG_PLAYING;
  String SONG_NAME;

  boolean USING_CONTROLLER;

  boolean LOGGING_ENABLED;

  boolean RAINBOW_FINS;

  boolean SCREEN_RECORDING;
  boolean SHOW_CODE;
  boolean SHOW_METADATA;
  boolean BLOOM_ENABLED;

  boolean LOW_POWER_MODE;
  int LOW_POWER_SCALE;

  ArrayList<String> songList;
  int currentSongIndex;

  String OS_TYPE;

  String TITLE_BAR;

  int TUNNEL_ZOOM_INCREMENT;

  int logicalFrameCount;

  Config() {
    TITLE_BAR = "(t)unnel (b)lendmode, (d)iamonds, (f)in direction, (h)and-drawn, (p)lasma, (s)top, (w)ave, (>)toggle diamonds, (/)toggle fins, (n)ext song, (N)shuffle, (m)etadata";

    OS_TYPE = discoverOperatingSystem();

    PULSE_VALUE = 19.0;
    HEART_PULSE = 10.0;
    HEART_COLS  = 9;

    DASH_LINE_SPEED = 0.5;
    DASH_LINE_SPEED_LIMIT = 69;
    DASH_LINE_SPEED_INCREASING = true;

    canChangePlasmaFlow = false;
    PLASMA_INCREMENTING = true;
    PLASMA_SIZE = 128;

    PLASMA_SEED = 0;

    DRAW_PLASMA = false;
    DRAW_POLAR_PLASMA = false;

    DRAW_TUNNEL = false;
    TUNNEL_ZOOM_INCREMENT = 400;

    MIN_HANDY_RENDERER_POSITION = 0;
    CURRENT_HANDY_RENDERER_POSITION = 0;

    APPEAR_HAND_DRAWN = true;

    DRAW_DIAMONDS = true;
    DRAW_FINS = true;
    DRAW_WAVEFORM = true;

    FIN_REDNESS_ANGRY = true;
    ANIMATED = true;

    FINS = 8.0;
    FIN_REDNESS = 1;

    canChangeFinDirection = true;
    finRotationClockWise = false;

    BEZIER_Y_OFFSET = -50;
    MAX_BEZIER_Y_OFFSET = 40;
    MIN_BEZIER_Y_OFFSET = -140;

    WAVE_MULTIPLIER = 50.0;

    DIAMOND_CAN_CHANGE_CENTER_DISANCE = true;
    DIAMON_CAN_CHANGE_X_WIDTH = true;

    DIAMOND_WIDTH_OFFSET = 0.0;
    DIAMOND_HEIGHT_OFFSET = 0.0;

    INCREMENT_DIAMOND_DISTANCE = true;

    DRAW_INNER_DIAMONDS = false;

    CURRENT_BLEND_MODE_INDEX = 0;

    BACKGROUND_ENABLED = true;

    bandsPerOctave = 4;

    SONG_TO_VISUALIZE = "";

    STATE = 0;

    GLOBAL_REDNESS = 0.0;

    EPILEPSY_MODE_ON = false;

    SONG_PLAYING = false;
    SONG_NAME = "";

    USING_CONTROLLER = false;

    RAINBOW_FINS = false;

    SCREEN_RECORDING = false;
    SHOW_CODE = false;
    LOGGING_ENABLED = false;
    BLOOM_ENABLED = false;
    SHOW_METADATA = false;

    LOW_POWER_MODE = false;
    LOW_POWER_SCALE = 2;

    logicalFrameCount = 0;

    songList = new ArrayList<String>();
    currentSongIndex = 0;

    if (args != null) {
      for (String arg : args) {
        if (arg.equals("--fancy")) {
          BLOOM_ENABLED = true;
        }
        if (arg.startsWith("--circuit-text=")) {
          CIRCUIT_TEXT = arg.substring("--circuit-text=".length());
        }
        if (arg.equals("--lowpower")) {
          LOW_POWER_MODE = true;
          BLOOM_ENABLED = false;
        }
        if (arg.startsWith("--lowpower-scale=")) {
          try {
            LOW_POWER_SCALE = Integer.parseInt(arg.substring("--lowpower-scale=".length()));
            if (LOW_POWER_SCALE < 2) LOW_POWER_SCALE = 2;
          } catch (Exception e) {
            LOW_POWER_SCALE = 2;
          }
          LOW_POWER_MODE = true;
          BLOOM_ENABLED = false;
        }
      }
    }
  }
}