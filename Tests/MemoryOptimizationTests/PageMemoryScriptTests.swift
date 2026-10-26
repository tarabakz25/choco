import Foundation
import JavaScriptCore
import Testing
@testable import BrowserRuntime

@Suite("Memory optimization page probe", .serialized)
struct PageMemoryScriptTests {
    @Test func readsScrollPosition() throws {
        let probe = try probe(scrollX: "12.5", scrollY: "40")
        #expect(probe.scrollX == 12.5)
        #expect(probe.scrollY == 40)
        #expect(!probe.isPlayingAudio)
        #expect(!probe.hasUnsavedFormInput)
    }

    @Test func zeroScrollIsNotReplacedByTheDocumentElement() throws {
        let probe = try probe(scrollX: "0", scrollY: "0", scrollLeft: "80", scrollTop: "90")
        #expect(probe.scrollX == 0)
        #expect(probe.scrollY == 0)
    }

    @Test func missingWindowScrollFallsBackToTheDocument() throws {
        let probe = try probe(scrollY: "3", omitScrollX: true, scrollLeft: "15", scrollTop: "4")
        #expect(probe.scrollX == 15)
        #expect(probe.scrollY == 3)
    }

    @Test func playingUnmutedMediaCountsAsAudio() throws {
        let media = "[{paused:false, ended:false, muted:false, volume:1, readyState:2}]"
        let probe = try probe(media: media)
        #expect(probe.isPlayingAudio)
    }

    @Test func mutedPausedSilentOrUnreadyMediaDoesNotCountAsAudio() throws {
        let muted = try probe(media: "[{paused:false, ended:false, muted:true, volume:1, readyState:2}]")
        let paused = try probe(media: "[{paused:true, ended:false, muted:false, volume:1, readyState:2}]")
        let silent = try probe(media: "[{paused:false, ended:false, muted:false, volume:0, readyState:2}]")
        let unready = try probe(media: "[{paused:false, ended:false, muted:false, volume:1, readyState:1}]")
        #expect(!muted.isPlayingAudio)
        #expect(!paused.isPlayingAudio)
        #expect(!silent.isPlayingAudio)
        #expect(!unready.isPlayingAudio)
    }

    @Test func dirtyTextCheckboxAndSelectCountAsUnsavedInput() throws {
        let text = try probe(controls: """
        [{disabled:false, tagName:'INPUT', value:'hello', defaultValue:'', getAttribute(name){ return 'text'; }}]
        """)
        let checkbox = try probe(controls: """
        [{disabled:false, tagName:'INPUT', checked:true, defaultChecked:false, getAttribute(name){ return 'checkbox'; }}]
        """)
        let select = try probe(controls: """
        [{disabled:false, tagName:'SELECT', options:[{selected:true, defaultSelected:false}], getAttribute(name){ return null; }}]
        """)
        #expect(text.hasUnsavedFormInput)
        #expect(checkbox.hasUnsavedFormInput)
        #expect(select.hasUnsavedFormInput)
    }

    @Test func unchangedHiddenSubmitAndDisabledControlsDoNotCountAsUnsavedInput() throws {
        let same = try probe(controls: """
        [{disabled:false, tagName:'INPUT', value:'hello', defaultValue:'hello', getAttribute(name){ return 'text'; }}]
        """)
        let hidden = try probe(controls: """
        [{disabled:false, tagName:'INPUT', value:'secret', defaultValue:'', getAttribute(name){ return 'hidden'; }}]
        """)
        let submit = try probe(controls: """
        [{disabled:false, tagName:'INPUT', value:'Go', defaultValue:'', getAttribute(name){ return 'submit'; }}]
        """)
        let disabled = try probe(controls: """
        [{disabled:true, tagName:'INPUT', value:'hello', defaultValue:'', getAttribute(name){ return 'text'; }}]
        """)
        #expect(!same.hasUnsavedFormInput)
        #expect(!hidden.hasUnsavedFormInput)
        #expect(!submit.hasUnsavedFormInput)
        #expect(!disabled.hasUnsavedFormInput)
    }

    @Test func focusedContentEditableCountsAsUnsavedInput() throws {
        let probe = try probe(active: "{ isContentEditable: true }")
        #expect(probe.hasUnsavedFormInput)
    }

    @Test func malformedProbePayloadIsIgnored() {
        #expect(PageMemoryScript.decode(json: "") == nil)
        #expect(PageMemoryScript.decode(json: "{") == nil)
        #expect(PageMemoryScript.decode(json: "[]") == nil)
        #expect(PageMemoryScript.decode(json: "{\"x\":1}") == nil)
        #expect(PageMemoryScript.decode(value: 12) == nil)
        let probe = PageMemoryScript.decode(json: "{\"x\":-3,\"y\":4.5,\"playingAudio\":true,\"dirtyForm\":false}")
        #expect(probe == PageMemoryProbe(scrollX: 0, scrollY: 4.5, isPlayingAudio: true, hasUnsavedFormInput: false))
    }

    private func probe(
        scrollX: String = "0",
        scrollY: String = "0",
        omitScrollX: Bool = false,
        scrollLeft: String = "0",
        scrollTop: String = "0",
        media: String = "[]",
        controls: String = "[]",
        active: String = "null"
    ) throws -> PageMemoryProbe {
        let context = JSContext()!
        let failure = ProbeFailure()
        context.exceptionHandler = { _, value in failure.message = value?.toString() }
        let scrollXField = omitScrollX ? "" : "scrollX: \(scrollX),"
        context.evaluateScript("""
        var window = { \(scrollXField) scrollY: \(scrollY) };
        var document = {
          scrollingElement: null,
          documentElement: { scrollLeft: \(scrollLeft), scrollTop: \(scrollTop) },
          activeElement: \(active),
          media: \(media),
          controls: \(controls),
          querySelectorAll(selector) {
            if (selector === 'audio,video') return this.media;
            if (selector === 'input,textarea,select') return this.controls;
            return [];
          }
        };
        """)
        let value = context.evaluateScript(PageMemoryScript.source)
        #expect(failure.message == nil)
        let json = try #require(value?.toString())
        return try #require(PageMemoryScript.decode(json: json))
    }
}

private final class ProbeFailure: @unchecked Sendable {
    var message: String?
}
