import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

/**
 * InputChord — generic chord/buffer helper for scene input.
 *
 * Buffers named input intents for a short window so near-simultaneous presses
 * can resolve as a chord (e.g. "moveFwd" + "jumpUp" → "jumpFwd"). Decouples
 * input edge detection from action firing.
 *
 * Usage:
 *   InputChord chord = new InputChord(3);
 *   chord.register("moveFwd", "jumpUp", "jumpFwd");
 *   ...
 *   if (stickFwdEdge)  chord.press("moveFwd");
 *   if (aJustPressed)  chord.press("jumpUp");
 *   for (String intent : chord.resolve()) {
 *     switch (intent) {
 *       case "moveFwd": tryMove(FWD); break;
 *       case "jumpUp":  tryJump(false); break;
 *       case "jumpFwd": tryJump(true); break;
 *     }
 *   }
 *
 * Notes:
 *  - Chord rules are checked before expiry, so a chord fires the moment both
 *    halves are present (no waiting for window to elapse).
 *  - Lone intents flush only after `windowFrames` frames, giving the partner
 *    time to arrive.
 *  - Re-pressing same intent within window just refreshes its timestamp.
 */
class InputChord {
  int window;
  HashMap<String, Integer> pending = new HashMap<String, Integer>();
  ArrayList<ChordRule> rules = new ArrayList<ChordRule>();

  InputChord(int windowFrames) { this.window = windowFrames; }

  void register(String a, String b, String result) {
    rules.add(new ChordRule(a, b, result));
  }

  void press(String intent) {
    pending.put(intent, frameCount);
  }

  boolean has(String intent) { return pending.containsKey(intent); }

  void clear() { pending.clear(); }

  /** Call once per frame after pressing. Returns intents ready to execute. */
  ArrayList<String> resolve() {
    ArrayList<String> out = new ArrayList<String>();
    // Chord matches: fire as soon as both halves present.
    for (ChordRule r : rules) {
      if (pending.containsKey(r.a) && pending.containsKey(r.b)) {
        out.add(r.result);
        pending.remove(r.a);
        pending.remove(r.b);
      }
    }
    // Expired singles flush as standalone.
    Iterator<Map.Entry<String, Integer>> it = pending.entrySet().iterator();
    while (it.hasNext()) {
      Map.Entry<String, Integer> e = it.next();
      if (frameCount - e.getValue() >= window) {
        out.add(e.getKey());
        it.remove();
      }
    }
    return out;
  }
}

class ChordRule {
  String a, b, result;
  ChordRule(String a, String b, String r) { this.a = a; this.b = b; this.result = r; }
}
