import SwiftUI

struct PasteCollectionSheet: View {
    @Binding var name: String
    @Binding var text: String
    let onCancel: () -> Void
    let onSave: () -> Void

    private var detectedCharacterCount: Int {
        CaptureTextExtractor.uniqueCharacters(in: text).count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Image Name") {
                    TextField("Name", text: $name)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Paste characters below", systemImage: "doc.on.clipboard")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $text)
                            .frame(minHeight: 180)
                            .overlay(alignment: .topLeading) {
                                if text.isEmpty {
                                    Text(Self.placeholderText)
                                        .foregroundStyle(.tertiary)
                                        .allowsHitTesting(false)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            }
                    }
                } header: {
                    Text("Characters")
                } footer: {
                    Text("\(detectedCharacterCount) unique Chinese characters detected.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("From Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: onSave)
                        .disabled(detectedCharacterCount == 0)
                }
            }
        }
    }

    private static let placeholderText = "伊 朗 石 油 開 出 荷 姆 茲 仍 被 美 攔 截 川 普 暗 酸 習 近 平 戰 爭 就 另 隔 鍵 時 刻 美 元 霸 權 中 東 局 勢 關 鍵 時 刻 不 只 阿 聯 酋 要 求 美 元 互 換 貝 森 特 曝 中 東 亞 洲 多 國 求 加 入 美 元 保 護 傘 戰 爭 讓 美 元 金 穹 籠 罩 全 球 窮 國 因 戰 亂 離 不 開 穩 定 幣 美 元 霸 權 升 級 全 球"
}
