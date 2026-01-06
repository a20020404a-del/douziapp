//
//  RecordButton.swift
//  douziapp
//
//  録音開始/停止ボタン
//

import SwiftUI

struct RecordButton: View {
    @Binding var isRecording: Bool
    let action: () -> Void

    @State private var animationAmount: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            ZStack {
                // 外側のリング（録音中はパルスアニメーション）
                Circle()
                    .stroke(isRecording ? Color.red.opacity(0.3) : Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 88, height: 88)
                    .scaleEffect(isRecording ? animationAmount : 1.0)
                    .opacity(isRecording ? 2 - animationAmount : 1)

                // メインサークル
                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 72, height: 72)
                    .shadow(color: (isRecording ? Color.red : Color.blue).opacity(0.4), radius: 8, y: 4)

                // アイコン
                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    animationAmount = 1.5
                }
            } else {
                animationAmount = 1.0
            }
        }
        .accessibilityLabel(isRecording ? "録音を停止" : "録音を開始")
    }
}

#Preview {
    VStack(spacing: 40) {
        RecordButton(isRecording: .constant(false)) {}
        RecordButton(isRecording: .constant(true)) {}
    }
    .padding()
}
