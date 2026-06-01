# Venue Network Setup — Beginner's Guide

Written for someone who doesn't do networking. Goal: get audience phones
watching the live stream at a venue, reliably, **without depending on the
venue's WiFi or the internet at all.**

---

## The one big idea

The visualizer's stream **never goes over the internet.** The streaming server
(MediaMTX) runs *on your laptop*. Phones and TVs watch by connecting straight to
your laptop over a local network ("LAN" = Local Area Network — just the devices
near each other, talking directly).

So the question is never "is the internet fast enough?" It's: **"can the phones
reach the laptop?"** That's a local-network question, and it's the whole game.

Confirmed in the code: `stream.html` uses `iceServers: []` — meaning "LAN only,
no internet helper server needed." Good.

---

## Why the venue's own WiFi will probably fail you

It's tempting to just join the venue WiFi on the laptop and tell people to do the
same. Three reasons that bites you:

1. **Client isolation (the big one).** Most venue / café / "guest" WiFi is
   configured so devices *can't talk to each other* — only to the internet. This
   is a security default. Result: your phone and the laptop are both "on the
   WiFi" but the phone literally cannot reach the laptop. The stream just won't
   load, and there's nothing you can change on their router to fix it.
2. **Congestion.** You're sharing the air with every patron's phone, the till,
   the card machine, etc. Unpredictable.
3. **No control.** It's their equipment. You can't tune it, can't debug it, and
   it might change between soundcheck and showtime.

**Conclusion: don't use the venue's WiFi for the stream. Bring your own.**

---

## The fix: bring your own little network

You create a private network that only your gear uses. The laptop and the
audience phones all join *your* network. No internet involved, so it doesn't
matter if the venue's internet is slow, locked, or dead.

### Option A — Your own travel router (RECOMMENDED)

A small WiFi router you carry in your bag. It makes its own WiFi network (its own
"SSID" = the network name people pick from the list).

**Setup:**
1. Plug the router into power.
2. Connect the **laptop to the router with an ethernet cable** (the wired
   network port). Wired = the most stable possible link for the server. If the
   laptop has no ethernet port, a cheap USB-to-ethernet adapter works.
3. The router broadcasts its WiFi. Audience phones join *that* WiFi network.
4. Everyone's now on your private LAN. Stream works.

**Why this is best:** you control it, it's wired to the laptop, no isolation
problem, no internet needed.

### Option B — Laptop hotspot (works, but weaker)

Your laptop can broadcast its *own* WiFi network ("hotspot" / "mobile hotspot"
in the OS settings). Phones join the laptop directly.

**Downsides:** a laptop in hotspot mode handles fewer phones and has shorter
range than a real router. Also the laptop's WiFi chip is now busy *being* the
network, so it can't also be on the venue's internet at the same time (unless you
give the laptop internet via ethernet, freeing the WiFi for the hotspot).

Use this as a backup if you forgot the router.

---

## How phones actually open the stream

Once they're on your network, they open a web address in their phone browser —
something like `http://192.168.1.50:8080/stream.html` (the laptop's address on
*your* network; the sketch prints the exact URL in its on-screen HUD when
streaming is on).

- That long number is the laptop's "LAN IP" — its house number on your local
  network. With your own router it stays the same each time, so you can prepare
  ahead.
- **Make a QR code** of that URL and put it on a sign/screen. Nobody wants to
  type it. (Any free "URL to QR" website; do it once you know the address.)

---

## Scaling: how many phones can watch?

Important gotcha: **every viewer gets their own separate copy of the stream sent
from the laptop.** It's not one broadcast shared by all — it's 1 stream per
phone. So 20 phones = 20× the data leaving the laptop.

- 20 phones × VENUE profile (~1.5 Mbit each) ≈ 30 Mbit/s out of the laptop.
  Fine for a decent modern router, but know the limit.
- **Cheap travel routers choke around 10–20 connected devices.** Big crowd? Get
  a better router / access point.
- This is a second reason to run the **VENUE stream profile** (lower bitrate):
  it's lighter per phone, so more phones fit before things buckle. (In the
  sketch: `Shift+F6`/`Shift+F7` switches to VENUE; or the `.devstream` file set
  to `venue` starts in it.)

