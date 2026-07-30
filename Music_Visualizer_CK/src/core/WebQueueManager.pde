// WebQueueManager - turn-based web controller queue, crowd moderation, and operator controls.

import org.java_websocket.WebSocket;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

class WebQueueManager {
  List<String> queue = new ArrayList<String>();
  String activeDriverId = null;
  long turnStartMs = 0;
  int turnDurationSec = 300; // 5 minutes
  boolean paused = false;
  String pinnedDriverId = null;

  // Crowd voting 👍/👎 for the current driver turn
  Map<String, Integer> currentVotes = new HashMap<String, Integer>();
  int likes = 0;
  int dislikes = 0;

  long lastTickMs = 0;
  long lastBroadcastMs = 0;
  // Re-send the full status this often even when nothing changes, so every
  // client's countdown and "wait ~Nm" estimate stay in sync with the server
  // through a long, quiet turn (no joins/votes to trigger an event broadcast).
  static final long RESYNC_INTERVAL_MS = 5000;

  WebQueueManager() {
  }

  // Add client to queue (called on handshake success)
  synchronized void join(String clientId) {
    if (clientId == null || clientId.isEmpty()) return;

    // Spectators and admins are exempt from queue
    if (clientRegistry != null) {
      ClientInfo info = clientRegistry.byId.get(clientId);
      if (info != null && ("spectator".equals(info.role) || "admin".equals(info.role))) {
        return;
      }
    }

    if (!queue.contains(clientId)) {
      queue.add(clientId);
      println("[QUEUE] Client joined: " + clientId);
      if (activeDriverId == null) {
        promoteNext();
      } else {
        broadcastStatus();
      }
    }
  }

  // Remove client from queue (called on disconnect / kick)
  synchronized void leave(String clientId) {
    if (clientId == null) return;
    if (queue.remove(clientId)) {
      println("[QUEUE] Client left: " + clientId);
      if (clientId.equals(activeDriverId)) {
        activeDriverId = null;
        promoteNext();
      } else {
        broadcastStatus();
      }
    }
  }

  // Clear everything (e.g. on shutdown/reset)
  synchronized void clear() {
    queue.clear();
    activeDriverId = null;
    pinnedDriverId = null;
    currentVotes.clear();
    likes = 0;
    dislikes = 0;
    turnStartMs = 0;
    broadcastStatus();
  }

  // Promote next waiting driver
  synchronized void promoteNext() {
    currentVotes.clear();
    likes = 0;
    dislikes = 0;

    if (pinnedDriverId != null && isConnected(pinnedDriverId)) {
      activeDriverId = pinnedDriverId;
      turnStartMs = System.currentTimeMillis();
      broadcastStatus();
      return;
    }

    pruneDisconnected();

    if (queue.isEmpty()) {
      activeDriverId = null;
      turnStartMs = 0;
      broadcastStatus();
      return;
    }

    activeDriverId = queue.get(0);
    turnStartMs = System.currentTimeMillis();
    println("[QUEUE] Promoted next driver: " + activeDriverId);
    broadcastStatus();
  }

  // Force rotation to next driver
  synchronized void rotate() {
    if (queue.size() <= 1) {
      // Grace: keep active driver, reset clock
      turnStartMs = System.currentTimeMillis();
      broadcastStatus();
      return;
    }

    String oldDriver = activeDriverId;
    if (oldDriver != null) {
      queue.remove(oldDriver);
      queue.add(oldDriver);
    }
    promoteNext();
  }

  // Check if a client is registered and connected
  boolean isConnected(String clientId) {
    if (clientRegistry == null) return false;
    ClientInfo info = clientRegistry.byId.get(clientId);
    if (info == null) return false;
    
    // WS connection is open
    if (info.conn != null && info.conn.isOpen()) return true;
    
    // HTTP client: check if active recently (within 30 seconds)
    if (info.conn == null && (System.currentTimeMillis() - info.lastMsgMs) < 30000) return true;
    
    return false;
  }

  // Verify if client is the active driver or has operator privilege
  synchronized boolean isActiveDriver(String clientId) {
    if (clientId == null || clientId.isEmpty()) return false;
    if (clientRegistry != null) {
      ClientInfo info = clientRegistry.byId.get(clientId);
      if (info != null && "admin".equals(info.role)) return true; // operator bypass
    }
    return clientId.equals(activeDriverId);
  }

