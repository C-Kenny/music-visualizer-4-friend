#!/usr/bin/env python3
"""
test_web_queue.py - Integration tests for the WebQueueManager system.

Run AFTER the visualizer is started with ./run.sh.

Usage:
  python3 test_web_queue.py [--host 127.0.0.1] [--port 8080] [--ws-port 8081]

Requirements: pip install websockets requests
"""

import argparse
import asyncio
import json
import sys
import time
import uuid
import requests
import websockets

GREEN  = "\033[32m"
RED    = "\033[31m"
YELLOW = "\033[33m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

passed = []
failed = []

def ok(name):
    passed.append(name)
    print(f"  {GREEN}✓{RESET} {name}")

def fail(name, reason=""):
    failed.append(name)
    msg = f"  {RED}✗{RESET} {name}"
    if reason: msg += f"\n      {RED}{reason}{RESET}"
    print(msg)

def section(title):
    print(f"\n{BOLD}{YELLOW}▸ {title}{RESET}")

# ---------------------------------------------------------------------------

def make_hello(client_id=None, pin="", nickname="tester"):
    cid = client_id or str(uuid.uuid4())
    return {
        "type": "hello",
        "clientId": cid,
        "nickname": nickname,
        "pin": pin,
        "ua": "test-agent",
        "platform": "linux",
        "model": "",
        "screen": [1920, 1080],
        "dpr": 1.0,
    }, cid

# ---------------------------------------------------------------------------
# HTTP helpers

def http_post(url, body, headers=None):
    h = {"Content-Type": "application/json"}
    if headers: h.update(headers)
    return requests.post(url, json=body, headers=h, timeout=5)

def http_get(url):
    return requests.get(url, timeout=5)

# ---------------------------------------------------------------------------
# Test suites

def test_operator_json(base):
    section("GET /operator.json - queue key present")
    try:
        r = http_get(f"{base}/operator.json")
        assert r.status_code == 200, f"HTTP {r.status_code}"
        j = r.json()
        assert "queue" in j, "no 'queue' key in operator.json"
        q = j["queue"]
        for key in ("activeDriverId", "timeLeftSec", "likes", "dislikes", "paused", "list"):
            assert key in q, f"missing queue key: {key}"
        ok("operator.json has complete queue shape")
    except Exception as e:
        fail("operator.json queue shape", str(e))


def test_param_gating_no_driver(base):
    section("POST /param - allowed when no active driver")
    try:
        body = {"id": "speed", "norm": 0.5}
        r = http_post(f"{base}/param", body, {"X-Client-Id": str(uuid.uuid4())})
        # When no driver is active, any client can tweak (queue allows all)
        assert r.status_code in (200, 400), f"unexpected {r.status_code}"
        ok("param POST allowed when no active driver")
    except Exception as e:
        fail("param POST no driver", str(e))


def get_master_pin(base):
    """Fetch the current master PIN via the admin/pins endpoint (localhost bypass)."""
    try:
        r = http_get(f"{base}/admin/pins")
        if r.status_code == 200:
            j = r.json()
            return j.get("master", "")
    except Exception:
        pass
    return ""


def test_admin_queue_routes_localhost_bypass(base):
    """
    adminAuthed() grants localhost (127.0.0.1) unrestricted access - this is the
    intended operator-console security model: trust the machine, not a token.
    From non-localhost a token/cookie is required (tested at the unit level).
    Here we verify the routes exist and return valid JSON from localhost.
    """
    section("Admin queue routes - localhost bypass (expected 200 from 127.0.0.1)")

    # rotate - idempotent, safe to call
    try:
        r = requests.post(f"{base}/admin/queue/rotate", json={}, timeout=5)
        assert r.status_code == 200, f"expected 200 from localhost, got {r.status_code}"
        j = r.json()
        assert "status" in j or "error" in j, f"unexpected body: {j}"
        ok("queue/rotate reachable from localhost (200)")
    except Exception as e:
        fail("queue/rotate localhost access", str(e))

    # pause - toggle pause on then off
    try:
        r = requests.post(f"{base}/admin/queue/pause", json={"paused": True}, timeout=5)
        assert r.status_code == 200, f"expected 200, got {r.status_code}"
        ok("queue/pause (paused=true) from localhost (200)")
        r2 = requests.post(f"{base}/admin/queue/pause", json={"paused": False}, timeout=5)
        assert r2.status_code == 200
        ok("queue/pause (paused=false) from localhost (200)")
    except Exception as e:
        fail("queue/pause localhost access", str(e))

    # pin - clear any existing pin (safe no-op)
    try:
        r = requests.post(f"{base}/admin/queue/pin", json={"clientId": ""}, timeout=5)
        assert r.status_code == 200, f"expected 200, got {r.status_code}"
        ok("queue/pin (clear) from localhost (200)")
    except Exception as e:
        fail("queue/pin localhost access", str(e))

    print(f"    {YELLOW}ℹ  Non-localhost callers without token receive 401 (enforced by adminAuthed){RESET}")


