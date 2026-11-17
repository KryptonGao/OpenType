import SwiftUI

struct ScreenAskView: View {
    @Bindable var controller: ScreenAskController
    @FocusState private var focused: Bool

    /// Glass over a busy screenshot can wash out text; a window-colored tint keeps it readable in light and dark.
    private static let legibleGlass = Glass.regular.tint(Color(nsColor: .windowBackgroundColor).opacity(0.55))

    private struct ScrollFade: Equatable { var top = false, bottom = false }
    @State private var fade = ScrollFade()

    /// Soft edges where the reply continues past the visible height; the edge at the scroll limit stays crisp.
    private var fadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [fade.top ? .clear : .black, .black], startPoint: .top, endPoint: .bottom).frame(height: 26)
            Rectangle()
            LinearGradient(colors: [.black, fade.bottom ? .clear : .black], startPoint: .top, endPoint: .bottom).frame(height: 26)
        }
        .animation(.easeOut(duration: 0.15), value: fade)
    }

    private var showsAnswer: Bool { controller.isLoading || !controller.answer.isEmpty }

    private var inputRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "siri").font(.system(size: 22)).foregroundStyle(.primary)
            TextField("Ask", text: $controller.question, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .foregroundStyle(.primary)
                .lineLimit(1...4)
                .focused($focused)
                .onSubmit { controller.submit() }
                .disabled(controller.isLoading || controller.voiceState != .idle)
            Button(action: controller.toggleVoice) {
                Image(systemName: controller.voiceState == .recording ? "stop.fill" : "mic")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(controller.voiceState == .recording ? Color.red : Color.primary)
            .disabled(controller.isLoading || controller.voiceState == .transcribing)
            .help(controller.voiceState == .recording ? String(localized: "结束录音") : String(localized: "语音输入"))
            if controller.isLoading {
                Button(action: controller.stop) { Image(systemName: "stop.circle.fill").font(.title2) }
                    .buttonStyle(.plain)
                    .help("停止生成")
            } else {
                Button(action: controller.submit) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                    .buttonStyle(.plain)
                    .disabled(controller.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || controller.voiceState != .idle)
                    .help("发送")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    private var answerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Ask", systemImage: "siri").font(.headline)
                Spacer()
                if controller.isLoading { ProgressView().controlSize(.small) }
                else {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(controller.answer, forType: .string)
                    } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.plain)
                    .help("复制")
                }
            }
            if let status = controller.webSearchStatus ?? (controller.isLoading ? nil : controller.webSearchNote) {
                Label(status, systemImage: "globe")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !controller.answer.isEmpty {
                ScrollView {
                    MarkdownContent(controller.answer, fontSize: 14, animatesNewText: controller.isLoading)
                }
                .onScrollGeometryChange(for: ScrollFade.self) { geometry in
                    ScrollFade(top: geometry.contentOffset.y > 1,
                               bottom: geometry.contentOffset.y + geometry.containerSize.height < geometry.contentSize.height - 1)
                } action: { _, new in fade = new }
                .mask(fadeMask)
                .frame(maxHeight: 300)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    inputRow
                    if showsAnswer {
                        Divider().padding(.horizontal, 18).opacity(0.6)
                        answerSection
                    }
                }
                .glassEffect(Self.legibleGlass.interactive(), in: .rect(cornerRadius: 26))
                .animation(.smooth(duration: 0.25), value: showsAnswer)

                HStack(spacing: 10) {
                    Button(action: controller.searchImage) {
                        Label("Image Search", systemImage: "photo.badge.magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(Self.legibleGlass.interactive(), in: .capsule)
                    Spacer(minLength: 0)
                    Button(action: controller.close) {
                        Image(systemName: "xmark").frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(Self.legibleGlass.interactive(), in: .circle)
                    .help("关闭")
                }

                if controller.voiceState != .idle {
                    Label(controller.voiceState == .recording ? String(localized: "正在录音…") : String(localized: "正在转写…"), systemImage: "waveform")
                        .font(.callout)
                        .padding(12)
                        .glassEffect(Self.legibleGlass, in: .capsule)
                }
                if let error = controller.error {
                    Text(error).font(.callout).foregroundStyle(.red)
                        .textSelection(.enabled)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(Self.legibleGlass, in: .rect(cornerRadius: 16))
                }
            }
        }
        .frame(width: 380)
        // Generous margin so the glass' soft shadow is not clipped by the window edge.
        .padding(28)
        .gesture(WindowDragGesture())
        .onChange(of: controller.isLoading) { _, loading in focused = !loading }
        .onChange(of: controller.voiceState) { _, state in focused = state == .idle }
        .task {
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled else { return }
            focused = true
        }
    }
}
