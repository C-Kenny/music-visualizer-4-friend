import org.gamecontrolplus.gui.*;
import org.gamecontrolplus.*;
import net.java.games.input.*;

class Controller {
  ControlIO control;
  ControlDevice stick;

  float lx, ly;
  float rx, ry;

  /** Left / right trigger depression, ~0 (released) … 1 (full). Absent axes stay 0. */
  float lt, rt;

  boolean a_button, b_button, x_button, y_button;
  boolean back_button, start_button;
  boolean lb_button, rb_button;

  boolean dpad_hat_switch_up, dpad_hat_switch_down, dpad_hat_switch_left, dpad_hat_switch_right;

  boolean lstickclick_button, rstickclick_button;

  // Rising-edge (just pressed) flags — true only on the first frame a button goes down
  boolean a_just_pressed, b_just_pressed, x_just_pressed, y_just_pressed;
  boolean back_just_pressed, start_just_pressed;
  boolean lb_just_pressed, rb_just_pressed;
  boolean lstickclick_just_pressed, rstickclick_just_pressed;
  boolean dpad_up_just_pressed, dpad_down_just_pressed, dpad_left_just_pressed, dpad_right_just_pressed;

  // Previous-frame button states for edge detection
  private boolean prev_a, prev_b, prev_x, prev_y;
  private boolean prev_back, prev_start;
  private boolean prev_lb, prev_rb;
  private boolean prev_lstickclick, prev_rstickclick;
  private boolean prev_dpad_up, prev_dpad_down, prev_dpad_left, prev_dpad_right;

  Controller(PApplet applet) {
    control = ControlIO.getInstance(applet);
    stick = control.getMatchedDevice("joystick");
  }

  boolean isConnected() {
    return stick != null;
  }

  // Print matched device name and all its controls — call once from setup for debugging
  void debugPrintControls() {
    println("=== Controller matched: " + stick.getName() + " ===");
    for (ControlInput inp : stick.getInputs()) {
      String type = (inp instanceof ControlHat) ? "HAT" : (inp instanceof ControlButton) ? "BUTTON" : "SLIDER";
      println("  " + type + ": '" + inp.getName() + "'");
    }
  }

  void read() {
    lx = map(stick.getSlider("lx").getValue(), -1, 1, 0, width);
    ly = map(stick.getSlider("ly").getValue(), -1, 1, 0, height);

    rx = map(stick.getSlider("rx").getValue(), -1, 1, 0, width);
    ry = map(stick.getSlider("ry").getValue(), -1, 1, 0, height);

    try {
      lt = constrain(map(stick.getSlider("lt").getValue(), -1, 1, 0, 1), 0, 1);
    } catch (Exception e) {
      lt = 0;
    }
    try {
      rt = constrain(map(stick.getSlider("rt").getValue(), -1, 1, 0, 1), 0, 1);
    } catch (Exception e) {
      rt = 0;
    }

    a_button = stick.getButton("a").pressed();
    b_button = stick.getButton("b").pressed();
    x_button = stick.getButton("x").pressed();
    y_button = stick.getButton("y").pressed();

    back_button = stick.getButton("back").pressed();
    start_button = stick.getButton("start").pressed();

    lb_button = stick.getButton("lb").pressed();
    rb_button = stick.getButton("rb").pressed();

    lstickclick_button = stick.getButton("lstickclick").pressed();
    rstickclick_button = stick.getButton("rstickclick").pressed();

    dpad_hat_switch_up = stick.getHat("dpad").up();
    dpad_hat_switch_down = stick.getHat("dpad").down();
    dpad_hat_switch_left = stick.getHat("dpad").left();
    dpad_hat_switch_right = stick.getHat("dpad").right();

    // Compute rising-edge flags
    a_just_pressed = a_button && !prev_a;
    b_just_pressed = b_button && !prev_b;
    x_just_pressed = x_button && !prev_x;
    y_just_pressed = y_button && !prev_y;
    back_just_pressed = back_button && !prev_back;
    start_just_pressed = start_button && !prev_start;
    lb_just_pressed = lb_button && !prev_lb;
    rb_just_pressed = rb_button && !prev_rb;
    lstickclick_just_pressed = lstickclick_button && !prev_lstickclick;
    rstickclick_just_pressed = rstickclick_button && !prev_rstickclick;
    dpad_up_just_pressed = dpad_hat_switch_up && !prev_dpad_up;
    dpad_down_just_pressed = dpad_hat_switch_down && !prev_dpad_down;
    dpad_left_just_pressed = dpad_hat_switch_left && !prev_dpad_left;
    dpad_right_just_pressed = dpad_hat_switch_right && !prev_dpad_right;

    // Save current state for next frame
    prev_a = a_button; prev_b = b_button; prev_x = x_button; prev_y = y_button;
    prev_back = back_button; prev_start = start_button;
    prev_lb = lb_button; prev_rb = rb_button;
    prev_lstickclick = lstickclick_button; prev_rstickclick = rstickclick_button;
    prev_dpad_up = dpad_hat_switch_up; prev_dpad_down = dpad_hat_switch_down;
    prev_dpad_left = dpad_hat_switch_left; prev_dpad_right = dpad_hat_switch_right;
  }
}