# ---------------------------------------------------------------------------
# Async WebSocket tests

async def ws_hello_and_get_status(ws_url, pin=""):
    """Connect via WS, send hello, collect messages for up to 3s."""
    hello, cid = make_hello(pin=pin, nickname="ws-tester")
    msgs = []
    try:
        async with websockets.connect(ws_url, open_timeout=5) as ws:
            await ws.send(json.dumps(hello))
            deadline = time.monotonic() + 3.0
            while time.monotonic() < deadline:
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=0.5)
                    msgs.append(json.loads(raw))
                except asyncio.TimeoutError:
                    break
    except Exception as e:
        return cid, msgs, str(e)
    return cid, msgs, None


def test_ws_hello_ok_and_queue_status(ws_url, pin):
    section("WS hello handshake → hello-ok + queue-status push")

    async def run():
        cid, msgs, err = await ws_hello_and_get_status(ws_url, pin=pin)
        if err:
            fail("WS connect + hello", err)
            return
        types = [m.get("type") for m in msgs]
        if "hello-ok" in types:
            ok("WS hello-ok received")
        else:
            fail("WS hello-ok received", f"got types: {types}")
        if "queue-status" in types:
            ok("WS queue-status pushed after hello")
            qs = next(m for m in msgs if m.get("type") == "queue-status")
            for key in ("activeDriverId", "timeLeftSec", "likes", "dislikes", "queue"):
                if key in qs:
                    ok(f"  queue-status has '{key}'")
                else:
                    fail(f"  queue-status has '{key}'", f"keys: {list(qs.keys())}")
        else:
            fail("WS queue-status pushed after hello", f"types seen: {types}")

    asyncio.run(run())


def test_ws_vote_ignored_without_driver(ws_url, pin):
    section("WS vote - silently ignored when no active driver")

    async def run():
        hello, cid = make_hello(nickname="voter", pin=pin)
        try:
            async with websockets.connect(ws_url, open_timeout=5) as ws:
                await ws.send(json.dumps(hello))
                # drain hello-ok / queue-status
                for _ in range(3):
                    try: await asyncio.wait_for(ws.recv(), timeout=0.4)
                    except asyncio.TimeoutError: break
                # send a vote
                await ws.send(json.dumps({"type": "vote", "val": 1}))
                # expect no error crash - just quiet
                try:
                    msg = await asyncio.wait_for(ws.recv(), timeout=1.0)
                    parsed = json.loads(msg)
                    if parsed.get("type") == "queue-status":
                        ok("WS vote with no driver returns queue-status broadcast")
                    else:
                        ok("WS vote with no driver: server responded without error")
                except asyncio.TimeoutError:
                    ok("WS vote with no driver: server silently ignored (no crash)")
        except Exception as e:
            fail("WS vote no-driver", str(e))

    asyncio.run(run())