---

## Preflight checklist (do this BEFORE doors open)

- [ ] Router powered on, laptop connected to it by ethernet.
- [ ] Laptop on the router's WiFi network (or wired only — wired is fine).
- [ ] Phone joined the **same** (your) network — NOT the venue WiFi.
- [ ] Start the stream in the sketch (F6). Note the URL in the HUD.
- [ ] Open that URL on your own phone → confirm you see + hear the visualizer.
- [ ] Try a *second* phone at the same time → still works (proves it's not a
      fluke and the network handles multiple viewers).
- [ ] Switch to VENUE profile (`Shift+F6`) and re-check it still looks OK.
- [ ] Generate a QR code of the URL, put it where the audience can scan it.
- [ ] Walk to the far side of the room with a phone → still connects? (range
      check). If not, move the router higher / more central.

---

## Firewall & ports (the "it works for me but not their phone" trap)

Even on your own router, the **laptop's own firewall** can silently block
phones. The stream works when you test it on the laptop itself (that's
"localhost", which firewalls always allow), then fails from every phone. If
you've ruled out the network and it still won't connect, this is almost always
why.

**What the laptop needs to accept incoming connections on:**

| Port | Protocol | What it's for |
|------|----------|---------------|
| 8080 | TCP | The control panel + stream web pages + WebSocket (may walk to 8081… if 8080 is taken — watch the startup log) |
| 8889 | TCP + **UDP** | WebRTC (the low-latency stream). UDP matters — if only TCP is open, WebRTC silently fails and only HLS works |
| 8888 | TCP | HLS (the universal fallback stream; survives weak WiFi) |
| 8554 | TCP | RTSP (internal hand-off to MediaMTX; can stay laptop-only, but harmless to allow) |

**Open them (run once, on the laptop):**

- **Linux (ufw):**
  ```bash
  sudo ufw allow 8080/tcp
  sudo ufw allow 8889
  sudo ufw allow 8888/tcp
  ```
- **Windows:** when you first run the sketch, Windows pops up "Allow access?" —
  tick **Private networks** and allow. If you clicked Block once, undo it in
  *Windows Defender Firewall → Allow an app*.
- **macOS:** *System Settings → Network → Firewall* — either turn it off on your
  private network, or allow the Processing/Java app when prompted.

**The startup log tells you the right address.** When the panel starts it now
prints every address it found, **best first**, like:

```
[FEATUREFLAGS]   ★ open phones here → http://192.168.1.50:8080/   [eth0 — LAN — open phones here]
[FEATUREFLAGS]     also: http://172.17.0.1:8080/   [docker0 — virtual/VPN — phones CAN'T reach this]
```

Use the **★ one**. If you instead see `⚠ NO LAN ADDRESS FOUND`, the laptop isn't
on your router — fix that before touching anything else.

> **Why the ★ matters:** a laptop often has several addresses (your router,
> plus Docker/VPN/virtual ones). Only the real-LAN one is reachable by phones,
> and it's the one the QR code should point to.

---

## Glossary (plain words)

- **LAN** — the little group of devices near each other talking directly. Your
  private network.
- **SSID** — the WiFi network *name* you see in the list when joining WiFi.
- **Router / Access Point (AP)** — the box that makes a WiFi network.
- **Ethernet** — a network *cable*. The most reliable connection; no radio.
- **LAN IP** — a device's address *inside* your local network, like
  `192.168.x.x`. The laptop's LAN IP is what phones type/scan to reach it.
- **Client isolation / AP isolation** — a WiFi setting that stops devices on the
  same network from reaching each other. The thing that breaks venue WiFi for
  us.
- **Unicast** — one separate copy of data per receiver (vs. one shared
  broadcast). Why N phones = N× the laptop's upload.
- **STUN server** — an internet helper some video chats need to find each other.
  We *don't* use one (`iceServers: []`), which is exactly why we stay fully
  local.

---

## TL;DR

Get a small router. Cable the laptop to it. Audience joins *your* WiFi, not the
venue's. Run VENUE profile. QR the URL. The venue's internet can be completely
dead and it all still works.
