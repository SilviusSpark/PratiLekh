import AVFoundation
import SwiftUI

/// Presentation states only. Recording and delivery remain owned by ContentView/ASRService.
enum RecordingPresentationState: String, CaseIterable {
    case ready, listening, transcribing, processing, cancelled, error, loading, unavailable

    var title: String {
        switch self {
        case .ready: "Ready to record"
        case .listening: "Listening"
        case .transcribing: "Transcribing"
        case .processing: "Processing text"
        case .cancelled: "Recording cancelled"
        case .error: "Dictation error"
        case .loading: "Preparing speech model"
        case .unavailable: "Speech model not ready"
        }
    }

    var symbol: String {
        switch self {
        case .ready: "mic"
        case .listening: "waveform"
        case .transcribing, .processing: "text.alignleft"
        case .cancelled: "xmark.circle"
        case .error: "exclamationmark.triangle"
        case .loading: "hourglass"
        case .unavailable: "waveform.badge.exclamationmark"
        }
    }
}

struct RecordingStatus: View {
    @Environment(\.theme) private var theme
    let state: RecordingPresentationState
    var message: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(self.state.title, systemImage: self.state.symbol)
                .font(self.theme.typography.bodyStrong)
                .foregroundStyle(self.state == .error ? Color(nsColor: .systemRed) : self.theme.palette.accent)
            if let message, !message.isEmpty {
                Text(message)
                    .font(self.theme.typography.caption)
                    .foregroundStyle(self.theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct RecordingControls: View {
    @ObservedObject private var asr = AppServices.shared.asr
    @ObservedObject private var presentation = NotchContentState.shared
    @Environment(\.theme) private var theme
    let stop: () async -> Void
    let start: () -> Void

    private var state: RecordingPresentationState {
        let asr = self.asr
        if self.presentation.isTranscribing { return .transcribing }
        if self.presentation.isProcessing { return .processing }
        if asr.isRunningOrStarting { return .listening }
        if asr.showError || asr.micStatus == .denied || asr.micStatus == .restricted { return .error }
        if self.presentation.recordingWasCancelled { return .cancelled }
        if asr.isAsrReady { return .ready }
        return asr.isLoadingModel || asr.isDownloadingModel ? .loading : .unavailable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RecordingStatus(
                state: self.state,
                message: self.state == .error
                    ? (self.asr.micStatus == .denied || self.asr.micStatus == .restricted
                        ? "Microphone access is unavailable. Review PratiLekh’s access in System Settings → Privacy & Security → Microphone."
                        : self.asr.errorMessage)
                    : (self.state == .unavailable ? "Choose a speech model in Voice Engine." : nil)
            )
            RecordingActionButtons(
                isRecording: self.asr.isRunning,
                canBegin: !self.presentation.isTranscribing && !self.presentation.isProcessing && self.asr.isAsrReady,
                canCancel: self.asr.isRunningOrStarting,
                stop: { Task { await self.stop() } },
                start: self.start,
                cancel: { self.presentation.onCancelRequested?() }
            )
        }
        .onChange(of: self.asr.isRunning) { _, running in
            if running { self.presentation.recordingWasCancelled = false }
        }
    }
}

struct RecordingActionButtons: View {
    let isRecording: Bool
    let canBegin: Bool
    let canCancel: Bool
    let stop: () -> Void
    let start: () -> Void
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: self.isRecording ? self.stop : self.start) {
                Label(
                    self.isRecording ? "Stop recording" : "Start recording",
                    systemImage: self.isRecording ? "stop.fill" : "mic.fill"
                )
            }
            .buttonStyle(PremiumButtonStyle(height: 44))
            .focusable()
            .frame(maxWidth: 220)
            .disabled(!self.isRecording && !self.canBegin)
            .help(self.isRecording ? "Stop capture and transcribe your recording." : "Begin recording from your microphone.")
            if self.canCancel {
                Button("Cancel", action: self.cancel)
                    .buttonStyle(.bordered)
                    .focusable()
                    .help("Discard this recording without transcription.")
                    .accessibilityLabel("Cancel and discard recording")
            }
        }
    }
}

struct RecordingView: View {
    @Environment(\.theme) private var theme
    @Binding var appear: Bool
    let stopAndProcessTranscription: () async -> Void
    let startRecording: () -> Void

    var body: some View {
        ScrollView {
            ThemedCard(style: .standard) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        PratiLekhMark().stroke(self.theme.palette.accent, lineWidth: 2).frame(width: 40, height: 40)
                        Text("Dictation").font(self.theme.typography.title)
                    }
                    RecordingControls(stop: self.stopAndProcessTranscription, start: self.startRecording)
                }
                .padding(16)
            }
            .padding(16)
        }
    }
}

