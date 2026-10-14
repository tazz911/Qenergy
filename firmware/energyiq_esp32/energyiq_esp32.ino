// EnergyIQ — ESP32 smart meter firmware
// CAT B Module 1 (Edge Device Configuration) + Module 2 (Multi-Zone Energy Monitoring)
//
//   M1F1  WiFi configuration (SSID / password)   -> Serial Monitor commands, or the
//                                                   "EnergyIQ-Setup" hotspot page (real board)
//   M1F2  Settings saved in flash (NVS)          -> Preferences library, survives power off
//   M1F3  Auto reconnect to WiFi                 -> on power restart + retries when WiFi drops
//   M1F4  Factory reset                          -> hold the BOOT button (GPIO 0) for 5 s, or type "reset"
//   M2F1  Multi-zone voltage measurement         -> 1 voltage sensor (ZMPT101B), shared by all zones
//   M2F2  Multi-zone current measurement         -> 1 CT clamp (SCT-013) per zone, up to 3 zones
//
// Each zone is one device in the EnergyIQ app (its own serial + API key). Every 5 s the
// ESP32 sends each zone's reading to Supabase (POST /rest/v1/rpc/ingest_reading), the same
// call the Python fake meter uses. The database adds the timestamp and raises the alerts.
//
// WOKWI 1 = run in the Wokwi simulator: the sliders stand in for the sensors.
// WOKWI 0 = real ESP32 with real sensors (calibrate V_CAL / I_CAL below).
#define WOKWI 1

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <Preferences.h>
#if !WOKWI
#include <WebServer.h>
#include <DNSServer.h>
#endif

// ── Cloud (same publishable key as the app — safe to ship, Row Level Security protects data) ──
const char* SUPABASE_URL = "https://pdhcblffmifxagfaduoj.supabase.co";
const char* SUPABASE_KEY = "sb_publishable_sOYLPyexKVTdihRxVGjI9Q_IB2EuENh";

// ── Pins (ADC1 only — ADC2 does not work while WiFi is on) ──
const int MAX_ZONES = 3;
const int VOLT_PIN = 34;
const int CURRENT_PINS[MAX_ZONES] = {35, 32, 33};
const int BUTTON_PIN = 0;   // BOOT button on the ESP32 board
const int LED_PIN = 2;      // blue LED on most ESP32 boards

// ── Timing ──
const unsigned long SEND_INTERVAL_MS = 5000;
const unsigned long WIFI_RETRY_MS = 10000;
const unsigned long RESET_HOLD_MS = 5000;

// ── Real sensor calibration (WOKWI 0 only). Check with a multimeter / clamp meter and adjust. ──
const float V_CAL = 0.30f;                    // ADC counts -> volts (depends on the ZMPT101B trim pot)
const float I_CAL = 3.3f / 4095.0f * 30.0f;   // SCT-013-030: 30 A gives 1 V -> counts -> amps
const float I_NOISE = 0.05f;                  // below this the clamp reads 0 A

// ── Settings saved in flash ──
struct Config {
  String ssid, pass;
  String serial[MAX_ZONES], key[MAX_ZONES];
} cfg;
Preferences prefs;

// One measurement of one zone (declared up here: Arduino puts function prototypes above the code).
struct Reading { float voltage, current, power, pf; };

bool setupMode = false;          // no WiFi saved yet
bool wasConnected = false;
unsigned long lastWifiTry = 0, lastSend = 0, buttonDown = 0;
int wifiTries = 0;
bool buttonWarned = false;
unsigned long lastSentAt[MAX_ZONES] = {0};
double pendingKwh[MAX_ZONES] = {0};   // energy not yet accepted by the cloud (kept if WiFi is down)
String lineBuf;

// ───────────────────────────── Flash (M1F2) ─────────────────────────────
void loadConfig() {
  prefs.begin("energyiq", false);
  cfg.ssid = prefs.getString("ssid", "");
  cfg.pass = prefs.getString("pass", "");
  for (int z = 0; z < MAX_ZONES; z++) {
    cfg.serial[z] = prefs.getString(("s" + String(z)).c_str(), "");
    cfg.key[z] = prefs.getString(("k" + String(z)).c_str(), "");
  }
  prefs.end();
}

