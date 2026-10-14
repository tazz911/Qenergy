"""EnergyIQ meter simulator — pretends to be real smart meters.

Sends a reading for each device every few seconds to Supabase, exactly the way
the real ESP32 / smart meter will (POST /rest/v1/rpc/ingest_reading).

How to use:
  1. In the app add a zone, then add a device in that zone.
  2. Tap the device → copy its Serial and API key.
  3. Run:
       python tools/meter_simulator.py --device SERIAL:API_KEY
     More devices:  --device ESP32-001:key1 --device ESP32-002:key2
     Faster:        --interval 2
     Test alerts:   --spike-every 20   (every 20th reading is an overload / bad voltage)
  Stop with Ctrl+C.

Needs only Python 3 (no extra packages).
"""
import argparse
import json
import math
import random
import time
import urllib.error
import urllib.request
from datetime import datetime

SUPABASE_URL = "https://pdhcblffmifxagfaduoj.supabase.co"
PUBLISHABLE_KEY = "sb_publishable_sOYLPyexKVTdihRxVGjI9Q_IB2EuENh"


def send(serial, api_key, voltage, current, power, energy_kwh, pf):
    body = json.dumps({
        "p_serial": serial, "p_api_key": api_key,
        "p_voltage": round(voltage, 2), "p_current": round(current, 3),
        "p_power": round(power, 2), "p_energy_kwh": round(energy_kwh, 5),
        "p_power_factor": round(pf, 3),
    }).encode()
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/rpc/ingest_reading", data=body, method="POST",
        headers={"apikey": PUBLISHABLE_KEY, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=10) as res:
        return res.read().decode()


def typical_current(base_amps):
    """Daily pattern: low at night, peak in the afternoon (like air-conditioning in Oman)."""
    hour = datetime.now().hour + datetime.now().minute / 60
    daily = 0.55 + 0.45 * math.sin((hour - 9) / 24 * 2 * math.pi)
    return max(0.3, base_amps * daily * random.uniform(0.9, 1.1))


def main():
    ap = argparse.ArgumentParser(description="EnergyIQ smart meter simulator")
    ap.add_argument("--device", action="append", required=True, help="SERIAL:API_KEY (repeat for more devices)")
    ap.add_argument("--interval", type=float, default=5, help="seconds between readings (default 5)")
    ap.add_argument("--spike-every", type=int, default=0, help="every Nth reading is abnormal (0 = never)")
    args = ap.parse_args()

    devices = []
    for d in args.device:
        if ":" not in d:
            ap.error(f"--device must look like SERIAL:API_KEY, got {d!r}")
        serial, key = d.split(":", 1)
        devices.append({"serial": serial.strip(), "key": key.strip(), "base": random.uniform(6, 14)})

    print(f"Sending readings for {len(devices)} device(s) every {args.interval}s. Ctrl+C to stop.")
    n = 0
    while True:
        n += 1
        for dev in devices:
            voltage = random.gauss(230, 1.5)
            current = typical_current(dev["base"])
            pf = random.uniform(0.88, 0.98)
            label = ""
            if args.spike_every and n % args.spike_every == 0:
                kind = random.choice(["overload", "voltage_low", "voltage_high"])
                if kind == "overload":
                    current = random.uniform(22, 30)
                elif kind == "voltage_low":
                    voltage = random.uniform(195, 205)
                else:
                    voltage = random.uniform(252, 260)
                label = f"  <-- test {kind}"
            power = voltage * current * pf                     # W
            energy_kwh = power * args.interval / 3600 / 1000   # energy since last reading
            try:
                send(dev["serial"], dev["key"], voltage, current, power, energy_kwh, pf)
                print(f"{datetime.now():%H:%M:%S} {dev['serial']}: {voltage:6.1f} V {current:5.2f} A {power/1000:5.2f} kW{label}")
            except urllib.error.HTTPError as e:
                print(f"{dev['serial']}: rejected ({e.code}) {e.read().decode()[:200]}")
            except Exception as e:  # network problem — keep trying
                print(f"{dev['serial']}: network error {e}")
        time.sleep(args.interval)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nStopped.")
