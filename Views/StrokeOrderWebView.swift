import SwiftUI
import WebKit

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

            Text("Animation data is bundled for offline use; missing characters can be generated from known components.")
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
            let result = StrokeAnimationProvider.shared.animationData(for: character)
            let strokeData = result.json ?? "null"
            let status = statusMessage(for: result)
            let statusLiteral = Self.javascriptLiteral(status)
            let js = "window.renderCharacter(\(characterLiteral), \(size), \(strokeData), \(statusLiteral));"
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

        private func statusMessage(for result: StrokeAnimationResult) -> String {
            switch result.source {
            case .bundled:
                return ""
            case .generatedStored, .generatedLive:
                return result.explanation ?? "Generated from components"
            case .unavailable:
                return result.explanation ?? "No stroke animation available"
            }
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
            #wrap { position:relative; display:flex; align-items:center; justify-content:center; width:100%; height:100%; }
            #target { margin: auto; }
            #status { position:absolute; left:4px; right:4px; bottom:2px; min-height:14px; font-size:11px; color:#777; text-align:center; line-height:1.2; }
            #status:empty { display:none; }
          </style>
          <script>\(scriptContent)</script>
        </head>
        <body>
          <div id=\"wrap\"><div id=\"target\"></div><div id=\"status\"></div></div>
          <script>
            let writer = null;
            window.clearCharacter = function() {
              const target = document.getElementById('target');
              const status = document.getElementById('status');
              target.innerHTML = '';
              status.textContent = '';
              writer = null;
            };
            window.renderCharacter = function(ch, size, bundledData, statusText) {
              const target = document.getElementById('target');
              const status = document.getElementById('status');
              target.style.width = size + 'px';
              target.style.height = size + 'px';
              target.innerHTML = '';
              status.textContent = statusText || '';
              if (!bundledData) {
                writer = null;
                return;
              }
              writer = HanziWriter.create('target', ch, {
                width: size,
                height: size,
                padding: 5,
                showOutline: true,
                strokeAnimationSpeed: 1.2,
                delayBetweenStrokes: 120,
                delayBetweenLoops: 800,
                charDataLoader: function(char, onComplete, onError) {
                  onComplete(bundledData);
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
