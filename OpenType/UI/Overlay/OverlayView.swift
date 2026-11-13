import SwiftUI

struct OverlayView: View {
    let coordinator: DictationSessionCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                statusIcon
                Text(statusTitle)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                trailingControl
            }

            if let status = coordinator.webSearchStatus, coordinator.state == .processing {
                Label(status, systemImage: "magnifyingglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let target = coordinator.translationTarget {
                translationPicker(target)
            }

            if showsWaveform {
                WaveformView(levels: coordinator.levelHistory, color: statusColor)
                    .frame(height: 26)
            }

            if showsTranscript {
                Text("\(Text(coordinator.solidText).foregroundStyle(.primary))\(Text(coordinator.stashText).foregroundStyle(.secondary))")
                    .font(.body)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !coordinator.pendingText.isEmpty, showsPendingText {
                Text(coordinator.pendingText)
                    .font(.body)
                    .textSelection(.enabled)
                    .lineLimit(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                HStack {
                    Button("复制文本") { coordinator.copyPendingText() }
                        .buttonStyle(.borderedProminent)
                    Button("关闭") { coordinator.cancelSession() }
                    Spacer()
                    Text("按 Esc 关闭").font(.caption).foregroundStyle(.secondary)
                }
                .controlSize(.small)
            } else if case .error = coordinator.state {
                HStack {
                    Spacer()
                    Button("关闭") { coordinator.cancelSession() }.controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.separator.opacity(0.5)))
        .padding(8) // room for the window shadow
    }

    /// Popup row: translation target language, pre-selected from Settings and changeable until processing starts.
    private func translationPicker(_ target: TranslationLanguage) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "character.bubble").foregroundStyle(.secondary)
            Text("翻译为").foregroundStyle(.secondary)
            Menu {
                ForEach(TranslationLanguage.allCases) { language in
                    Button {
                        coordinator.setTranslationTarget(language)
                    } label: {
                        if language == target {
                            Label(language.displayName, systemImage: "checkmark")
                        } else {
                            Text(language.displayName)
                        }
                    }
                }
            } label: {
                Text(target.displayName)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(!coordinator.canChangeTranslationTarget)
            if !target.regions.isEmpty {
                Text("用语").foregroundStyle(.secondary)
                Menu {
                    ForEach(target.regions) { region in
                        Button {
                            coordinator.setTranslationRegion(region)
                        } label: {
                            if region == coordinator.translationRegion {
                                Label(region.displayName, systemImage: "checkmark")
                            } else {
                                Text(region.displayName)
                            }
                        }
                    }
                } label: {
                    Text(coordinator.translationRegion?.displayName ?? target.regions[0].displayName)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(!coordinator.canChangeTranslationTarget)
            }
            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    // MARK: Derived state

    @ViewBuilder private var statusIcon: some View {
        switch coordinator.state {
        case .connecting, .finalizing, .processing, .inserting:
            ProgressView().controlSize(.small)
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .manualCopy:
            Image(systemName: "doc.on.clipboard").foregroundStyle(.orange)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
        case .recording:
            Image(systemName: "mic.fill").foregroundStyle(.red)
        case .idle:
            Image(systemName: "mic").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var trailingControl: some View {
        if coordinator.state == .recording || coordinator.state == .connecting, coordinator.sessionMode == .toggle {
            Button("完成") { coordinator.stopRecording() }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
        }
    }

    private var showsWaveform: Bool {
        coordinator.state == .recording || coordinator.state == .connecting
    }

    private var showsTranscript: Bool {
        switch coordinator.state {
        case .recording, .connecting, .finalizing, .processing: !(coordinator.solidText + coordinator.stashText).isEmpty
        default: false
        }
    }

    private var showsPendingText: Bool {
        switch coordinator.state {
        case .manualCopy, .error: true
        default: false
        }
    }

    private var statusColor: Color {
        coordinator.state == .recording ? .red : .secondary
    }

    private var statusTitle: String {
        switch coordinator.state {
        case .idle: "待机"
        case .connecting: coordinator.isHelpMeSay ? "帮我说 · 正在连接…" : "正在连接…"
        case .recording:
            switch (coordinator.isHelpMeSay, coordinator.sessionMode) {
            case (true, .hold): "帮我说 · 正在聆听…（松开结束）"
            case (true, .toggle): "帮我说 · 正在聆听…（再按一次结束）"
            case (false, .hold): "正在聆听…（松开结束）"
            case (false, .toggle): "正在聆听…（再按一次结束）"
            }
        case .finalizing: "正在收尾…"
        case .processing:
            coordinator.isHelpMeSay ? "正在帮你说…" : coordinator.translationTarget == nil ? "正在整理文本…" : "正在翻译…"
        case .inserting: "正在插入…"
        case .success(let note): note.map { "已插入 · \($0)" } ?? "已插入"
        case .manualCopy(let reason): "未自动插入：\(reason)"
        case .error(let message): message
        }
    }
}

private struct WaveformView: View {
    let levels: [Float]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let count = levels.count
            let spacing: CGFloat = 3
            let barWidth = max(2, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(levels.indices, id: \.self) { index in
                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: barWidth, height: max(3, CGFloat(levels[index]) * proxy.size.height))
                }
            }
            .frame(maxHeight: .infinity)
        }
        .animation(.linear(duration: 0.08), value: levels)
    }
}
