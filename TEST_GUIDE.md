# LLMcoder 功能测试指南

## 安装确认
包已重新安装，版本：llmcoder 1.2.0

## 测试步骤

### 1. 启动 Chat Panel
在RStudio中运行：
```r
llmcoder::addin_chat_panel()
```

### 2. 测试 Clear chat 按钮
**步骤**：
1. 在输入框中输入任意文本，点击Send或Ctrl+Enter发送
2. 确认消息显示在聊天区域
3. 点击左侧侧边栏的 "Clear chat" 按钮

**预期结果**：
- 聊天区域清空
- 显示空状态提示："LLMcoder Chat Panel - Ask me anything about R..."

---

### 3. 测试 Export transcript 按钮
**步骤**：
1. 进行几次对话（至少2-3条消息）
2. 点击左侧侧边栏的 "Export transcript" 按钮
3. 选择保存位置，保存文件

**预期结果**：
- 弹出文件保存对话框
- 保存的txt文件包含完整的对话记录
- 文件格式：
  ```
  # LLMcoder Chat Transcript
  [时间戳]
  
  USER: [用户消息]
  ASSISTANT: [AI回复]
  ...
  ```

---

### 4. 测试发送按钮文字
**步骤**：
1. 观察输入框右侧的蓝色按钮

**预期结果**：
- 按钮上显示 "Send" 文字
- 不再是只有蓝色色块

---

### 5. 测试代码块渲染
**步骤**：
1. 在输入框中输入：`请给我一个R绘图示例`
2. 发送消息
3. 查看AI回复中的代码块

**预期结果**：
- 代码块显示在灰色的 `<pre>` 块中
- 代码块右上角显示语言标签（如 "R"）
- 代码块下方有两个按钮：**Run** 和 **Insert**
- 代码语法正确高亮（作为纯文本显示，但缩进和换行正确）

**示例正确渲染**：
```
┌─────────────────────────────────────┐
│ R                    [Run] [Insert]│
│─────────────────────────────────────│
│ x <- 1:10                      │
│ y <- x^2                       │
│ plot(x, y)                     │
│─────────────────────────────────────│
```

**错误渲染（仍能看到HTML标签）**：
```
┌─────────────────────────────────────┐
│ <pre><div class='code-header'>...  │
│ (HTML标签作为文本显示)              │
└─────────────────────────────────────┘
```

---

### 6. 测试 Run 按钮
**步骤**：
1. 让AI生成一个简单的R代码块
2. 点击代码块下方的 "Run" 按钮
3. 查看RStudio控制台

**预期结果**：
- 代码被发送到控制台并执行
- 控制台显示代码执行结果

---

### 7. 测试 Insert 按钮
**步骤**：
1. 打开一个R脚本文件（.R文件）
2. 将光标放置在任意位置
3. 让AI生成一个R代码块
4. 点击代码块下方的 "Insert" 按钮

**预期结果**：
- 代码被插入到当前光标位置
- 代码缩进正确
- 如果当前没有打开的文档，会弹出提示："No active document. Code sent to console (not executed)."

---

### 8. 测试中文显示
**步骤**：
1. 输入中文问题，如：`如何读取CSV文件？`
2. 查看AI回复

**预期结果**：
- 中文字符正确显示，无乱码
- 标点符号正确显示

---

## 调试方法

### 方法1：检查浏览器控制台
1. 在RStudio Gadget窗口中，右键点击页面，选择 "Inspect Element"
2. 打开浏览器开发者工具
3. 查看Console标签页，看是否有JavaScript错误
4. 查看Elements标签页，检查HTML是否正确渲染

### 方法2：在R中直接测试渲染函数
```r
library(llmcoder)

# 测试渲染函数
test_text <- "这是一个测试。

```r
x <- 1:10
plot(x)
```

结束测试。"

result <- llmcoder:::render_markdown_html(test_text)
cat(result)
```

**正确的输出**应该包含：
- `<pre><div class='code-header'><span class='code-lang'>R</span>...`
- `<button class='btn-run-code'...>Run</button>`
- `<button class='btn-insert-code'...>Insert</button>`

**错误的输出**会包含：
- `&lt;pre&gt;` 而不是 `<pre>`
- `&lt;button&gt;` 而不是 `<button>`

---

## 常见问题

### Q1: 点击按钮没有反应
**可能原因**：
- Shiny的input绑定没有正确注册
- JavaScript错误导致事件监听失败

**解决方法**：
1. 检查浏览器控制台是否有错误
2. 重新启动Chat Panel
3. 确认包已正确安装：`packageVersion("llmcoder")`

### Q2: 代码块显示为纯文本（看到HTML标签）
**可能原因**：
- `render_markdown_html()`函数没有正确生成HTML
- 前端接收到的HTML字符串被转义了

**解决方法**：
1. 在R中直接运行 `render_markdown_html()` 测试（见方法2）
2. 检查函数返回值是否包含未转义的HTML标签
3. 重新安装包

### Q3: Insert按钮点击后没有插入代码
**可能原因**：
- RStudio API调用失败
- 没有打开的活动文档

**解决方法**：
1. 确保有一个打开的R脚本文件
2. 将光标放置在想要插入代码的位置
3. 查看是否弹出错误提示对话框

---

## 测试检查表

- [ ] Clear chat 按钮正常工作
- [ ] Export transcript 按钮正常工作
- [ ] 发送按钮显示 "Send" 文字
- [ ] 代码块正确渲染（不显示HTML标签）
- [ ] 代码块包含 Run 和 Insert 两个按钮
- [ ] Run 按钮可以执行代码
- [ ] Insert 按钮可以插入代码到脚本
- [ ] 中文显示正常
- [ ] 标题、列表、粗体、斜体格式正确

---

## 联系信息

如果遇到问题，请提供：
1. RStudio版本：`rstudioapi::versionInfo()$version`
2. R版本：`R.version.string`
3. llmcoder版本：`packageVersion("llmcoder")`
4. 浏览器控制台错误信息（如果有）
5. `render_markdown_html()` 函数的输出（见方法2）
