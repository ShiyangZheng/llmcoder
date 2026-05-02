# LLMcoder UI 修复总结

## 修复日期
2026-05-02

## 修复的问题

### 1. Clear chat / Export transcript 按钮无响应
**问题原因**：按钮缺少 `action-button` 类，Shiny 无法识别按钮点击事件。

**修复位置**：`R/chat.R` 第470-476行

**修复内容**：
```r
# 修改前
tags$button(id = "btn_clear", class = "sidebar-btn", ...)
tags$button(id = "btn_export", class = "sidebar-btn", ...)

# 修改后
tags$button(id = "btn_clear", class = "action-button sidebar-btn", ...)
tags$button(id = "btn_export", class = "action-button sidebar-btn", ...)
```

### 2. 发送按钮只有蓝色色块
**问题原因**：按钮内部只有 `<i>` 图标元素，没有文字。

**修复位置**：`R/chat.R` 第511-513行

**修复内容**：
```r
# 修改前
tags$button(id = "btn_send", class = "send-btn",
  tags$i(class = "fa fa-paper-plane")
)

# 修改后
tags$button(id = "btn_send", class = "send-btn", "Send")
```

### 3. 代码块添加"Insert"按钮功能
**需求**：用户希望AI回复中的R代码块能够直接插入到当前脚本中，而不仅仅是运行。

**修复位置**：
- `R/chat.R` - `render_markdown_html()` 函数
- `R/chat.R` - `chat_server()` 函数
- `R/chat.R` - `chat_css()` 函数
- `inst/www/chat_panel.js`

**修复内容**：

#### 3.1 修改 `render_markdown_html()` 函数
在R代码块中添加两个按钮："Run" 和 "Insert"
```r
btn <- if (lang == "r" || lang == "R") {
  run_btn <- paste0("<button class='btn-run-code' data-code='",
                     URLencode(inner, reserved = TRUE), "'>Run</button>")
  insert_btn <- paste0("<button class='btn-insert-code' data-code='",
                        URLencode(inner, reserved = TRUE), "'>Insert</button>")
  paste0(run_btn, " ", insert_btn)
} else ""
```

#### 3.2 添加CSS样式
```css
.btn-insert-code {
  font-size: 12px;
  padding: 3px 10px;
  background: #37b24d;  /* 绿色 */
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: background .15s;
  margin-left: 4px;
}

.btn-insert-code:hover { background: #2f9e44; }
```

#### 3.3 修改 JavaScript 处理"Insert"按钮点击
```javascript
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
```

#### 3.4 添加服务器端逻辑处理"Insert"按钮
```r
# ---- Run code in console ----
shiny::observeEvent(input$doRunCode, {
  code <- input$doRunCode
  if (!nzchar(trimws(code))) return()
  tryCatch({
    rstudioapi::sendToConsole(code, execute = TRUE, focus = FALSE)
  }, error = function(e) {
    rstudioapi::showDialog("LLMcoder", paste("Could not send to console:", e$message))
  })
})

# ---- Insert code into script ----
shiny::observeEvent(input$doInsertCode, {
  code <- input$doInsertCode
  if (!nzchar(trimws(code))) return()
  tryCatch({
    context <- get_editor_ctx()
    if (is.null(context$doc_id)) {
      # 没有打开的文档，发送到控制台（不执行）
      rstudioapi::sendToConsole(code, execute = FALSE, focus = FALSE)
      rstudioapi::showDialog("LLMcoder", "No active document. Code sent to console (not executed).")
    } else {
      # 插入到当前光标位置
      rstudioapi::insertText(code)
    }
  }, error = function(e) {
    rstudioapi::showDialog("LLMcoder", paste("Could not insert code:", e$message))
  })
})
```

## 测试建议

1. 重新安装包：`R CMD INSTALL llmcoder`
2. 在RStudio中运行：`llmcoder::addin_chat_panel()`
3. 测试项目：
   - ✅ 点击 "Clear chat" 按钮，检查聊天记录是否清空
   - ✅ 点击 "Export transcript" 按钮，检查是否保存对话记录
   - ✅ 检查发送按钮是否显示 "Send" 文字
   - ✅ 向AI询问R代码相关问题，检查代码块是否显示 "Run" 和 "Insert" 两个按钮
   - ✅ 点击 "Run" 按钮，检查代码是否发送到控制台并执行
   - ✅ 点击 "Insert" 按钮，检查代码是否插入到当前脚本的光标位置

## 文件清单

修改的文件：
- `/Users/admin/WorkBuddy/Claw/llmcoder_work/llmcoder/R/chat.R`
- `/Users/admin/WorkBuddy/Claw/llmcoder_work/llmcoder/inst/www/chat_panel.js`

包安装状态：
- ✅ 安装成功 (2026-05-02)
- 安装命令：`R CMD INSTALL --no-multiarch --with-keep.source .`
- 安装位置：`/Users/admin/Library/R/x86_64/4.2/library/llmcoder`
