import SwiftUI
import WebKit

// WKWebView subclass that forwards scroll events to the parent ScrollView
private class NonScrollingWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

// Weak-reference wrapper to break the retain cycle between
// WKUserContentController (which strongly retains message handlers)
// and the Coordinator (which holds SwiftUI bindings).
private class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(_ delegate: WKScriptMessageHandler) { self.delegate = delegate }
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

struct ChatMarkdownWebView: NSViewRepresentable {
    let content: String
    let isDark: Bool
    @Binding var dynamicHeight: CGFloat

    private static let localizedThinkingTitle = NSLocalizedString(
        "chat.thinkingProcess",
        tableName: nil,
        bundle: .main,
        value: "思考过程",
        comment: "Thinking block title"
    )
    private static let localizedCopyTitle = NSLocalizedString(
        "chat.copy",
        tableName: nil,
        bundle: .main,
        value: "复制",
        comment: "Copy button title"
    )
    private static let localizedCopiedTitle = NSLocalizedString(
        "chat.copied",
        tableName: nil,
        bundle: .main,
        value: "已复制",
        comment: "Copied button title"
    )

    func makeCoordinator() -> Coordinator {
        Coordinator(dynamicHeight: $dynamicHeight)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        // Use WeakScriptHandler to prevent retain cycle:
        // WKUserContentController strongly retains its message handlers,
        // which would otherwise pin the Coordinator and its SwiftUI bindings.
        userContentController.add(WeakScriptHandler(context.coordinator), name: "heightChange")
        userContentController.add(WeakScriptHandler(context.coordinator), name: "codeCopy")
        config.userContentController = userContentController

        let webView = NonScrollingWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        context.coordinator.webView = webView
        context.coordinator.currentThemeIsDark = isDark

        loadHTMLTemplate(webView: webView, context: context)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator

        // Theme change
        if coordinator.currentThemeIsDark != isDark {
            coordinator.currentThemeIsDark = isDark
            let js = "setTheme(\(isDark));"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        // Content change — only re-render if content actually changed
        if coordinator.lastRenderedContent != content {
            coordinator.lastRenderedContent = content
            if coordinator.isReady {
                renderContent(webView: webView, content: content)
            } else {
                coordinator.pendingContent = content
            }
        }
    }

    private func loadHTMLTemplate(webView: WKWebView, context: Context) {
        // Load the HTML from bundle or inline
        if let htmlPath = Bundle.main.path(forResource: "chat-message", ofType: "html"),
           let htmlContent = try? String(contentsOfFile: htmlPath, encoding: .utf8) {
            webView.loadHTMLString(htmlContent, baseURL: Bundle.main.bundleURL)
        } else {
            // Fallback: load from source directory during development
            let htmlString = ChatMarkdownHTMLTemplate.html
            webView.loadHTMLString(htmlString, baseURL: nil)
        }
    }

    private func renderContent(webView: WKWebView, content: String) {
        let escaped = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            // Escape Unicode line/paragraph separators — JS treats them as
            // newlines inside template literals, which breaks the JS injection.
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        let js = "render(`\(escaped)`);"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var dynamicHeight: Binding<CGFloat>
        weak var webView: WKWebView?
        var isReady = false
        var pendingContent: String?
        var lastRenderedContent: String?
        var currentThemeIsDark = false

        init(dynamicHeight: Binding<CGFloat>) {
            self.dynamicHeight = dynamicHeight
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isReady = true

            // Inject marked.js + highlight.js
            injectLibraries(webView: webView) { [weak self] in
                guard let self else { return }

                // Set theme
                let js = "setTheme(\(self.currentThemeIsDark));"
                webView.evaluateJavaScript(js, completionHandler: nil)

                // Render pending content
                if let pending = self.pendingContent {
                    self.pendingContent = nil
                    let escaped = pending
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "`", with: "\\`")
                        .replacingOccurrences(of: "$", with: "\\$")
                        .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
                        .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
                    webView.evaluateJavaScript("render(`\(escaped)`);", completionHandler: nil)
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Allow initial load, block external navigation
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
            } else if let url = navigationAction.request.url, url.scheme == "about" || url.scheme == "file" {
                decisionHandler(.allow)
            } else {
                // Open external links in default browser
                if let url = navigationAction.request.url {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
            }
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "heightChange":
                let height: CGFloat?
                if let number = message.body as? NSNumber {
                    height = CGFloat(truncating: number)
                } else if let doubleValue = message.body as? Double {
                    height = CGFloat(doubleValue)
                } else {
                    height = nil
                }

                if let height, height > 0 {
                    DispatchQueue.main.async { [weak self] in
                        self?.dynamicHeight.wrappedValue = height
                    }
                }
            case "codeCopy":
                if let code = message.body as? String {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(code, forType: .string)
                }
            default:
                break
            }
        }

        // MARK: - Library Injection

        private func injectLibraries(webView: WKWebView, completion: @escaping () -> Void) {
            // Inject marked.js
            let markedJS = ChatMarkdownLibraries.markedJS
            webView.evaluateJavaScript(markedJS) { _, _ in
                webView.evaluateJavaScript("window._markedReady = true;", completionHandler: nil)

                // Inject highlight.js
                let hlJS = ChatMarkdownLibraries.highlightJS
                webView.evaluateJavaScript(hlJS) { _, _ in
                    webView.evaluateJavaScript("window._hlReady = true;", completionHandler: nil)
                    webView.evaluateJavaScript(Self.localizedStringsBootstrapScript, completionHandler: nil)
                    completion()
                }
            }
        }

        private static var localizedStringsBootstrapScript: String {
            let strings = [
                "thinkingTitle": ChatMarkdownWebView.localizedThinkingTitle,
                "copy": ChatMarkdownWebView.localizedCopyTitle,
                "copied": ChatMarkdownWebView.localizedCopiedTitle,
            ]
            let data = try? JSONSerialization.data(withJSONObject: strings)
            let payload = data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            return "window.chatMessageStrings = \(payload);"
        }
    }
}

// MARK: - Inline HTML Template (Development Fallback)

enum ChatMarkdownHTMLTemplate {
    static let html: String = {
        // Minimal inline HTML for development when bundle resource isn't available
        """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <style>
        * { margin:0; padding:0; box-sizing:border-box; }
        html,body { font-family:-apple-system,sans-serif; font-size:13px; line-height:1.6;
          color:var(--text); background:transparent; -webkit-font-smoothing:antialiased; overflow:hidden; }
        :root { --text:#1d1d1f; --text-secondary:#6e6e73; --bg-code:#f5f5f7; --border:#d2d2d7;
          --accent:#0071e3; }
        .dark { --text:#f5f5f7; --text-secondary:#a1a1a6; --bg-code:#1c1c1e; --border:#3a3a3c;
          --accent:#2997ff; }
        #content { padding:2px 0; word-wrap:break-word; }
        #content p { margin-bottom:8px; }
        #content code { font-family:"SF Mono",Menlo,monospace; font-size:12px;
          background:var(--bg-code); border-radius:4px; padding:1px 5px; }
        #content pre { margin:8px 0; padding:10px 12px; overflow-x:auto; background:var(--bg-code);
          border-radius:8px; border:1px solid var(--border); }
        #content pre code { background:none; padding:0; border-radius:0; }
        #content strong { font-weight:600; }
        #content ul,#content ol { padding-left:20px; margin-bottom:8px; }
        </style></head>
        <body><div id="content"></div>
        <script>
        window.chatMessageStrings = window.chatMessageStrings || {
          thinkingTitle: "思考过程",
          copy: "复制",
          copied: "已复制"
        };
        function render(md) {
          if (!md) { document.getElementById('content').innerHTML=''; return; }
          var html = md.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\\n/g,'<br>');
          if (typeof marked!=='undefined'&&marked.parse) html=marked.parse(md,{breaks:true,gfm:true});
          document.getElementById('content').innerHTML=html;
          if(window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.heightChange)
            window.webkit.messageHandlers.heightChange.postMessage(document.documentElement.scrollHeight);
        }
        function appendDelta(d){if(!window._sb)window._sb='';window._sb+=d;render(window._sb);}
        function resetStream(){window._sb='';}
        function setTheme(dark){if(dark)document.documentElement.classList.add('dark');
          else document.documentElement.classList.remove('dark');}
        function notifyHeightChange(){if(window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.heightChange)
          window.webkit.messageHandlers.heightChange.postMessage(document.documentElement.scrollHeight);}
        if(typeof ResizeObserver!=='undefined'){new ResizeObserver(notifyHeightChange).observe(document.getElementById('content')||document.body);}
        </script></body></html>
        """
    }()
}

// MARK: - JS Libraries (loaded from CDN URLs as source strings)

enum ChatMarkdownLibraries {
    // marked.js v14 — minified source injected at runtime
    // In production, these would be bundled as .js files in the app bundle.
    // For now, we use CDN fetch with caching fallback.
    static let markedJS: String = """
    if (typeof marked === 'undefined') {
      // Minimal marked.js implementation for basic markdown
      window.marked = {
        parse: function(src, options) {
          options = options || {};
          var text = src;
          var highlightCode = function(code, lang) {
            if (typeof window._highlightCode === 'function') {
              return window._highlightCode(code.trim(), lang);
            }
            return code;
          };

          // Code blocks (fenced)
          text = text.replace(/```(\\w*)\\n([\\s\\S]*?)```/g, function(m, lang, code) {
            var highlighted = highlightCode(code, lang);
            var cls = lang ? ' class="language-' + lang + '"' : '';
            return '<pre><code' + cls + '>' + highlighted + '</code></pre>';
          });

          // Inline code
          text = text.replace(/`([^`]+)`/g, '<code>$1</code>');

          // Headers
          text = text.replace(/^#### (.+)$/gm, '<h4>$1</h4>');
          text = text.replace(/^### (.+)$/gm, '<h3>$1</h3>');
          text = text.replace(/^## (.+)$/gm, '<h2>$1</h2>');
          text = text.replace(/^# (.+)$/gm, '<h1>$1</h1>');

          // Bold
          text = text.replace(/\\*\\*(.+?)\\*\\*/g, '<strong>$1</strong>');
          // Italic
          text = text.replace(/\\*(.+?)\\*/g, '<em>$1</em>');

          // Unordered lists
          text = text.replace(/^[\\s]*[-*+] (.+)$/gm, '<li>$1</li>');
          text = text.replace(/(<li>.*<\\/li>\\n?)+/g, '<ul>$&</ul>');

          // Ordered lists
          text = text.replace(/^[\\s]*\\d+\\. (.+)$/gm, '<li>$1</li>');

          // Blockquotes
          text = text.replace(/^> (.+)$/gm, '<blockquote>$1</blockquote>');

          // Horizontal rules
          text = text.replace(/^---$/gm, '<hr>');

          // Links — add rel="noopener noreferrer" to prevent reverse tabnapping
          text = text.replace(/\\[([^\\]]+)\\]\\(([^)]+)\\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>');

          // Paragraphs
          text = text.replace(/^(?!<[hulpboh]|$)(.+)$/gm, '<p>$1</p>');

          // Line breaks
          if (options.breaks) {
            text = text.replace(/\\n/g, '<br>');
          }

          // Clean up double br in blocks
          text = text.replace(/<br><br>/g, '</p><p>');

          return text;
        }
      };
    }
    window.configureMarkedHighlight = function() {
      if (typeof hljs === 'undefined') return;
      window._highlightCode = function(code, lang) {
        if (lang && hljs.getLanguage && hljs.getLanguage(lang)) {
          try { return hljs.highlight(code, { language: lang }).value; } catch (e) {}
        }
        if (hljs.highlightAuto) {
          try { return hljs.highlightAuto(code).value; } catch (e) {}
        }
        return code;
      };
    };
    """