void saveConfig() {
  prefs.begin("energyiq", false);
  prefs.putString("ssid", cfg.ssid);
  prefs.putString("pass", cfg.pass);
  for (int z = 0; z < MAX_ZONES; z++) {
    prefs.putString(("s" + String(z)).c_str(), cfg.serial[z]);
    prefs.putString(("k" + String(z)).c_str(), cfg.key[z]);
  }
  prefs.end();
}

// M1F4: wipe everything and start again in setup mode.
void factoryReset() {
  Serial.println("\n*** FACTORY RESET: all settings erased from flash. Restarting... ***");
  prefs.begin("energyiq", false);
  prefs.clear();
  prefs.end();
  delay(1000);
  ESP.restart();
}

// ───────────────────────────── Input checks ─────────────────────────────
bool validSerial(const String& s) {
  if (s.length() < 1 || s.length() > 50) return false;
  for (char c : s) if (!isalnum(c) && c != '-' && c != '_') return false;
  return true;
}

bool validKey(const String& k) {   // API key is a UUID: 8-4-4-4-12 hex digits
  if (k.length() != 36) return false;
  for (int i = 0; i < 36; i++) {
    char c = k[i];
    if (i == 8 || i == 13 || i == 18 || i == 23) { if (c != '-') return false; }
    else if (!isxdigit(c)) return false;
  }
  return true;
}

int zoneCount() {
  int n = 0;
  for (int z = 0; z < MAX_ZONES; z++) if (cfg.serial[z].length()) n++;
  return n;
}

// ───────────────────────────── Serial setup (M1F1) ─────────────────────────────
void printHelp() {
  Serial.println("\nCommands (type and press Enter):");
  Serial.println("  ssid <wifi name>             set WiFi name");
  Serial.println("  pass <wifi password>         set WiFi password (just 'pass' = no password)");
  Serial.println("  zone <1-3> <serial> <apikey> link a zone to a device from the app");
  Serial.println("  zone <1-3> clear             remove a zone");
  Serial.println("  show                         show saved settings");
  Serial.println("  restart                      restart the ESP32 (settings stay in flash)");
  Serial.println("  reset                        factory reset (erase everything)");
  Serial.println("  help                         this list");
}

void printConfig() {
  Serial.println("\n--- Saved settings (flash) ---");
  Serial.printf("  WiFi name : %s\n", cfg.ssid.length() ? cfg.ssid.c_str() : "(not set)");
  Serial.printf("  WiFi pass : %s\n", cfg.pass.length() ? "********" : "(none)");
  for (int z = 0; z < MAX_ZONES; z++) {
    if (cfg.serial[z].length())
      Serial.printf("  Zone %d    : %s  key %s...  (CT clamp on GPIO %d)\n", z + 1,
                    cfg.serial[z].c_str(), cfg.key[z].substring(0, 8).c_str(), CURRENT_PINS[z]);
    else
      Serial.printf("  Zone %d    : (empty)\n", z + 1);
  }
  Serial.println("------------------------------");
}

