const $ = (id) => document.getElementById(id);
const logEl = $("log");
const log = (m) => { logEl.textContent += m + "\n"; logEl.scrollTop = logEl.scrollHeight; };

// Test 15 first with false (does the mic hear the mentor?). If it transcribes itself, set true.
const STOP_TTS_ON_LISTEN = false;

const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
let rec = null;
let listening = false;
let wantListening = false;   // true from "start" until YOU press stop
let base = "";               // text kept from before an automatic restart
let tStop = 0;               // when you pressed stop (for the delay test)

if (!SR) {
  log("SpeechRecognition NOT available in this context.");
} else {
  rec = new SR();
  rec.lang = "en-IN";           // try "en-US" too if accuracy is poor
  rec.interimResults = true;
  rec.continuous = true;        // keep listening through pauses
  rec.onstart = () => { listening = true; $("mic").textContent = "⏹ Stop"; log("started"); };
  rec.onend = () => {
    listening = false;
    if (wantListening) {        // Chrome ended it, but I still want to listen
      base = $("text").value ? $("text").value + " " : "";
      try { rec.start(); log("auto-restarted"); return; } catch (e) { log("restart failed: " + e); }
    }
    wantListening = false;
    $("mic").textContent = "🎙 Start listening";
    log("ended");
  };
  rec.onerror = (e) => {
    log("ERROR: " + e.error + (e.message ? " - " + e.message : ""));
    // 'no-speech' and 'aborted' are normal; anything else stops the auto-restart loop
    if (e.error !== "no-speech" && e.error !== "aborted") wantListening = false;
  };
  rec.onresult = (e) => {
    let text = "";
    for (let i = 0; i < e.results.length; i++) text += e.results[i][0].transcript + " ";
    $("text").value = (base + text).trim();
    const last = e.results[e.results.length - 1];
    if (last.isFinal && tStop) {
      log("final text " + Math.round(performance.now() - tStop) + " ms after I pressed stop");
      tStop = 0;
    }
  };
}

function toggle() {
  if (!rec) return log("no recognizer");
  try {
    if (wantListening) {                 // second press = stop
      wantListening = false;
      tStop = performance.now();
      rec.stop();
      return;
    }
    if (STOP_TTS_ON_LISTEN) { chrome.tts.stop(); speechSynthesis.cancel(); }
    wantListening = true;
    base = "";
    $("text").value = "";
    rec.start();
  } catch (e) { log("toggle failed: " + e); wantListening = false; }
}

$("mic").addEventListener("click", toggle);

$("perm").addEventListener("click", () => {
  chrome.tabs.create({ url: chrome.runtime.getURL("mic-permission.html") });
});

$("tts").addEventListener("click", () => {
  chrome.tts.speak("Hello. This is your mentor. Try a hint when you are stuck.", { rate: 1.0 });
  log("chrome.tts requested");
});

// speechSynthesis is the other option; also list the English voices (click twice if empty).
$("synth").addEventListener("click", () => {
  const voices = speechSynthesis.getVoices();
  log("English voices: " + (voices.filter((v) => v.lang.startsWith("en"))
    .map((v) => v.name + " (" + v.lang + ")").join(", ") || "none loaded yet, click again"));
  const u = new SpeechSynthesisUtterance("Hello. This is speech synthesis. Try a hint when you are stuck.");
  const indian = voices.find((v) => v.lang === "en-IN");
  if (indian) u.voice = indian;
  speechSynthesis.speak(u);
  log("speechSynthesis requested" + (indian ? " with " + indian.name : " (no en-IN voice found)"));
});

// Ask the background to speak in 5 s; close this panel to prove it works without it.
$("bgtts").addEventListener("click", () => {
  chrome.runtime.sendMessage({ type: "bg-tts-in-5s" });
  log("close this panel now; you should hear a voice in about 5 s");
});

// Fallback test: the same page as a small popup window.
$("popup").addEventListener("click", () => {
  chrome.windows.create({ url: chrome.runtime.getURL("sidepanel.html"), type: "popup", width: 380, height: 620 });
});

chrome.runtime.onMessage.addListener((msg) => {
  if (msg && msg.type === "toggle-listen") { log("shortcut received"); toggle(); }
});

// Experimental: is on-device recognition available for en-IN in this Chrome version?
if (SR && SR.available) {
  SR.available({ langs: ["en-IN"], processLocally: true })
    .then((r) => log("on-device recognition (en-IN): " + r))
    .catch((e) => log("on-device check failed: " + e));
} else {
  log("on-device recognition API not present in this Chrome version");
}

log("panel loaded; SpeechRecognition available: " + !!SR);