  // Handle 👍/👎 votes from other queue members
  synchronized void vote(String voterId, int value) {
    if (activeDriverId == null) return;
    if (voterId.equals(activeDriverId)) return; // no self-voting

    int v = value > 0 ? 1 : (value < 0 ? -1 : 0);
    if (v == 0) {
      currentVotes.remove(voterId);
    } else {
      currentVotes.put(voterId, v);
    }

    // Tally votes
    int l = 0;
    int d = 0;
    for (int voteVal : currentVotes.values()) {
      if (voteVal > 0) l++;
      else if (voteVal < 0) d++;
    }
    likes = l;
    dislikes = d;

    // Troll mitigation: skip if too many dislikes (e.g. 5+ dislikes and dislikes > likes)
    if (dislikes >= 5 && dislikes > likes * 2) {
      println("[QUEUE] Crowd veto! Shortening turn for: " + activeDriverId);
      turnStartMs = System.currentTimeMillis() - (turnDurationSec * 1000L); // expire turn
    }

    broadcastStatus();
  }

  // Remove disconnected/idle clients
  synchronized void pruneDisconnected() {
    long now = System.currentTimeMillis();
    Iterator<String> it = queue.iterator();
    while (it.hasNext()) {
      String cid = it.next();
      if (!isConnected(cid)) {
        it.remove();
      }
    }
  }

  // Main game-loop tick
  synchronized void tick() {
    long now = System.currentTimeMillis();
    if (now - lastTickMs < 1000) return;
    lastTickMs = now;

    if (paused) return;

    pruneDisconnected();

    if (activeDriverId != null) {
      if (!isConnected(activeDriverId)) {
        println("[QUEUE] Active driver disconnected; moving next");
        leave(activeDriverId);
        return;
      }

      long elapsedSec = (now - turnStartMs) / 1000;
      if (elapsedSec >= turnDurationSec) {
        println("[QUEUE] Turn duration elapsed; rotating");
        rotate();
      } else if (now - lastBroadcastMs >= RESYNC_INTERVAL_MS) {
        broadcastStatus();   // periodic resync (time-based, not frame-based)
      }
    } else {
      if (!queue.isEmpty()) {
        promoteNext();
      }
    }
  }

  // Broadcast status payload over WS to all connected clients
  void broadcastStatus() {
    lastBroadcastMs = System.currentTimeMillis();   // any send resets the resync clock
    if (controllerWS != null) {
      controllerWS.broadcast(getStatusJson());
    }
  }

  // Generate queue status JSON
  synchronized String getStatusJson() {
    long now = System.currentTimeMillis();
    long elapsedSec = activeDriverId != null ? (now - turnStartMs) / 1000 : 0;
    long timeLeftSec = Math.max(0, turnDurationSec - elapsedSec);

    StringBuilder sb = new StringBuilder();
    sb.append("{\"type\":\"queue-status\"")
      .append(",\"activeDriverId\":\"").append(paramJsonEsc(activeDriverId != null ? activeDriverId : ""))
      .append("\",\"activeDriverName\":\"").append(paramJsonEsc(getNickname(activeDriverId)))
      .append("\",\"timeLeftSec\":").append(timeLeftSec)
      .append(",\"turnDurationSec\":").append(turnDurationSec)
      .append(",\"likes\":").append(likes)
      .append(",\"dislikes\":").append(dislikes)
      .append(",\"paused\":").append(paused)
      .append(",\"queue\":[");

    for (int i = 0; i < queue.size(); i++) {
      String cid = queue.get(i);
      if (i > 0) sb.append(",");
      sb.append("{\"clientId\":\"").append(paramJsonEsc(cid))
        .append("\",\"nickname\":\"").append(paramJsonEsc(getNickname(cid)))
        .append("\"}");
    }
    sb.append("]}");
    return sb.toString();
  }

  String getNickname(String clientId) {
    if (clientId == null || clientId.isEmpty()) return "None";
    if (clientRegistry != null) {
      ClientInfo info = clientRegistry.byId.get(clientId);
      if (info != null) return info.nickname;
    }
    return "user-" + clientId.substring(0, Math.min(clientId.length(), 4));
  }
}
