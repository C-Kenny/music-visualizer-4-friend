// ControllerWebSocket — low-latency phone-controller stream over WS.
//
// Listens on port 8081. Browser sends JSON frames:
//   {"type":"sticks","lx":-1..1,"ly":-1..1,"rx":-1..1,"ry":-1..1}
//   {"type":"button","btn":"A|B|X|Y","action":"down|up|tap"}
//
// Updates the global webController; merged into Controller state by the main
// draw loop.

import org.java_websocket.WebSocket;
import org.java_websocket.handshake.ClientHandshake;
import org.java_websocket.server.WebSocketServer;
import java.net.InetSocketAddress;

class ControllerWebSocket extends WebSocketServer {

  ControllerWebSocket(int port) {
    super(new InetSocketAddress("0.0.0.0", port));
    setReuseAddr(true);
  }

  @Override
  public void onOpen(WebSocket conn, ClientHandshake handshake) {
    println("[WS] controller connected: " + conn.getRemoteSocketAddress());
  }

  @Override
  public void onClose(WebSocket conn, int code, String reason, boolean remote) {
    println("[WS] controller disconnected (" + code + "): " + reason);
  }

  @Override
  public void onMessage(WebSocket conn, String msg) {
    try {
      JSONObject o = parseJSONObject(msg);
      if (o == null) return;
      String type = o.getString("type", "");
      if (type.equals("sticks")) {
        webController.setSticks(
          o.getFloat("lx", 0),
          o.getFloat("ly", 0),
          o.getFloat("rx", 0),
          o.getFloat("ry", 0)
        );
      } else if (type.equals("button")) {
        String btn = o.getString("btn", "");
        String act = o.getString("action", "");
        webController.setButton(btn, act);
        println("[WS] button " + btn + " " + act);
      }
    } catch (Exception e) {
      println("[WS] message parse error: " + e.getMessage());
    }
  }

  @Override
  public void onError(WebSocket conn, Exception ex) {
    println("[WS] error: " + ex.getMessage());
  }

  @Override
  public void onStart() {
    println("[WS] controller server listening on port " + getPort());
  }
}
