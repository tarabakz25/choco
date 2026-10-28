import Foundation
import WebKit

/// Turns the Chrome Web Store's "Add to Chrome" button, which is disabled outside Chrome, into an "Add to Choco" button.
/// The page script only relabels and enables the button and reports the click; Swift decides what the click means.
enum StoreInstallBridge {
    static let handlerName = "chocoStoreInstall"

    static func makeScript() -> WKUserScript { WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true) }

    static let source = """
    (() => {
      const host = location.hostname;
      if (host !== 'chromewebstore.google.com' && host !== 'chrome.google.com') return;
      const ja = (document.documentElement.lang || navigator.language || '').toLowerCase().startsWith('ja');
      const label = ja ? 'Choco に追加' : 'Add to Choco';
      const busyLabel = ja ? '追加中…' : 'Adding…';
      // The store's class names are generated; the filled primary button is the install button, and its label is a [jsname=V67aGc] span.
      const isInstallLabel = (text) => /^(Chrome に追加|Add to Chrome)$/.test(text.trim()) || text === label || text === busyLabel;
      const handled = new WeakSet();
      let busy = false;
      // Styled through CSSOM and Web Animations, which a page's Content Security Policy does not restrict.
      const spinner = document.createElement('span');
      Object.assign(spinner.style, { display: 'inline-block', width: '14px', height: '14px', marginRight: '8px', verticalAlign: '-2px',
                                     border: '2px solid currentColor', borderTopColor: 'transparent', borderRadius: '50%', boxSizing: 'border-box' });
      spinner.animate([{ transform: 'rotate(0deg)' }, { transform: 'rotate(360deg)' }], { duration: 800, iterations: Infinity });
      const onClick = (event) => {
        event.preventDefault();
        event.stopImmediatePropagation();
        // The store's own script clicks buttons programmatically; only a real click is the user's request.
        if (!event.isTrusted || busy) return;
        busy = true;
        apply();
        window.webkit.messageHandlers.\(handlerName).postMessage({});
      };
      // Called by the app when the install flow has ended, whatever its outcome.
      window.__chocoStoreInstallFinished = () => { busy = false; apply(); };
      const apply = () => {
        for (const button of document.querySelectorAll('main button')) {
          const text = button.querySelector('[jsname="V67aGc"]');
          if (!text || !isInstallLabel(text.textContent)) continue;
          const wanted = busy ? busyLabel : label;
          if (text.textContent !== wanted) text.textContent = wanted;
          if (busy) {
            if (spinner.nextSibling !== text) text.before(spinner);
            button.setAttribute('aria-busy', 'true');
          } else {
            spinner.remove();
            button.removeAttribute('aria-busy');
          }
          button.style.cursor = busy ? 'progress' : '';
          if (button.disabled) button.disabled = false;
          button.removeAttribute('disabled');
          button.removeAttribute('aria-describedby');
          if (!handled.has(button)) {
            handled.add(button);
            button.addEventListener('click', onClick, true);
          }
        }
      };
      let scheduled = false;
      const schedule = () => {
        if (scheduled) return;
        scheduled = true;
        requestAnimationFrame(() => { scheduled = false; apply(); });
      };
      new MutationObserver(schedule).observe(document, { childList: true, subtree: true, attributes: true, attributeFilter: ['disabled'], characterData: true });
      schedule();
    })();
    """
}

/// Forwards script messages without letting the user content controller retain the session.
@MainActor final class StoreInstallMessageHandler: NSObject, WKScriptMessageHandler {
    private let onRequest: (WKScriptMessage) -> Void

    init(onRequest: @escaping (WKScriptMessage) -> Void) { self.onRequest = onRequest }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        onRequest(message)
    }
}
