import Foundation

/// Scroll and activity captured from a page before its web view is discarded.
public struct PageMemoryProbe: Equatable, Sendable {
    public var scrollX: Double
    public var scrollY: Double
    public var isPlayingAudio: Bool
    public var hasUnsavedFormInput: Bool

    public init(scrollX: Double, scrollY: Double, isPlayingAudio: Bool, hasUnsavedFormInput: Bool) {
        self.scrollX = scrollX.isFinite ? max(0, scrollX) : 0
        self.scrollY = scrollY.isFinite ? max(0, scrollY) : 0
        self.isPlayingAudio = isPlayingAudio
        self.hasUnsavedFormInput = hasUnsavedFormInput
    }
}

public struct PageScrollOffset: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x.isFinite ? max(0, x) : 0
        self.y = y.isFinite ? max(0, y) : 0
    }
}

/// JavaScript that reads scroll position, media playback, and unsaved form edits.
/// JavaScriptCore tests run this against a fake document. WebKit runs the same source.
enum PageMemoryScript {
    static let source = """
    (() => {
      const root = document.scrollingElement || document.documentElement || {};
      const rawX = window.scrollX;
      const rawY = window.scrollY;
      const x = Number(rawX == null ? (root.scrollLeft || 0) : rawX);
      const y = Number(rawY == null ? (root.scrollTop || 0) : rawY);
      const playingAudio = Array.from(document.querySelectorAll('audio,video')).some((el) => {
        if (!el || el.paused || el.ended || el.muted) return false;
        if (typeof el.volume === 'number' && el.volume <= 0) return false;
        return Number(el.readyState || 0) >= 2;
      });
      const dirtyControl = Array.from(document.querySelectorAll('input,textarea,select')).some((el) => {
        if (!el || el.disabled) return false;
        const type = String(el.getAttribute ? (el.getAttribute('type') || '') : '').toLowerCase();
        if (type === 'hidden' || type === 'submit' || type === 'button' || type === 'reset' || type === 'image') return false;
        if (type === 'checkbox' || type === 'radio') return !!el.checked !== !!el.defaultChecked;
        if (String(el.tagName || '').toUpperCase() === 'SELECT') {
          return Array.from(el.options || []).some((option) => !!option.selected !== !!option.defaultSelected);
        }
        return String(el.value || '') !== String(el.defaultValue || '');
      });
      const active = document.activeElement;
      const composing = !!(active && active.isContentEditable);
      return JSON.stringify({
        x: Number.isFinite(x) ? x : 0,
        y: Number.isFinite(y) ? y : 0,
        playingAudio: playingAudio,
        dirtyForm: dirtyControl || composing
      });
    })()
    """

    struct Payload: Decodable {
        var x: Double
        var y: Double
        var playingAudio: Bool
        var dirtyForm: Bool
    }

    static func decode(value: Any?) -> PageMemoryProbe? {
        if let json = value as? String { return decode(json: json) }
        if let json = value as? NSString { return decode(json: json as String) }
        return nil
    }

    static func decode(json: String) -> PageMemoryProbe? {
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }
        return PageMemoryProbe(scrollX: payload.x, scrollY: payload.y, isPlayingAudio: payload.playingAudio, hasUnsavedFormInput: payload.dirtyForm)
    }
}
