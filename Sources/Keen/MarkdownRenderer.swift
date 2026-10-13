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
        :root { color-scheme:light dark; --bg:#fff; --fg:#1d1d1f; --muted:#707780; --line:#e1e4e8; --soft-line:#eceef1; --code:#f5f6f7; --link:#1769c2; --quote:#60606a; --table-head:#f7f8f9; --body-font:-apple-system,BlinkMacSystemFont,"Helvetica Neue","PingFang SC",sans-serif; --heading-font:var(--body-font); --body-leading:1.72; --paragraph-gap:1em; --heading-weight:650; }
        html[data-theme='dark'] { --bg:#1e2024; --fg:#d9dce1; --muted:#969da7; --line:#3b4047; --soft-line:#30343a; --code:#292d33; --link:#71a9ed; --quote:#a6adb6; --table-head:#262a2f; }
        @media (prefers-color-scheme:dark) { html[data-theme='system'] { --bg:#1e2024; --fg:#d9dce1; --muted:#969da7; --line:#3b4047; --soft-line:#30343a; --code:#292d33; --link:#71a9ed; --quote:#a6adb6; --table-head:#262a2f; } }
        html[data-style='everforest-light'] { color-scheme:light; --bg:#fdf6e3; --fg:#5c6a72; --muted:#829181; --line:#d8d5b8; --soft-line:#e3dec4; --code:#f3ead3; --link:#35a77c; --quote:#667b74; --table-head:#f2edda; --body-leading:1.66; --paragraph-gap:.9em; --heading-weight:700; }
        html[data-style='swiss'] { --body-font:"Helvetica Neue",Helvetica,Arial,Verdana,"PingFang SC",sans-serif; --heading-font:var(--body-font); --body-leading:1.6; --paragraph-gap:1.5rem; --heading-weight:600; }
        html[data-style='ink'] { --body-font:"Avenir Next",-apple-system,"PingFang SC",sans-serif; --body-leading:1.6; --paragraph-gap:.84em; --heading-weight:650; }
        html[data-style='manuscript'] { --body-font:"New York",Georgia,"Songti SC",serif; --heading-font:"New York",Georgia,"Songti SC",serif; --body-leading:1.86; --paragraph-gap:1.16em; --heading-weight:700; }
        * { box-sizing:border-box; }
        html,body { margin:0; min-height:100%; background:var(--bg); color:var(--fg); }
        body { font-family:var(--body-font); font-size:var(--font-size,15px); line-height:var(--body-leading); letter-spacing:.002em; -webkit-font-smoothing:antialiased; text-rendering:optimizeLegibility; }
        main { width:min(var(--reading-width,860px), calc(100vw - 80px)); margin:0 auto; padding:48px 0 96px; }
        html[data-style='swiss'] main { width:min(calc(65rem + 64px), calc(100vw - 60px)); margin:30px auto 0; padding:32px 32px 96px; }
        html[data-style='everforest-light'] main { width:calc(100vw - 96px); padding-top:34px; }
        h1,h2,h3,h4,h5,h6 { font-family:var(--heading-font); color:var(--fg); font-weight:var(--heading-weight); line-height:1.3; margin:1.72em 0 .66em; letter-spacing:-.018em; scroll-margin-top:24px; }
        h1 { font-size:2.18em; margin-top:.1em; padding-bottom:.38em; border-bottom:1px solid var(--line); } h2 { font-size:1.72em; padding-bottom:.28em; border-bottom:1px solid var(--soft-line); }
        h3 { font-size:1.22em; } h4 { font-size:1.08em; }
        html[data-style='swiss'] h1,html[data-style='swiss'] h2 { border-bottom:0; padding-bottom:0; }
        html[data-style='swiss'] h1,html[data-style='swiss'] h2,html[data-style='swiss'] h3,html[data-style='swiss'] h4,html[data-style='swiss'] h5 { margin:2.5rem 0 1.25rem; line-height:1.2; letter-spacing:0; }
        html[data-style='swiss'] h1 { margin-top:0; font-size:2.75rem; color:var(--fg); }
        html[data-style='swiss'] h2 { font-size:2.25rem; }
        html[data-style='swiss'] h3 { font-size:1.875rem; }
        html[data-style='swiss'] h4 { font-size:1.5rem; }
        html[data-style='swiss'] h5 { font-size:1.25rem; }
        p { margin:0 0 var(--paragraph-gap); } strong { font-weight:650; } a { color:var(--link); text-decoration:none; cursor:pointer; } a:hover { text-decoration:underline; text-underline-offset:2px; }
        blockquote { margin:1.2em 0; padding:.18em 1.05em; color:var(--quote); border-left:3px solid var(--line); }
        html[data-style='everforest-light'] blockquote { padding:.45em .9em; border-left:4px solid #a6b49a; background:#f3efd6; }
        code { font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:.87em; background:var(--code); border-radius:4px; padding:.14em .34em; }
        pre { position:relative; overflow:auto; margin:1.2em 0; padding:15px 17px; border:1px solid var(--line); border-radius:6px; background:var(--code); line-height:1.5; }
        pre code { padding:0; background:none; white-space:pre; }
        .copy-code { position:absolute; right:8px; top:8px; border:1px solid var(--line); border-radius:5px; background:var(--bg); color:var(--fg); padding:3px 8px; opacity:.62; transition:opacity .12s; }
        pre:hover .copy-code { opacity:1; }
        .mermaid-shell { position:relative; margin:1.25em 0; border:0; background:transparent; overflow:visible; }
        .mermaid-toolbar { position:absolute; z-index:3; right:0; top:0; display:flex; justify-content:flex-end; gap:5px; padding:0; }
        .mermaid-toolbar button { border:1px solid var(--line); border-radius:5px; background:var(--bg); color:var(--fg); min-width:28px; padding:3px 8px; }
        .mermaid-viewport { min-height:120px; overflow:auto; padding:4px 0 18px; cursor:grab; touch-action:none; }
        .mermaid-viewport.dragging { cursor:grabbing; }
        .mermaid-stage { width:max-content; min-width:0; transform-origin:0 0; transition:transform .12s ease-out; }
        .mermaid-stage svg { display:block; margin:0; max-width:none !important; }
        .mermaid-error { padding:14px 16px; color:#b42318; white-space:pre-wrap; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; }
        .table-wrap { width:calc(100vw - 36px); margin:1.35em 0 2em; position:relative; left:50%; transform:translateX(-50%); overflow:auto; background:var(--bg); }
        table { width:auto; min-width:0; max-width:100%; border:1px solid var(--line); border-radius:5px; border-spacing:0; border-collapse:separate; font-size:.96em; line-height:1.42; font-variant-numeric:tabular-nums; color:var(--fg); overflow:hidden; }
        th,td { padding:10px 12px; border-right:1px solid var(--soft-line); border-bottom:1px solid var(--soft-line); text-align:left; vertical-align:top; overflow-wrap:anywhere; }
        th:last-child,td:last-child { border-right:0; } tbody tr:last-child td { border-bottom:0; }
        th { position:sticky; top:0; z-index:1; height:54px; background:var(--table-head); font-weight:650; vertical-align:middle; }
        html[data-style='swiss'] table { margin:1.5rem 0; table-layout:fixed; border-color:rgba(0,0,0,.08); border-radius:6px; font-size:.9375rem; line-height:1.5; }
        html[data-style='swiss'] th,html[data-style='swiss'] td { padding:.75rem 1rem; vertical-align:middle; border-color:rgba(0,0,0,.06); }
        html[data-style='swiss'] th { height:auto; background:rgba(0,0,0,.04); font-weight:700; }
        html[data-style='swiss'] tbody tr:nth-child(odd) td { background:rgba(0,0,0,.01); }
        html[data-style='swiss'] tbody tr:nth-child(even) td { background:rgba(0,0,0,.02); }
        td code { padding:0; background:transparent; color:inherit; }
        html[data-style='swiss'] .table-wrap,html[data-style='everforest-light'] .table-wrap { width:100%; left:auto; transform:none; }
        html[data-style='swiss'] .table-wrap { margin:1.5rem 0; }
        html[data-style='everforest-light'] td code { padding:.06em .25em; color:#d69900; background:#f3ead3; }
        html[data-style='everforest-light'] a { color:#35a77c; }
        table.history-table { width:auto; table-layout:auto; }
        table.history-table th:nth-child(1),table.history-table td:nth-child(1) { min-width:180px; overflow-wrap:normal; word-break:normal; }
        table.history-table th:nth-child(2),table.history-table td:nth-child(2) { min-width:70px; }
        table.history-table th:nth-last-child(2),table.history-table td:nth-last-child(2) { min-width:72px; text-align:center; }
        table.history-table th:last-child,table.history-table td:last-child { min-width:72px; text-align:center; }
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
        window.keenConfigure=(theme,style,size,width)=>{ document.documentElement.dataset.theme=theme; document.documentElement.dataset.style=style; document.documentElement.style.setProperty('--font-size',size+'px'); document.documentElement.style.setProperty('--reading-width',width+'px'); };
        </script>\(mermaidRuntime)</body></html>
        """
    }

    private static let mermaidBootstrap = #"""
    (() => {
      const shells = [...document.querySelectorAll('.mermaid-shell')];
      if (!shells.length || typeof mermaid === 'undefined') return;
      const dark = document.documentElement.dataset.style !== 'everforest-light' &&
        (document.documentElement.dataset.theme === 'dark' ||
        (document.documentElement.dataset.theme === 'system' && matchMedia('(prefers-color-scheme: dark)').matches));
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
        const box = svg.viewBox?.baseVal;
        const naturalWidth = box?.width || svg.getBoundingClientRect().width || 1;
        const naturalHeight = box?.height || svg.getBoundingClientRect().height || 1;
        svg.style.width = `${naturalWidth}px`;
        svg.style.height = `${naturalHeight}px`;
        stage.style.width = `${naturalWidth}px`;
        stage.style.height = `${naturalHeight}px`;
        stage.dataset.scale = Math.min(1, (viewport.clientWidth - 8) / naturalWidth).toFixed(3);
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
        let headerCells = Array(table.head.children)
        let columnCount = headerCells.count
        let headerTitles = headerCells.map { plainText($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let isHistoryTable = headerTitles == ["时间", "版本", "描述", "作者", "审核人"]
        let tableClasses = isHistoryTable ? "columns-\(columnCount) history-table" : "columns-\(columnCount)"
        let header = headerCells.map { cell in
            "<th>\(renderChildren(cell))</th>"
        }.joined()
        let rows = table.body.children.map { row in
            let cells = row.children.map { cell in
                "<td>\(renderChildren(cell))</td>"
            }.joined()
            return "<tr>\(cells)</tr>"
        }.joined()
        return "<div class=\"table-wrap\"><table class=\"\(tableClasses)\"><thead><tr>\(header)</tr></thead><tbody>\(rows)</tbody></table></div>"
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