    // highlight.js — minimal subset for common languages
    static let highlightJS: String = """
    if (typeof hljs === 'undefined') {
      window.hljs = {
        _languages: {},
        getLanguage: function(name) {
          return this._languages[name] || null;
        },
        registerLanguage: function(name, def) {
          this._languages[name] = def;
        },
        highlight: function(code, opts) {
          return { value: this._basicHighlight(code, opts.language) };
        },
        highlightAuto: function(code) {
          return { value: this._basicHighlight(code, '') };
        },
        highlightElement: function(el) {
          el.innerHTML = this._basicHighlight(el.textContent, '');
          el.dataset.highlighted = 'true';
        },
        _basicHighlight: function(code, lang) {
          // Basic keyword highlighting for common languages
          var keywords = /\\b(func|fn|let|var|const|if|else|for|while|return|import|struct|class|enum|switch|case|break|continue|try|catch|throw|async|await|pub|static|self|super|true|false|nil|null|undefined|def|from|in|as|is|not|and|or|with|yield|match|impl|trait|use|mod|crate|where|type|protocol|guard|defer|do|repeat|extension|private|public|internal|override|final|mut|ref|move|unsafe|extern|macro|println|print|String|Int|Bool|Float|Double|Array|Dict|Optional|Result|Error|None|Some|Ok|Err|Vec|Box|Rc|Arc|HashMap|HashSet)\\b/g;
          var strings = /(["'])(?:(?!\\1)[^\\\\]|\\\\.)*\\1/g;
          var comments = /\\/\\/.*$|\\/\\*[\\s\\S]*?\\*\\//gm;
          var numbers = /\\b\\d+\\.?\\d*\\b/g;

          var result = code;
          // Escape HTML first
          result = result.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

          // Apply highlighting (order matters — comments override others)
          var tokens = [];
          var r;
          while ((r = comments.exec(result)) !== null) tokens.push({s:r.index,e:r.index+r[0].length,t:'comment',v:r[0]});
          while ((r = strings.exec(result)) !== null) {
            var inComment = tokens.some(function(t){return r.index>=t.s&&r.index<t.e;});
            if (!inComment) tokens.push({s:r.index,e:r.index+r[0].length,t:'string',v:r[0]});
          }
          while ((r = keywords.exec(result)) !== null) {
            var inOther = tokens.some(function(t){return r.index>=t.s&&r.index<t.e;});
            if (!inOther) tokens.push({s:r.index,e:r.index+r[0].length,t:'keyword',v:r[0]});
          }
          while ((r = numbers.exec(result)) !== null) {
            var inOther2 = tokens.some(function(t){return r.index>=t.s&&r.index<t.e;});
            if (!inOther2) tokens.push({s:r.index,e:r.index+r[0].length,t:'number',v:r[0]});
          }

          tokens.sort(function(a,b){return b.s-a.s;});
          tokens.forEach(function(tok) {
            var cls = 'hljs-' + tok.t;
            result = result.substring(0,tok.s) + '<span class="'+cls+'">' + tok.v + '</span>' + result.substring(tok.e);
          });

          return result;
        }
      };
    }
    """
}
