class Config {
  float PULSE_VALUE;
  float HEART_PULSE;

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

  boolean SCREEN_RECORDING;

  String OS_TYPE;

  String TITLE_BAR;

  int TUNNEL_ZOOM_INCREMENT;

  Config() {
    TITLE_BAR = "(t)unnel (b)lendmode, (d)iamonds, (f)in direction, (h)and-drawn, (p)lasma, (s)top, (w)ave, (>)toggle diamonds, (/)toggle fins";

    OS_TYPE = discoverOperatingSystem();

    PULSE_VALUE = 19.0;
    HEART_PULSE = 10.0;

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

    DIAMOND_DISTANCE_FROM_CENTER = width*0.07;

    DIAMOND_RIGHT_EDGE_X = width*0.92;
    DIAMOND_LEFT_EDGE_X = width*0.74;

    DIAMOND_RIGHT_EDGE_Y = height*0.71;
    DIAMOND_LEFT_EDGE_Y = height*0.92;

    DIAMOND_CAN_CHANGE_CENTER_DISANCE = true;
    DIAMON_CAN_CHANGE_X_WIDTH = true;

    DIAMOND_WIDTH_OFFSET = 0.0;
    DIAMOND_HEIGHT_OFFSET = 0.0;

    MAX_DIAMOND_DISTANCE = width * 0.3;
    MIN_DIAMOND_DISTANCE = height * 0.1;

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

    SCREEN_RECORDING = false;
  }
}