void handleCommand(String line) {
  line.trim();
  if (!line.length()) return;
  int sp = line.indexOf(' ');
  String cmd = sp < 0 ? line : line.substring(0, sp);
  String arg = sp < 0 ? "" : line.substring(sp + 1);
  arg.trim();
  cmd.toLowerCase();

  if (cmd == "help") {
    printHelp();
  } else if (cmd == "show") {
    printConfig();
  } else if (cmd == "ssid") {
    if (!arg.length() || arg.length() > 32) { Serial.println("WiFi name must be 1-32 characters."); return; }
    cfg.ssid = arg; saveConfig();
    Serial.printf("OK - WiFi name saved: %s  (type 'restart' to connect)\n", arg.c_str());
  } else if (cmd == "pass") {
    if (arg.length() > 63) { Serial.println("Password is too long (max 63)."); return; }
    cfg.pass = arg; saveConfig();
    Serial.println(arg.length() ? "OK - WiFi password saved." : "OK - no WiFi password.");
  } else if (cmd == "zone") {
    int sp2 = arg.indexOf(' ');
    int z = (sp2 < 0 ? arg : arg.substring(0, sp2)).toInt() - 1;
    if (z < 0 || z >= MAX_ZONES) { Serial.println("Zone must be 1, 2 or 3."); return; }
    String rest = sp2 < 0 ? "" : arg.substring(sp2 + 1);
    rest.trim();
    if (rest == "clear") {
      cfg.serial[z] = ""; cfg.key[z] = ""; saveConfig();
      Serial.printf("OK - zone %d removed.\n", z + 1);
      return;
    }
    int sp3 = rest.indexOf(' ');
    String serial = sp3 < 0 ? rest : rest.substring(0, sp3);
    String key = sp3 < 0 ? "" : rest.substring(sp3 + 1);
    key.trim();
    if (!validSerial(serial)) { Serial.println("Bad serial. Use letters, numbers, - or _ (example ESP32-001)."); return; }
    if (!validKey(key)) { Serial.println("Bad API key. Copy it again from the app (36 characters)."); return; }
    cfg.serial[z] = serial; cfg.key[z] = key; saveConfig();
    lastSentAt[z] = 0; pendingKwh[z] = 0;
    Serial.printf("OK - zone %d = %s saved to flash.\n", z + 1, serial.c_str());
  } else if (cmd == "restart") {
    Serial.println("Restarting...");
    delay(500);
    ESP.restart();
  } else if (cmd == "reset") {
    factoryReset();
  } else {
    Serial.println("Unknown command. Type 'help'.");
  }
}

void readSerial() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') { handleCommand(lineBuf); lineBuf = ""; }
    else if (lineBuf.length() < 200) lineBuf += c;
  }
}

// ───────────────────────────── Setup hotspot page (M1F1, real board only) ─────────────────────────────
#if !WOKWI
WebServer server(80);
DNSServer dns;

String htmlEscape(const String& s) {
  String o;
  for (char c : s) {
    if (c == '<') o += "&lt;"; else if (c == '>') o += "&gt;";
    else if (c == '"') o += "&quot;"; else if (c == '&') o += "&amp;"; else o += c;
  }
  return o;
}

void handleRoot() {
  String h = F("<!doctype html><meta name=viewport content='width=device-width'>"
               "<title>EnergyIQ Setup</title><style>body{font-family:sans-serif;max-width:420px;margin:20px auto;padding:0 12px}"
               "input{width:100%;padding:8px;margin:4px 0 12px;box-sizing:border-box}button{padding:10px 20px}</style>"
               "<h2>EnergyIQ meter setup</h2><form method=post action=/save>"
               "<b>WiFi</b><br>Name<input name=ssid required maxlength=32 value='");
  h += htmlEscape(cfg.ssid) + "'>Password<input name=pass type=password maxlength=63>";
  for (int z = 0; z < MAX_ZONES; z++) {
    h += "<b>Zone " + String(z + 1) + "</b> (CT clamp on GPIO " + String(CURRENT_PINS[z]) + ")<br>";
    h += "Serial<input name=s" + String(z) + " maxlength=50 value='" + htmlEscape(cfg.serial[z]) + "'>";
    h += "API key<input name=k" + String(z) + " maxlength=36 value='" + htmlEscape(cfg.key[z]) + "'>";
  }
  h += F("<button>Save and restart</button></form>");
  server.send(200, "text/html", h);
}

void handleSave() {
  String ssid = server.arg("ssid");
  if (!ssid.length() || ssid.length() > 32) { server.send(400, "text/plain", "WiFi name must be 1-32 characters"); return; }
  for (int z = 0; z < MAX_ZONES; z++) {
    String s = server.arg("s" + String(z)), k = server.arg("k" + String(z));
    s.trim(); k.trim();
    if (s.length() && (!validSerial(s) || !validKey(k))) {
      server.send(400, "text/plain", "Zone " + String(z + 1) + ": bad serial or API key");
      return;
    }
    cfg.serial[z] = s; cfg.key[z] = s.length() ? k : "";
  }
  cfg.ssid = ssid;
  cfg.pass = server.arg("pass");
  saveConfig();
  server.send(200, "text/html", "<h3>Saved. The meter restarts and connects to your WiFi.</h3>");
  delay(1500);
  ESP.restart();
}