struct DictationOverlayControls: View {
    @Environment(\.theme) private var theme
    let state: RecordingPresentationState
    let stop: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                PratiLekhMark().stroke(self.theme.palette.accent, lineWidth: 1.2)
                    .frame(width: 16, height: 16).accessibilityHidden(true)
                Label(self.state.title, systemImage: self.state.symbol)
            }
                .font(self.theme.typography.captionStrong)
                .foregroundStyle(self.theme.palette.primaryText)
                .accessibilityElement(children: .combine)
            if self.state == .listening {
                HStack(spacing: 12) {
                    Button("Stop", action: self.stop)
                        .buttonStyle(PremiumButtonStyle(height: 28))
                        .focusable()
                        .frame(width: 76)
                        .help("Stop capture and transcribe")
                        .accessibilityLabel("Stop recording and transcribe")
                    Button("Cancel", action: self.cancel)
                        .buttonStyle(.bordered)
                        .focusable()
                        .help("Discard recording without transcription")
                        .accessibilityLabel("Cancel and discard recording")
                }
            }
        }
    }
}

#if DEBUG
/// In-memory UI evidence. No capture, provider calls or history persistence.
struct MilestoneTwoReviewView: View {
    @Environment(\.theme) private var theme
    @State private var state = RecordingPresentationState.listening

    static let longHistoryEntry = TranscriptionHistoryEntry(
        rawText: String(repeating: "The hearing is on 12 October at 10 am. कृपया फ़ाइल २७ साथ लाएँ।\n\n", count: 30),
        processedText: String(repeating: "The hearing is on 12 October at 10 am. कृपया फ़ाइल २७ साथ लाएँ।\n\n", count: 30),
        appName: "Long-text preview",
        windowTitle: "Synthetic fixture",
        wasAIProcessed: false
    )

    static let historyEntries = [
        TranscriptionHistoryEntry(
            timestamp: Date(timeIntervalSince1970: 1_790_812_800),
            rawText: "The hearing is on 12 October at 10 am please bring file 27",
            processedText: "The hearing is on 12 October at 10 am. Please bring file 27.",
            appName: "Preview document",
            windowTitle: "Synthetic fixture",
            wasAIProcessed: true,
            processingModel: "Illustrative formatting"
        ),
        TranscriptionHistoryEntry(
            timestamp: Date(timeIntervalSince1970: 1_790_809_200),
            rawText: "अगली सुनवाई १२ अक्टूबर को सुबह १० बजे होगी। कृपया फ़ाइल २७ साथ लाएँ।",
            processedText: "अगली सुनवाई १२ अक्टूबर को सुबह १० बजे होगी। कृपया फ़ाइल २७ साथ लाएँ।",
            appName: "Hindi preview",
            windowTitle: "Synthetic fixture",
            wasAIProcessed: false
        ),
        TranscriptionHistoryEntry(
            timestamp: Date(timeIntervalSince1970: 1_790_805_600),
            rawText: "We received 3 documents today the next review is on 14 October",
            processedText: "We received 3 documents today the next review is on 14 October",
            appName: "Error preview",
            windowTitle: "Synthetic fixture",
            wasAIProcessed: false,
            aiProcessingError: "Synthetic provider error. No request was sent."
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recording review").font(self.theme.typography.title)
                Text("Synthetic states — no audio capture or processing. Overlay embedded for review; not a floating-window capture.")
                    .font(self.theme.typography.caption)
                    .foregroundStyle(self.theme.palette.secondaryText)
                Picker("Recording state", selection: self.$state) {
                    ForEach(RecordingPresentationState.allCases, id: \.self) { state in
                        Text(state.title).tag(state)
                    }
                }
                ThemedCard(style: .standard) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            PratiLekhMark().stroke(self.theme.palette.accent, lineWidth: 2)
                                .frame(width: 32, height: 32)
                            Text("Dictation").font(self.theme.typography.sectionTitle)
                        }
                        RecordingStatus(state: self.state, message: self.state == .error ? "Synthetic microphone permission denied. Enable access in System Settings." : nil)
                        RecordingActionButtons(
                            isRecording: self.state == .listening,
                            canBegin: self.state == .ready || self.state == .cancelled,
                            canCancel: self.state == .listening,
                            stop: {},
                            start: {},
                            cancel: {}
                        )
                        Text("अगली सुनवाई १२ अक्टूबर को सुबह १० बजे होगी।")
                            .font(.system(size: 16)).textSelection(.enabled)
                    }
                    .padding(16)
                }
                Text("Overlay component — synthetic state").font(self.theme.typography.captionStrong)
                BottomOverlayView(reviewState: self.state)
                    .allowsHitTesting(false)
            }
            .padding(16)
        }
    }
}
#endif