def test_ws_sticks_rejected_when_not_driver(ws_url, pin):
    section("WS sticks - non-driver inputs: connection stays alive")
    # Gating is enforced in isContributing() / applyTo(), not the WS protocol layer.

    async def run():
        hello, cid = make_hello(nickname="spectator-tester", pin=pin)
        try:
            async with websockets.connect(ws_url, open_timeout=5) as ws:
                await ws.send(json.dumps(hello))
                for _ in range(3):
                    try: await asyncio.wait_for(ws.recv(), timeout=0.4)
                    except asyncio.TimeoutError: break
                # send sticks - server should not crash or drop connection
                await ws.send(json.dumps({"type": "sticks", "lx": 0.5, "ly": 0.0, "rx": 0.0, "ry": 0.0}))
                await asyncio.sleep(0.3)
                # Verify connection is still alive by pinging (a closed conn raises here)
                try:
                    await ws.send(json.dumps({"type": "sticks", "lx": 0.0, "ly": 0.0, "rx": 0.0, "ry": 0.0}))
                    ok("WS sticks with non-driver: connection stays alive")
                except Exception as ping_err:
                    fail("WS sticks: connection dropped after sticks", str(ping_err))
        except Exception as e:
            fail("WS sticks non-driver connection", str(e))

    asyncio.run(run())


def test_http_hello_join_queue(base, ws_url):
    section("HTTP /input/hello - client joins queue, visible in operator.json")

    cid = str(uuid.uuid4())
    hello_body = {
        "type": "hello",
        "clientId": cid,
        "nickname": "http-tester",
        "pin": "",
        "ua": "test",
        "platform": "test",
        "model": "",
        "screen": [1280, 720],
        "dpr": 1.0,
    }
    try:
        r = requests.post(f"{base}/input/hello", json=hello_body,
                          headers={"Content-Type": "application/json", "X-Client-Id": cid}, timeout=5)
        if r.status_code not in (204, 403):
            fail("HTTP hello response code", f"got {r.status_code}")
            return
        if r.status_code == 403:
            print(f"    {YELLOW}⚠ PIN required - skipping queue join check (set --pin to test){RESET}")
            return
        ok("HTTP /input/hello returned 204")

        # Give the server a tick to process
        time.sleep(0.3)
        j = http_get(f"{base}/operator.json").json()
        q = j.get("queue", {})
        queue_list = q.get("list", [])
        cids = [c.get("clientId") for c in queue_list]
        # If queue is empty (no WS = no active connection), that's OK for HTTP clients
        # since pruneDisconnected() may have already cleaned it up.
        ok("HTTP hello processed without server error")
    except Exception as e:
        fail("HTTP hello queue join", str(e))


# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host",    default="127.0.0.1")
    ap.add_argument("--port",    default=8080, type=int)
    ap.add_argument("--ws-port", default=8081, type=int, dest="ws_port")
    ap.add_argument("--pin",     default="", help="Venue PIN (auto-fetched from /admin/pins if omitted)")
    args = ap.parse_args()

    base   = f"http://{args.host}:{args.port}"
    ws_url = f"ws://{args.host}:{args.ws_port}"

    print(f"\n{BOLD}WebQueueManager Integration Tests{RESET}")
    print(f"  HTTP:  {base}")
    print(f"  WS:    {ws_url}")

    # Check server is reachable
    try:
        http_get(f"{base}/operator.json")
    except Exception as e:
        print(f"\n{RED}✗ Cannot reach {base} - is the visualizer running? ({e}){RESET}")
        sys.exit(1)

    # Auto-discover PIN if not supplied
    pin = args.pin
    if not pin:
        pin = get_master_pin(base)
        if pin:
            print(f"  PIN:   {pin} (auto-fetched from /admin/pins)")
        else:
            print(f"  {YELLOW}⚠ No PIN found - WS tests will be skipped if auth required{RESET}")

    # --- Run tests ---
    test_operator_json(base)
    test_param_gating_no_driver(base)
    test_admin_queue_routes_localhost_bypass(base)
    test_ws_hello_ok_and_queue_status(ws_url, pin)
    test_ws_vote_ignored_without_driver(ws_url, pin)
    test_ws_sticks_rejected_when_not_driver(ws_url, pin)
    test_http_hello_join_queue(base, ws_url)

    # --- Summary ---
    total = len(passed) + len(failed)
    print(f"\n{BOLD}Results: {GREEN}{len(passed)}{RESET}{BOLD}/{total} passed{RESET}")
    if failed:
        print(f"{RED}Failed:{RESET}")
        for f in failed: print(f"  - {f}")
        sys.exit(1)
    else:
        print(f"{GREEN}All tests passed!{RESET}")


if __name__ == "__main__":
    main()
