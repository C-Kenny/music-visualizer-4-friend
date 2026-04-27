// ControllerWebSocket — low-latency phone-controller stream over WS.
//
// Listens on port 8081. Browser sends JSON frames:
//   {"type":"hello","clientId":"<uuid>","nickname":"Sam","ua":"...","platform":"...",
//    "model":"Pixel 7","screen":[412,915],"dpr":2.625}
//   {"type":"sticks","lx":-1..1,"ly":-1..1,"rx":-1..1,"ry":-1..1}
//   {"type":"button","btn":"A|B|X|Y","action":"down|up|tap"}
//
// hello must arrive before sticks/button or the conn is dropped. Identity from
// hello is used for rate limiting, role assignment, kick/ban.

import org.java_websocket.WebSocket;
import org.java_websocket.handshake.ClientHandshake;
import org.java_websocket.server.WebSocketServer;
import java.net.InetSocketAddress;

class ControllerWebSocket extends WebSocketServer {

  ControllerWebSocket(int port) {
    super(new InetSocketAddress("0.0.0.0", port));
    setReuseAddr(true);
  }

  String ipOf(WebSocket conn) {
    try { return conn.getRemoteSocketAddress().getAddress().getHostAddress(); }
    catch (Exception e) { return "?"; }
  }

  @Override
  public void onOpen(WebSocket conn, ClientHandshake handshake) {
    String ip = ipOf(conn);
    println("[WS] controller connected: " + conn.getRemoteSocketAddress());
    if (clientRegistry != null && !clientRegistry.registerWs(conn, ip)) {
      try { conn.close(1008, "banned"); } catch (Exception e) {}
    }
  }

  @Override
  public void onClose(WebSocket conn, int code, String reason, boolean remote) {
    println("[WS] controller disconnected (" + code + "): " + reason);
    if (clientRegistry != null) clientRegistry.onClose(conn);
  }

  @Override
  public void onMessage(WebSocket conn, String msg) {
    try {
      JSONObject o = parseJSONObject(msg);
      if (o == null) return;
      String type = o.getString("type", "");
      String ip = ipOf(conn);

      if (type.equals("hello")) {
        String err = clientRegistry.applyHello(conn, ip, o);
        if (err != null) {
          // Send a reason payload before close so the client UI can show it.
          try { conn.send("{\"type\":\"hello-rejected\",\"reason\":\"" + err + "\"}"); } catch (Exception e) {}
          try { conn.close(1008, err); } catch (Exception e) {}
        } else {
          try { conn.send("{\"type\":\"hello-ok\"}"); } catch (Exception e) {}
        }
        return;
      }

      ClientInfo info = clientRegistry.byConn(conn);
      if (info == null) {
        // No hello yet — drop and ask client to identify (we just close; client reconnects + sends hello).
        try { conn.close(1002, "hello required"); } catch (Exception e) {}
        return;
      }
      if (!clientRegistry.allow(info)) {
        return;   // silently drop over rate limit
      }

      if (type.equals("sticks")) {
        webController.setSticks(
          info.clientId,
          o.getFloat("lx", 0),
          o.getFloat("ly", 0),
          o.getFloat("rx", 0),
          o.getFloat("ry", 0)
        );
      } else if (type.equals("button")) {
        String btn = o.getString("btn", "");
        String act = o.getString("action", "");
        webController.setButton(info.clientId, btn, act);
      } else if (type.equals("trigger")) {
        webController.setTrigger(info.clientId,
          o.getString("which", ""), o.getFloat("value", 0));
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
