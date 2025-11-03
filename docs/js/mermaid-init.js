document.addEventListener("DOMContentLoaded", function () {
    if (window.mermaid) {
      mermaid.initialize({
        startOnLoad: true,
        securityLevel: "loose", // safe default for untrusted diagrams
      });
    }
  });
  