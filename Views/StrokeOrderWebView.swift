import SwiftUI
import WebKit
import SQLite3

private let SQLITE_TRANSIENT_STROKES = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct StrokeOrderSection: View {
    let character: String
    @State private var reloadToken = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Stroke Order")
                    .font(.headline)
                Spacer()
                Button("Replay") {
                    reloadToken = UUID()
                }
                .buttonStyle(.bordered)
            }

            StrokeOrderWebView(character: character, reloadToken: reloadToken)
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 1)
                )

            Text("Animation data is bundled for offline use; missing characters load over HTTPS.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct StrokeOrderWebView: UIViewRepresentable {
    let character: String
    let reloadToken: UUID
    var canvasSize: Int = 280

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var didLoadBootstrap = false
        var lastCharacter: String = ""
        var lastToken: UUID?
        var lastSize: Int = 0
        var pendingCharacter: String?
        var pendingSize: Int = 0

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            didLoadBootstrap = true
            guard let pendingCharacter else { return }
            render(character: pendingCharacter, size: pendingSize)
            self.pendingCharacter = nil
        }

        func render(character: String, size: Int) {
            guard let webView else { return }
            let characterLiteral = Self.javascriptLiteral(character)
            let strokeData = CharacterStrokeRepository.shared.strokeJSON(for: character) ?? "null"
            let js = "window.renderCharacter(\(characterLiteral), \(size), \(strokeData));"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func clear() {
            webView?.evaluateJavaScript("window.clearCharacter();", completionHandler: nil)
        }

        private static func javascriptLiteral(_ input: String) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: input, options: .fragmentsAllowed),
                  let literal = String(data: data, encoding: .utf8) else {
                let escaped = input
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "\\r")
                return "\"\(escaped)\""
            }
            return literal
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        
        let html = Self.bootstrapHTML(scriptContent: Self.cachedScriptContent)
        webView.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let safeSize = max(80, canvasSize)
        let renderCharacter = character.trimmingCharacters(in: .whitespacesAndNewlines)
        let coordinator = context.coordinator
        let needsReload =
            coordinator.lastCharacter != renderCharacter ||
            coordinator.lastToken != reloadToken ||
            coordinator.lastSize != safeSize

        guard needsReload else { return }

        coordinator.lastCharacter = renderCharacter
        coordinator.lastToken = reloadToken
        coordinator.lastSize = safeSize

        guard renderCharacter.count == 1 else {
            coordinator.pendingCharacter = nil
            if coordinator.didLoadBootstrap {
                coordinator.clear()
            }
            return
        }

        coordinator.pendingCharacter = renderCharacter
        coordinator.pendingSize = safeSize
        if coordinator.didLoadBootstrap {
            coordinator.render(character: renderCharacter, size: safeSize)
            coordinator.pendingCharacter = nil
        }
    }

    private static var cachedScriptContent: String = {
        guard let url = Bundle.main.url(forResource: "hanzi-writer.min", withExtension: "js"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return content
    }()

    private static func bootstrapHTML(scriptContent: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name=\"viewport\" content=\"width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no\" />
          <style>
            html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; font-family: -apple-system; background: transparent; }
            #wrap { display:flex; align-items:center; justify-content:center; width:100%; height:100%; }
            #target { margin: auto; }
          </style>
          <script>\(scriptContent)</script>
        </head>
        <body>
          <div id=\"wrap\"><div id=\"target\"></div></div>
          <script>
            let writer = null;
            window.clearCharacter = function() {
              const target = document.getElementById('target');
              target.innerHTML = '';
              writer = null;
            };
            window.renderCharacter = function(ch, size, bundledData) {
              const target = document.getElementById('target');
              target.style.width = size + 'px';
              target.style.height = size + 'px';
              target.innerHTML = '';
              writer = HanziWriter.create('target', ch, {
                width: size,
                height: size,
                padding: 5,
                showOutline: true,
                strokeAnimationSpeed: 1.2,
                delayBetweenStrokes: 120,
                delayBetweenLoops: 800,
                charDataLoader: function(char, onComplete, onError) {
                  if (bundledData) {
                    onComplete(bundledData);
                    return;
                  }
                  const url = 'https://cdn.jsdelivr.net/npm/hanzi-writer-data@latest/' + encodeURIComponent(char) + '.json';
                  fetch(url)
                    .then(function(response) {
                      if (!response.ok) { throw new Error('Stroke data unavailable'); }
                      return response.json();
                    })
                    .then(onComplete)
                    .catch(function(error) {
                      if (onError) { onError(error); }
                    });
                }
              });
              writer.loopCharacterAnimation();
            };
          </script>
        </body>
        </html>
        """
    }
}

private final class CharacterStrokeRepository: @unchecked Sendable {
    static let shared = CharacterStrokeRepository()

    private var db: OpaquePointer?
    private let lock = NSLock()

    private init() {
        guard let url = Bundle.main.url(forResource: "character_strokes", withExtension: "db") else {
            return
        }

        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            db = nil
        }
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func strokeJSON(for character: String) -> String? {
        let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let db else { return nil }
        lock.lock()
        defer { lock.unlock() }

        let sql = "SELECT data FROM strokes WHERE character = ? LIMIT 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (trimmed as NSString).utf8String, -1, SQLITE_TRANSIENT_STROKES)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let dataPointer = sqlite3_column_text(statement, 0) else {
            return nil
        }

        let json = String(cString: dataPointer)
        guard let data = json.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            return nil
        }

        return json
    }
}
