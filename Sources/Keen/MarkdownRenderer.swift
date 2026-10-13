import Foundation
import Markdown

struct MarkdownRenderer {
    func render(source: String, baseURL: URL) -> RenderedDocument {
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        var builder = HTMLBuilder(baseURL: baseURL)
        let body = builder.render(document)
        let mermaidScript = builder.hasMermaid ? Self.loadMermaidScript() : nil
        return RenderedDocument(html: Self.page(body: body, mermaidScript: mermaidScript), headings: builder.headings)
    }

    private static func loadMermaidScript() -> String? {
        let url = Bundle.module.url(forResource: "mermaid.min", withExtension: "js", subdirectory: "vendor")
            ?? Bundle.module.url(forResource: "mermaid.min", withExtension: "js")
        guard let url else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private static func page(body: String, mermaidScript: String?) -> String {
        let mermaidRuntime = mermaidScript.map {
            "<script>\($0)</script><script>\(mermaidBootstrap)</script>"
        } ?? ""
        return """
        <!doctype html>
        <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: light dark; --bg:#fff; --fg:#24292f; --muted:#66707b; --line:#d8dee4; --code:#f6f8fa; --link:#0969da; --quote:#57606a; }
        html[data-theme='dark'] { --bg:#1e1f22; --fg:#d6d9df; --muted:#9ba3ad; --line:#3b4048; --code:#292c31; --link:#69a7ff; --quote:#a0a8b2; }
        @media (prefers-color-scheme:dark) { html[data-theme='system'] { --bg:#1e1f22; --fg:#d6d9df; --muted:#9ba3ad; --line:#3b4048; --code:#292c31; --link:#69a7ff; --quote:#a0a8b2; } }
        * { box-sizing:border-box; }
        html,body { margin:0; min-height:100%; background:var(--bg); color:var(--fg); }
        body { font-family:-apple-system,BlinkMacSystemFont,"Helvetica Neue","PingFang SC",sans-serif; font-size:var(--font-size,16px); line-height:1.75; letter-spacing:.005em; -webkit-font-smoothing:antialiased; }
        main { max-width:var(--reading-width,900px); margin:0 auto; padding:40px 44px 80px; }
        h1,h2,h3,h4,h5,h6 { color:var(--fg); line-height:1.28; margin:1.75em 0 .68em; letter-spacing:-.015em; scroll-margin-top:22px; }
        h1 { font-size:2em; padding-bottom:.3em; border-bottom:1px solid var(--line); } h2 { font-size:1.5em; padding-bottom:.25em; border-bottom:1px solid var(--line); }
        h1:first-child { margin-top:.15em; } p { margin:0 0 1.05em; } a { color:var(--link); text-decoration:none; cursor:pointer; } a:hover { text-decoration:underline; }
        blockquote { margin:1em 0; padding:.1em 1em; color:var(--quote); border-left:4px solid var(--line); }
        code { font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:.88em; background:var(--code); border-radius:4px; padding:.15em .35em; }
        pre { position:relative; overflow:auto; padding:16px; border:1px solid var(--line); border-radius:8px; background:var(--code); line-height:1.5; }
        pre code { padding:0; background:none; white-space:pre; }
        .copy-code { position:absolute; right:8px; top:8px; border:1px solid var(--line); border-radius:5px; background:var(--bg); color:var(--fg); padding:3px 8px; opacity:.62; transition:opacity .12s; }
        pre:hover .copy-code { opacity:1; }
        .mermaid-shell { margin:1.25em 0; border:1px solid var(--line); border-radius:9px; background:var(--code); overflow:hidden; }
        .mermaid-toolbar { display:flex; justify-content:flex-end; gap:5px; padding:7px 8px; border-bottom:1px solid var(--line); }
        .mermaid-toolbar button { border:1px solid var(--line); border-radius:5px; background:var(--bg); color:var(--fg); min-width:28px; padding:3px 8px; }
        .mermaid-viewport { min-height:120px; overflow:hidden; padding:18px; cursor:grab; touch-action:none; }
        .mermaid-viewport.dragging { cursor:grabbing; }
        .mermaid-stage { width:max-content; min-width:100%; transform-origin:0 0; transition:transform .12s ease-out; }
        .mermaid-stage svg { display:block; margin:auto; max-width:none !important; height:auto; }
        .mermaid-error { padding:14px 16px; color:#b42318; white-space:pre-wrap; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; }
        table { display:block; max-width:100%; overflow:auto; border-collapse:collapse; margin:1em 0; }
        th,td { border:1px solid var(--line); padding:7px 12px; } th { background:var(--code); }
        img { max-width:100%; height:auto; border-radius:4px; } hr { border:0; border-top:1px solid var(--line); margin:2em 0; }
        ul.task-list { list-style:none; padding-left:.15em; }
        .task-list > li { display:grid; grid-template-columns:22px minmax(0,1fr); align-items:start; margin:.28em 0; }
        .task-list > li > input { margin:.56em 0 0 1px; accent-color:var(--link); }
        .task-list > li > p { margin:0; }
        </style></head>
        <body><main>\(body)</main>
        <script>
        const bridge = window.webkit?.messageHandlers?.keen;
        document.querySelectorAll('pre').forEach(pre => { const button=document.createElement('button'); button.className='copy-code'; button.textContent='复制'; button.onclick=()=>navigator.clipboard.writeText(pre.querySelector('code')?.innerText||''); pre.appendChild(button); });
        const headings=[...document.querySelectorAll('h1,h2,h3,h4,h5,h6')];
        const observer=new IntersectionObserver(entries=>{ const visible=entries.filter(e=>e.isIntersecting).sort((a,b)=>a.boundingClientRect.top-b.boundingClientRect.top); if(visible[0]) bridge?.postMessage({type:'heading',id:visible[0].target.id}); }, {rootMargin:'-5% 0px -78% 0px',threshold:[0,1]});
        headings.forEach(h=>observer.observe(h));
        window.keenScrollTo=id=>document.getElementById(id)?.scrollIntoView({behavior:'smooth',block:'start'});
        window.keenConfigure=(theme,size,width)=>{ document.documentElement.dataset.theme=theme; document.documentElement.style.setProperty('--font-size',size+'px'); document.documentElement.style.setProperty('--reading-width',width+'px'); };
        </script>\(mermaidRuntime)</body></html>
        """
    }

    private static let mermaidBootstrap = #"""
    (() => {
      const shells = [...document.querySelectorAll('.mermaid-shell')];
      if (!shells.length || typeof mermaid === 'undefined') return;
      const dark = document.documentElement.dataset.theme === 'dark' ||
        (document.documentElement.dataset.theme === 'system' && matchMedia('(prefers-color-scheme: dark)').matches);
      mermaid.initialize({
        startOnLoad: false,
        securityLevel: 'strict',
        theme: dark ? 'dark' : 'neutral',
        suppressErrorRendering: true,
        maxTextSize: 100000
      });

      const applyTransform = shell => {
        const stage = shell.querySelector('.mermaid-stage');
        stage.style.transform = `translate(${stage.dataset.x || 0}px, ${stage.dataset.y || 0}px) scale(${stage.dataset.scale || 1})`;
      };
      const fit = shell => {
        const viewport = shell.querySelector('.mermaid-viewport');
        const stage = shell.querySelector('.mermaid-stage');
        const svg = stage.querySelector('svg');
        if (!svg) return;
        stage.style.transform = 'none';
        const naturalWidth = svg.getBoundingClientRect().width || 1;
        stage.dataset.scale = Math.min(1, (viewport.clientWidth - 36) / naturalWidth).toFixed(3);
        stage.dataset.x = '0'; stage.dataset.y = '0';
        applyTransform(shell);
      };
      window.keenMermaidZoom = (button, factor) => {
        const shell = button.closest('.mermaid-shell');
        const stage = shell.querySelector('.mermaid-stage');
        stage.dataset.scale = Math.max(.25, Math.min(3, Number(stage.dataset.scale || 1) * factor)).toFixed(3);
        applyTransform(shell);
      };
      window.keenMermaidFit = button => fit(button.closest('.mermaid-shell'));

      shells.forEach(shell => {
        const viewport = shell.querySelector('.mermaid-viewport');
        const stage = shell.querySelector('.mermaid-stage');
        let drag = null;
        viewport.addEventListener('pointerdown', event => {
          drag = { x:event.clientX, y:event.clientY, sx:Number(stage.dataset.x || 0), sy:Number(stage.dataset.y || 0) };
          viewport.classList.add('dragging'); viewport.setPointerCapture(event.pointerId);
        });
        viewport.addEventListener('pointermove', event => {
          if (!drag) return;
          stage.dataset.x = drag.sx + event.clientX - drag.x;
          stage.dataset.y = drag.sy + event.clientY - drag.y;
          applyTransform(shell);
        });
        viewport.addEventListener('pointerup', () => { drag = null; viewport.classList.remove('dragging'); });
      });

      (async () => {
        for (const shell of shells) {
          const node = shell.querySelector('.mermaid');
          const source = node.textContent;
          try {
            await mermaid.run({ nodes:[node], suppressErrors:true });
            requestAnimationFrame(() => fit(shell));
          } catch (error) {
            shell.querySelector('.mermaid-toolbar').hidden = true;
            shell.querySelector('.mermaid-viewport').innerHTML = '';
            const message = document.createElement('div');
            message.className = 'mermaid-error';
            message.textContent = `Mermaid 渲染失败\n${error?.message || error}\n\n${source}`;
            shell.appendChild(message);
          }
        }
      })();
    })();
    """#
}

private struct HTMLBuilder {
    let baseURL: URL
    var headings: [HeadingItem] = []
    var hasMermaid = false
    private var usedSlugs: [String: Int] = [:]

    mutating func render(_ markup: any Markup) -> String {
        switch markup {
        case let document as Document:
            return renderChildren(document)
        case let heading as Heading:
            let title = plainText(heading)
            let slug = uniqueSlug(title)
            let line = heading.range?.lowerBound.line ?? 1
            headings.append(HeadingItem(id: slug, title: title, level: heading.level, line: line))
            return "<h\(heading.level) id=\"\(escapeAttribute(slug))\">\(renderChildren(heading))</h\(heading.level)>"
        case let paragraph as Paragraph:
            return "<p>\(renderChildren(paragraph))</p>"
        case let text as Markdown.Text:
            return escape(text.string)
        case let emphasis as Emphasis:
            return "<em>\(renderChildren(emphasis))</em>"
        case let strong as Strong:
            return "<strong>\(renderChildren(strong))</strong>"
        case let deletion as Strikethrough:
            return "<del>\(renderChildren(deletion))</del>"
        case let inlineCode as InlineCode:
            return "<code>\(escape(inlineCode.code))</code>"
        case let code as CodeBlock:
            if code.language?.lowercased() == "mermaid" {
                hasMermaid = true
                return """
                <section class="mermaid-shell">
                  <div class="mermaid-toolbar">
                    <button title="缩小" onclick="keenMermaidZoom(this,0.8)">−</button>
                    <button title="适应宽度" onclick="keenMermaidFit(this)">适应</button>
                    <button title="放大" onclick="keenMermaidZoom(this,1.25)">＋</button>
                  </div>
                  <div class="mermaid-viewport"><div class="mermaid-stage" data-scale="1" data-x="0" data-y="0"><div class="mermaid">\(escape(code.code))</div></div></div>
                </section>
                """
            }
            let language = code.language.map { " class=\"language-\(escapeAttribute($0))\"" } ?? ""
            return "<pre><code\(language)>\(escape(code.code))</code></pre>"
        case let quote as BlockQuote:
            return "<blockquote>\(renderChildren(quote))</blockquote>"
        case let link as Markdown.Link:
            let href = link.destination.map(escapeAttribute) ?? ""
            return "<a href=\"\(href)\">\(renderChildren(link))</a>"
        case let image as Markdown.Image:
            let src = image.source.flatMap(safeImageSource).map(escapeAttribute) ?? ""
            let alt = escapeAttribute(plainText(image))
            return src.isEmpty ? "<span class=\"missing-image\">[图片不可用：\(alt)]</span>" : "<img src=\"\(src)\" alt=\"\(alt)\">"
        case let table as Table:
            return renderTable(table)
        case let list as UnorderedList:
            let taskClass = list.children.contains { ($0 as? ListItem)?.checkbox != nil } ? " class=\"task-list\"" : ""
            return "<ul\(taskClass)>\(renderChildren(list))</ul>"
        case let list as OrderedList:
            return "<ol start=\"\(list.startIndex)\">\(renderChildren(list))</ol>"
        case let item as ListItem:
            let checkbox: String
            switch item.checkbox {
            case .checked?: checkbox = "<input type=\"checkbox\" checked disabled>"
            case .unchecked?: checkbox = "<input type=\"checkbox\" disabled>"
            case nil: checkbox = ""
            }
            return "<li>\(checkbox)\(renderChildren(item))</li>"
        case is ThematicBreak:
            return "<hr>"
        case is LineBreak:
            return "<br>"
        case is SoftBreak:
            return "\n"
        case let html as HTMLBlock:
            return "<pre><code>\(escape(html.rawHTML))</code></pre>"
        case let html as InlineHTML:
            return escape(html.rawHTML)
        default:
            return renderChildren(markup)
        }
    }

    private mutating func renderChildren(_ markup: any Markup) -> String {
        markup.children.map { render($0) }.joined()
    }

    private mutating func renderTable(_ table: Table) -> String {
        let header = table.head.children.map { cell in
            "<th>\(renderChildren(cell))</th>"
        }.joined()
        let rows = table.body.children.map { row in
            let cells = row.children.map { cell in
                "<td>\(renderChildren(cell))</td>"
            }.joined()
            return "<tr>\(cells)</tr>"
        }.joined()
        return "<table><thead><tr>\(header)</tr></thead><tbody>\(rows)</tbody></table>"
    }

    private func plainText(_ markup: any Markup) -> String {
        if let text = markup as? Markdown.Text { return text.string }
        if let code = markup as? InlineCode { return code.code }
        return markup.children.map(plainText).joined()
    }

    private mutating func uniqueSlug(_ value: String) -> String {
        let scalars = value.lowercased().unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) || scalar.value > 127 ? Character(String(scalar)) : "-"
        }
        var base = String(scalars).replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if base.isEmpty { base = "section" }
        let count = usedSlugs[base, default: 0]
        usedSlugs[base] = count + 1
        return count == 0 ? base : "\(base)-\(count)"
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func escapeAttribute(_ value: String) -> String { escape(value) }

    private func safeImageSource(_ value: String) -> String? {
        guard !value.isEmpty,
              !value.hasPrefix("/"),
              !value.hasPrefix("//"),
              URLComponents(string: value)?.scheme == nil else { return nil }
        let decoded = value.removingPercentEncoding ?? value
        let resolved = baseURL.appendingPathComponent(decoded).standardizedFileURL
        let root = baseURL.standardizedFileURL.path + "/"
        guard resolved.path.hasPrefix(root) else { return nil }
        return value
    }
}
