// Clicking the toolbar icon opens the side panel.
chrome.runtime.onInstalled.addListener(() => {
  chrome.sidePanel
    .setPanelBehavior({ openPanelOnActionClick: true })
    .catch((e) => console.error(e));
});

// Keyboard shortcut. sidePanel.open() must run inside the user gesture, so call it
// FIRST and synchronously, using the window id Chrome hands us (no await before it).
chrome.commands.onCommand.addListener((command, tab) => {
  if (command !== "toggle-listen") return;
  if (tab && tab.windowId !== undefined) {
    chrome.sidePanel
      .open({ windowId: tab.windowId })
      .catch((e) => console.warn("sidePanel.open failed (click the icon once instead):", e));
  } else {
    console.warn("no tab passed to the command; click the icon once to open the panel");
  }
  // Give the panel a moment to load, then ask it to toggle listening.
  setTimeout(() => {
    chrome.runtime.sendMessage({ type: "toggle-listen" }).catch(() => {});
  }, 400);
});

// Test: can chrome.tts speak from the background with the panel CLOSED?
chrome.runtime.onMessage.addListener((msg) => {
  if (msg && msg.type === "bg-tts-in-5s") {
    setTimeout(() => {
      chrome.tts.speak("This voice came from the background, with the panel closed.");
    }, 5000);
  }
});