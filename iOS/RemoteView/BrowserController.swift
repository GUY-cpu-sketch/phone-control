import Foundation
import WebKit
import UIKit
import Combine

@MainActor
final class BrowserController: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published var currentURL = "https://www.google.com"
    @Published var pageTitle = ""
    @Published var canGoBack = false
    @Published var canGoForward = false

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: URL(string: currentURL)!))
    }

    func navigate(_ value: String) {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if !text.contains("://") {
            if text.contains(" ") {
                text = "https://www.google.com/search?q=" + (text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
            } else {
                text = "https://" + text
            }
        }
        guard let url = URL(string: text) else { return }
        currentURL = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func goBack() { if webView.canGoBack { webView.goBack() } }
    func goForward() { if webView.canGoForward { webView.goForward() } }
    func reload() { webView.reload() }

    func scroll(deltaY: CGFloat) {
        let y = max(0, webView.scrollView.contentOffset.y + deltaY)
        webView.scrollView.setContentOffset(CGPoint(x: webView.scrollView.contentOffset.x, y: y), animated: true)
    }

    func tap(x: CGFloat, y: CGFloat) {
        let js = """
        (() => {
          const x = \(Int(x)); const y = \(Int(y));
          const el = document.elementFromPoint(x, y);
          if (!el) return;
          el.focus?.();
          el.click?.();
        })();
        """
        webView.evaluateJavaScript(js)
    }

    func typeText(_ text: String) {
        let data = try? JSONSerialization.data(withJSONObject: [text])
        let encoded = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        let js = """
        (() => {
          const value = \(encoded)[0];
          const el = document.activeElement;
          if (!el) return;
          if ('value' in el) {
            const setter = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(el), 'value')?.set;
            if (setter) setter.call(el, value); else el.value = value;
            el.dispatchEvent(new Event('input', {bubbles:true}));
            el.dispatchEvent(new Event('change', {bubbles:true}));
          }
        })();
        """
        webView.evaluateJavaScript(js)
    }

    func snapshotJPEG(completion: @escaping (Data?) -> Void) {
        let config = WKSnapshotConfiguration()
        config.rect = webView.bounds
        webView.takeSnapshot(with: config) { image, _ in
            completion(image?.jpegData(compressionQuality: 0.48))
        }
    }

    func navigationState() -> [String: Any] {
        [
            "type": "browser-state",
            "url": webView.url?.absoluteString ?? currentURL,
            "title": webView.title ?? "",
            "canGoBack": webView.canGoBack,
            "canGoForward": webView.canGoForward, "viewportWidth": webView.bounds.width, "viewportHeight": webView.bounds.height
        ]
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        currentURL = webView.url?.absoluteString ?? currentURL
        pageTitle = webView.title ?? ""
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }
}
