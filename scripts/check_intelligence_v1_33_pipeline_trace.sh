#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Intelligence V1.33 -- read-only verification of the pipeline-trace claims in the V1.33 document against the source tree:
# stage ORDER in ASRService.stop and ContentView.processStoppedTranscription (the Intelligence/AI hand-off precedes the GAAV and
# continuous formatters), the DEFAULT values of the settings the document cites, and the spoken-punctuation prefix. No execution.
python3 <<'PY'
import re, sys
def fail(m): print("FAIL:", m); sys.exit(1)
asr = open("Sources/Fluid/Services/ASRService.swift").read()
cv = open("Sources/Fluid/ContentView.swift").read()
st = open("Sources/Fluid/Persistence/SettingsStore.swift").read()

# ASRService.stop: fillers -> dictionary -> spoken punctuation, single full-audio provider call.
s = asr[asr.index("    func stop("):]
s = s[:s.index("    private func beginDeferredStopUIInvalidation")]
order = ["provider.transcribeFinal(pcm)", "ASRService.removeFillerWords(result.text)", "ASRService.applyCustomDictionary(textWithoutFillers)", "ASRService.applySpokenPunctuationFormatting(dictionaryText)"]
pos = [s.find(x) for x in order]
if min(pos) < 0 or pos != sorted(pos): fail(f"stop() stage order differs: {pos}")

# ContentView.processStoppedTranscription order.
f = cv[cv.index("private func processStoppedTranscription"):cv.index("private func reprocessDictationText") if cv.index("private func processStoppedTranscription") < cv.index("private func reprocessDictationText") else len(cv)]
steps = ["ASRService.applySpokenPunctuationFormatting(", "SpokenSendParser.parse(", "LegalDictationProcessor.shared.process(", "processTextWithAIMetrics(", "ASRService.applyDictationLiteralFormatting(", "ASRService.applyGAAVFormatting(", "ASRService.applyContinuousDictationFormatting(", "ASRService.applyTerminalLiteralAutocompleteSpacing("]
pos = [f.find(x) for x in steps]
if min(pos) < 0 or pos != sorted(pos): fail(f"processStoppedTranscription order differs: {pos}")

# Defaults cited in the document.
def default(prop, value):
    m = re.search(r"var " + prop + r": Bool \{\s*get \{\s*[^\n]*\?\? (true|false|self\.\w+)", st)
    if not m or m.group(1) != value: fail(f"default of {prop} is {m.group(1) if m else None}, expected {value}")
default("removeFillerWordsEnabled", "true")
default("autoConvertPunctuationEnabled", "true")
default("spokenSendEnabled", "false")
default("literalDictationFormattingEnabled", "false")
default("gaavModeEnabled", "false")
default("continuousDictationModeEnabled", "false")
default("gaavRemoveTrailingPeriodEnabled", "self.gaavModeEnabled")
default("gaavLowercaseFirstLetterEnabled", "self.gaavModeEnabled")
default("continuousDictationSpacingEnabled", "self.continuousDictationModeEnabled")
default("contextAwareCapitalizationEnabled", "self.continuousDictationModeEnabled")
if 'static let defaultPunctuationDictionaryPrefix = "literal"' not in st: fail("default spoken-punctuation prefix is not 'literal'")
if "self.recordingPrecedingText = TypingService.textBeforeCursorInFocusedField()" not in cv: fail("preceding-text capture changed")
if "providerText: result.text" not in asr: fail("API seam no longer returns provider text")
print("PASS: V1.33 pipeline-trace claims verified against the source (stage order, defaults, prefix, context capture, API provider-text seam)")
PY
