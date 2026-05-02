(function() {
  /* ---------- helpers ---------- */
  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&")
      .replace(/</g, "<")
      .replace(/>/g, ">");
  }

  function detectLanguage(code) {
    if (code.indexOf("<-") !== -1 || code.indexOf("->") !== -1 ||
        code.indexOf("library(") !== -1 || code.indexOf("require(") !== -1) {
      return "r";
    }
    return "text";
  }

  function renderCode(text) {
    var parts = text.split(/(```\w*\n?[\s\S]*?```)/g);
    var html = "";
    for (var i = 0; i < parts.length; i++) {
      var block = parts[i];
      var m = block.match(/^```(\w*)/);
      if (m) {
        var lang = m[1] || detectLanguage(block);
        var inner = block.replace(/^```\w*\n?/, "").replace(/\s*```\s*$/, "");
        var escaped = escapeHtml(inner);
        var langLabel = lang === "r" ? "R" : (lang ? lang.toUpperCase() : "CODE");
        var runBtn = lang === "r"
          ? "<button class='btn-run-code' data-code='" + encodeURIComponent(inner) + "'>Run</button>"
          : "";
        html += "<pre><div class='code-header'><span class='code-lang'>" + langLabel +
                "</span>" + runBtn + "</div><code>" + escaped + "</code></pre>";
      } else {
        var inline = escapeHtml(block);
        inline = inline.replace(/`([^`]+)`/g, "<code>$1</code>");
        inline = inline.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
        inline = inline.replace(/\*([^*]+)\*/g, "<em>$1</em>");
        inline = inline.replace(/^### (.+)$/gm, "<h4>$1</h4>");
        inline = inline.replace(/^## (.+)$/gm, "<h3>$1</h3>");
        inline = inline.replace(/^# (.+)$/gm, "<h2>$1</h2>");
        inline = inline.replace(/^- (.+)$/gm, "<li>$1</li>");
        inline = inline.replace(/(<li>.*<\/li>)/s, "<ul>$1</ul>");
        inline = inline.replace(/\n/g, "<br>");
        if (inline.trim()) html += "<p>" + inline + "</p>";
      }
    }
    return html;
  }

  function scrollBottom() {
    var c = document.getElementById("msg_container");
    if (c) c.scrollTop = c.scrollHeight;
  }

  function appendMsg(role, html) {
    var container = document.getElementById("msg_container");
    if (!container) return;
    var empty = document.getElementById("empty_state");
    if (empty) empty.remove();
    var av = role === "user" ? "Y" :
             role === "error" ? "!" : "AI";
    var el = document.createElement("div");
    el.className = "msg " + role;
    el.innerHTML =
      "<div class='msg-avatar'>" + av + "</div>" +
      "<div class='msg-body'>" + html + "</div>";
    container.appendChild(el);
    scrollBottom();
  }

  function showThinking(show) {
    var wrap = document.getElementById("thinking_wrap");
    if (!wrap) return;
    wrap.style.display = show ? "flex" : "none";
  }

  function setInputEnabled(enabled) {
    var inp = document.getElementById("chat_input");
    var btn = document.getElementById("btn_send");
    if (inp) inp.disabled = !enabled;
    if (btn) btn.disabled = !enabled;
  }

  function sendMessage() {
    var inp = document.getElementById("chat_input");
    if (!inp) return;
    var text = inp.value.trim();
    if (!text) return;
    inp.value = "";
    appendMsg("user", "<p>" + escapeHtml(text) + "</p>");
    setInputEnabled(false);
    showThinking(true);
    Shiny.setInputValue("doChat", text, { priority: "event" });
  }


  /* ---- 注册 Shiny 消息处理器 ----
     Shiny 在未就绪时会自动排队，无需等 DOMContentLoaded */
  function registerHandlers() {
    if (typeof Shiny === "undefined") return;
    Shiny.addCustomMessageHandler("appendMsg", function(msg) {
      appendMsg(msg.role, msg.html);
    });
    Shiny.addCustomMessageHandler("thinkingDone", function(msg) {
      showThinking(false);
    });
    Shiny.addCustomMessageHandler("inputEnabled", function(msg) {
      setInputEnabled(msg.enabled !== false);
    });
    Shiny.addCustomMessageHandler("clearDone", function(msg) {
      var container = document.getElementById("msg_container");
      if (container) {
        container.innerHTML = "";
        container.innerHTML =
          "<div id='empty_state' class='empty-state'>" +
          "<div class='empty-state-icon'>&#129302;</div>" +
          "<div><strong>LLMcoder Chat Panel</strong></div>" +
          "<div>Ask me anything about R, data analysis,<br>statistics, or your code.</div>" +
          "</div>";
      }
    });
  }

  if (typeof Shiny !== "undefined" && Shiny.initialized) {
    registerHandlers();
  } else {
    document.addEventListener("shiny:connected", registerHandlers);
    window.addEventListener("DOMContentLoaded", registerHandlers);
  }

  window.addEventListener("DOMContentLoaded", function() {
    var inp = document.getElementById("chat_input");
    if (inp) {
      inp.addEventListener("keydown", function(e) {
        if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
          e.preventDefault();
          sendMessage();
        }
        inp.style.height = "auto";
        inp.style.height = Math.min(inp.scrollHeight, 160) + "px";
      });
      // 绕过 autofocus 拦截：页面加载后手动 focus
      setTimeout(function() { inp.focus(); }, 300);
    }
    var btn = document.getElementById("btn_send");
    if (btn) {
      btn.addEventListener("click", function() { sendMessage(); });
    }
    document.addEventListener("click", function(e) {
      var runBtn = e.target.closest(".btn-run-code");
      if (runBtn) {
        var code = decodeURIComponent(runBtn.getAttribute("data-code") || "");
        if (!code) return;
        Shiny.setInputValue("doRunCode", code, { priority: "event" });
        return;
      }
      var insertBtn = e.target.closest(".btn-insert-code");
      if (insertBtn) {
        var code = decodeURIComponent(insertBtn.getAttribute("data-code") || "");
        if (!code) return;
        Shiny.setInputValue("doInsertCode", code, { priority: "event" });
      }
    });
  });

  window.appendMsgBridge = appendMsg;
})();
