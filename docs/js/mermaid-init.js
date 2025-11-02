document.addEventListener("DOMContentLoaded", function () {
    if (window.mermaid) {
      mermaid.initialize({
        startOnLoad: true,
        securityLevel: "strict", // safe default for untrusted diagrams
      });
    }
  });
  