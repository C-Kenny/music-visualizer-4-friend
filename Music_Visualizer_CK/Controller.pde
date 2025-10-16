import org.gamecontrolplus.gui.*;
import org.gamecontrolplus.*;
import net.java.games.input.*;

class Controller {
  ControlIO control;
  ControlDevice stick;

  float lx, ly;
  float rx, ry;

  boolean a_button, b_button, x_button, y_button;
  boolean back_button, start_button;
  boolean lb_button, rb_button;

  boolean dpad_hat_switch_up, dpad_hat_switch_down, dpad_hat_switch_left, dpad_hat_switch_right;

  boolean lstickclick_button, rstickclick_button;

  Controller(PApplet applet) {
    control = ControlIO.getInstance(applet);
    stick = control.getMatchedDevice("joystick");
  }

  boolean isConnected() {
    return stick != null;
  }

  void read() {
    lx = map(stick.getSlider("lx").getValue(), -1, 1, 0, width);
    ly = map(stick.getSlider("ly").getValue(), -1, 1, 0, height);

    rx = map(stick.getSlider("rx").getValue(), -1, 1, 0, width);
    ry = map(stick.getSlider("ry").getValue(), -1, 1, 0, height);

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
  }
}