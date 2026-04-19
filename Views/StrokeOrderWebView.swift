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

            Text("Animation is loaded from HanziWriter data over HTTPS.")
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
        }

        func render(character: String, size: Int) {
            guard let webView else { return }
            let escapedCharacter = jsEscaped(character)
            let js = "window.renderCharacter('\(escapedCharacter)', \(size));"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        private func jsEscaped(_ input: String) -> String {
            input
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
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
        let coordinator = context.coordinator
        let needsReload =
            coordinator.lastCharacter != character ||
            coordinator.lastToken != reloadToken ||
            coordinator.lastSize != safeSize

        guard needsReload else { return }

        coordinator.lastCharacter = character
        coordinator.lastToken = reloadToken
        coordinator.lastSize = safeSize

        coordinator.pendingCharacter = character
        coordinator.pendingSize = safeSize
        if coordinator.didLoadBootstrap {
            coordinator.render(character: character, size: safeSize)
        }
    }

    private static var cachedScriptContent: String = {
        guard let url = Bundle.main.url(forResource: "hanzi-writer.min", withExtension: "js"),
              let content = try? String(contentsOf: url) else {
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
            window.renderCharacter = function(ch, size) {
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
                delayBetweenLoops: 800
              });
              writer.loopCharacterAnimation();
            };
          </script>
        </body>
        </html>
        """
    }
}