void startHotspot() {
  WiFi.mode(WIFI_AP);
  WiFi.softAP("EnergyIQ-Setup");
  dns.start(53, "*", WiFi.softAPIP());          // any website opens the setup page
  server.on("/", handleRoot);
  server.on("/save", HTTP_POST, handleSave);
  server.onNotFound(handleRoot);
  server.begin();
  Serial.printf("Setup hotspot 'EnergyIQ-Setup' is on. Connect your phone, then open http://%s\n",
                WiFi.softAPIP().toString().c_str());
}
#endif

// ───────────────────────────── WiFi (M1F3) ─────────────────────────────
void connectWifi() {
  wifiTries++;
  Serial.printf("Connecting to WiFi '%s' (try %d)...\n", cfg.ssid.c_str(), wifiTries);
  WiFi.disconnect();
#if WOKWI
  WiFi.begin(cfg.ssid.c_str(), cfg.pass.c_str(), 6);   // channel 6 = Wokwi-GUEST, skips the scan
#else
  WiFi.begin(cfg.ssid.c_str(), cfg.pass.c_str());
#endif
  lastWifiTry = millis();
}

void checkWifi() {
  bool up = WiFi.status() == WL_CONNECTED;
  if (up && !wasConnected) {
    Serial.printf("WiFi connected. IP %s\n", WiFi.localIP().toString().c_str());
    wifiTries = 0;
  } else if (!up && wasConnected) {
    Serial.println("WiFi lost - reconnecting by itself...");
    lastWifiTry = 0;
  }
  wasConnected = up;
  if (!up && millis() - lastWifiTry > WIFI_RETRY_MS) connectWifi();
}

// ───────────────────────────── Measurement (M2F1 + M2F2) ─────────────────────────────
#if WOKWI
// Sliders: voltage slider middle = 230 V (range 180-280 V), current sliders 0-30 A.
float slider(int pin) { return analogRead(pin) / 4095.0f; }

Reading measureZone(int z) {
  float v = (180.0f + slider(VOLT_PIN) * 100.0f) * (1 + random(-5, 6) / 1000.0f);
  float i = slider(CURRENT_PINS[z]) * 30.0f * (1 + random(-20, 21) / 1000.0f);
  float pf = i > 0 ? 0.90f + random(0, 81) / 1000.0f : 0;
  return {v, i, v * i * pf, pf};
}
#else
// Samples the shared voltage sensor and this zone's CT clamp together for 200 ms
// (10 mains cycles at 50 Hz). Sensors sit on a DC mid-point, so the AC part is
// worked out from the variance; real power comes from the V x I covariance.
Reading measureZone(int z) {
  const int pinI = CURRENT_PINS[z];
  double sv = 0, si = 0, svv = 0, sii = 0, svi = 0;
  long n = 0;
  unsigned long start = millis();
  while (millis() - start < 200) {
    double v = analogRead(VOLT_PIN), i = analogRead(pinI);
    sv += v; si += i; svv += v * v; sii += i * i; svi += v * i; n++;
  }
  double mv = sv / n, mi = si / n;
  double vrms = sqrt(max(0.0, svv / n - mv * mv)) * V_CAL;
  double irms = sqrt(max(0.0, sii / n - mi * mi)) * I_CAL;
  double p = (svi / n - mv * mi) * V_CAL * I_CAL;
  if (irms < I_NOISE) { irms = 0; p = 0; }
  double pf = (vrms > 0 && irms > 0) ? constrain(p / (vrms * irms), 0.0, 1.0) : 0;
  return {(float)vrms, (float)irms, (float)max(0.0, p), (float)pf};
}
#endif

