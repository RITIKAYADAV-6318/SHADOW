document.getElementById("go").addEventListener("click", async () => {
  const s = document.getElementById("status");
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    stream.getTracks().forEach((t) => t.stop());
    s.textContent = "Granted. Close this tab and use the side panel.";
  } catch (e) {
    s.textContent = "Failed: " + e.name + " - " + e.message;
  }
});