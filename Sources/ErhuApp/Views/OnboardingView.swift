import SwiftUI

struct OnboardingView: View {
    @Binding var isShowing: Bool

    var body: some View {
        TabView {
            OnboardingPage(
                image: "music.note.list",
                title: "欢迎来到二胡识谱",
                description: "一款帮助二胡学习者练习识谱和音准的教学工具。\n通过实时音高检测，判断演奏是否准确。"
            )

            OnboardingPage(
                image: "music.quarternote.3",
                title: "认识简谱",
                description: "简谱用数字 1-7 表示 do re mi fa sol la si。\n\n1=do  2=re  3=mi\n4=fa  5=sol  6=la  7=si\n\n数字旁边的点表示高八度或低八度。",
                example: "1 2 3 5 6 5 3 2 1"
            )

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "music.mic")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)

                Text("如何练习")
                    .font(.largeTitle.weight(.bold))

                VStack(alignment: .leading, spacing: 16) {
                    OnboardingStep(number: 1, text: "从曲库中选择一首曲子")
                    OnboardingStep(number: 2, text: "点击「开始演奏」，对着麦克风演奏二胡")
                    OnboardingStep(number: 3, text: "跟随曲谱，实时查看音准反馈")
                    OnboardingStep(number: 4, text: "练习结束，查看准确率总结")
                }
                .padding(.horizontal, 40)

                VStack(spacing: 12) {
                    // Feedback legend
                    VStack(alignment: .leading, spacing: 8) {
                        Text("反馈说明：")
                            .font(.headline)
                        HStack {
                            Circle().fill(.green).frame(width: 12, height: 12)
                            Text("正确").font(.caption)
                            Circle().fill(.orange).frame(width: 12, height: 12)
                            Text("音不准").font(.caption)
                            Circle().fill(.red).frame(width: 12, height: 12)
                            Text("错音").font(.caption)
                            Circle().fill(.gray).frame(width: 12, height: 12)
                            Text("等待输入").font(.caption)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)

                Spacer()

                Button {
                    isShowing = false
                } label: {
                    Text("开始使用")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

struct OnboardingPage: View {
    let image: String
    let title: String
    let description: String
    var example: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: image)
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.largeTitle.weight(.bold))

            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            if let example = example {
                Text(example)
                    .font(.system(size: 24, design: .monospaced))
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
    }
}

struct OnboardingStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.subheadline)
        }
    }
}