// ───────────────────────────── Send to cloud ─────────────────────────────
// Returns the HTTP status (200 = saved). Readings are timestamped by the database.
int sendReading(int z, const Reading& r, double kwh) {
  WiFiClientSecure client;
  client.setInsecure();   // TODO for production: pin the Supabase root certificate
  HTTPClient http;
  http.setTimeout(8000);
  if (!http.begin(client, String(SUPABASE_URL) + "/rest/v1/rpc/ingest_reading")) return -1;
  http.addHeader("apikey", SUPABASE_KEY);
  http.addHeader("Content-Type", "application/json");
  char body[320];
  snprintf(body, sizeof body,
           "{\"p_serial\":\"%s\",\"p_api_key\":\"%s\",\"p_voltage\":%.2f,\"p_current\":%.3f,"
           "\"p_power\":%.2f,\"p_energy_kwh\":%.5f,\"p_power_factor\":%.3f}",
           cfg.serial[z].c_str(), cfg.key[z].c_str(), r.voltage, r.current, r.power, kwh, r.pf);
  int code = http.POST(body);
  if (code != 200) Serial.printf("  zone %d rejected (%d) %s\n", z + 1, code, http.getString().substring(0, 150).c_str());
  http.end();
  return code;
}

void measureAndSend() {
  bool online = WiFi.status() == WL_CONNECTED;
  for (int z = 0; z < MAX_ZONES; z++) {
    if (!cfg.serial[z].length()) continue;
    Reading r = measureZone(z);
    unsigned long now = millis();
    unsigned long dt = lastSentAt[z] ? now - lastSentAt[z] : SEND_INTERVAL_MS;
    lastSentAt[z] = now;
    pendingKwh[z] += r.power * dt / 3.6e9;   // W x ms -> kWh
    Serial.printf("Zone %d %-10s %6.1f V %6.2f A %6.2f kW", z + 1, cfg.serial[z].c_str(),
                  r.voltage, r.current, r.power / 1000);
    if (!online) { Serial.println("  (offline - kept, sent when WiFi is back)"); continue; }
    if (sendReading(z, r, pendingKwh[z]) == 200) { pendingKwh[z] = 0; Serial.println("  -> sent"); }
  }
}

// ───────────────────────────── Button + LED ─────────────────────────────
void checkButton() {
  if (digitalRead(BUTTON_PIN) == LOW) {
    if (!buttonDown) buttonDown = millis();
    unsigned long held = millis() - buttonDown;
    if (held > 300 && !buttonWarned) { Serial.println("Button held - keep holding 5 s for FACTORY RESET..."); buttonWarned = true; }
    if (held >= RESET_HOLD_MS) factoryReset();
  } else {
    if (buttonWarned) Serial.println("Button released - reset cancelled.");
    buttonDown = 0; buttonWarned = false;
  }
}

// Fast blink = setup mode, slow blink = connecting, steady on = online.
void updateLed() {
  if (setupMode) digitalWrite(LED_PIN, (millis() / 150) % 2);
  else if (WiFi.status() != WL_CONNECTED) digitalWrite(LED_PIN, (millis() / 600) % 2);
  else digitalWrite(LED_PIN, HIGH);
}

// ───────────────────────────── Main ─────────────────────────────
void setup() {
  Serial.begin(115200);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);
  analogReadResolution(12);
  delay(300);
  Serial.println("\n==============================");
  Serial.println("  EnergyIQ smart meter (ESP32)");
  Serial.println(WOKWI ? "  mode: Wokwi simulator (sliders = sensors)" : "  mode: real sensors");
  Serial.println("==============================");

  loadConfig();
  Serial.println("Settings loaded from flash.");
  printConfig();

  setupMode = cfg.ssid.length() == 0;
  if (setupMode) {
    Serial.println("\nSETUP MODE - no WiFi saved yet.");
#if WOKWI
    Serial.println("Type:  ssid Wokwi-GUEST   then   pass   then   zone 1 <serial> <apikey>   then   restart");
#else
    startHotspot();
#endif
    printHelp();
    return;
  }
  if (!zoneCount()) Serial.println("No zones yet - add one with: zone 1 <serial> <apikey>");
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  connectWifi();
  Serial.println("Type 'help' for commands. Hold BOOT 5 s = factory reset.");
}

void loop() {
  readSerial();
  checkButton();
  updateLed();
  if (setupMode) {
#if !WOKWI
    dns.processNextRequest();
    server.handleClient();
#endif
    return;
  }
  checkWifi();
  if (millis() - lastSend >= SEND_INTERVAL_MS) {
    lastSend = millis();
    measureAndSend();
  }
}
