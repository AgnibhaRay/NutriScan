import SwiftUI
import AVFoundation
import UIKit
import Combine
import Foundation

struct FrameView: View {
    var image: CGImage?
    @Environment(\.presentationMode) var presentationMode
    @Binding var isPresented: Bool
    @ObservedObject var frameHandler: FrameHandler
    @EnvironmentObject var authService: AuthService

    @State private var navigateToCapturedImage = false

    let frameColor = Color.white.opacity(0.7)
    let cornerLength: CGFloat = 30
    let cornerThickness: CGFloat = 2
    let buttonSizeLarge: CGFloat = 60
    let textPaddingBelowFrame: CGFloat = 20 // Adjust as needed

    init(image: CGImage? = nil, isPresented: Binding<Bool> = .constant(true), frameHandler: FrameHandler = FrameHandler()) {
        self.image = image
        self._isPresented = isPresented
        self.frameHandler = frameHandler
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GeometryReader { geometry in
                    Group {
                        if let image = image {
                            Image(image, scale: 1.0, label: Text("Camera Feed"))
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        } else {
                            ZStack {
                                Color.black
                                Text("Camera unavailable").foregroundColor(.white)
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .edgesIgnoringSafeArea(.all)

                GeometryReader { geometry in
                    let focusAreaSize = min(geometry.size.width, geometry.size.height) * 0.6 // Adjust as needed
                    let centerX = geometry.size.width / 2
                    let centerY = geometry.size.height / 2
                    let cornerOffset = cornerThickness / 2
                    let textYPosition = centerY + focusAreaSize / 2 + textPaddingBelowFrame

                    // Top Left Corner
                    Path { path in
                        path.move(to: CGPoint(x: centerX - focusAreaSize / 2 + cornerOffset, y: centerY - focusAreaSize / 2))
                        path.addLine(to: CGPoint(x: centerX - focusAreaSize / 2 + cornerLength, y: centerY - focusAreaSize / 2))
                        path.move(to: CGPoint(x: centerX - focusAreaSize / 2, y: centerY - focusAreaSize / 2 + cornerOffset))
                        path.addLine(to: CGPoint(x: centerX - focusAreaSize / 2, y: centerY - focusAreaSize / 2 + cornerLength))
                    }
                    .stroke(style: StrokeStyle(lineWidth: cornerThickness, lineCap: .round, lineJoin: .round))
                    .foregroundColor(frameColor)

                    // Top Right Corner
                    Path { path in
                        path.move(to: CGPoint(x: centerX + focusAreaSize / 2 - cornerLength, y: centerY - focusAreaSize / 2))
                        path.addLine(to: CGPoint(x: centerX + focusAreaSize / 2 - cornerOffset, y: centerY - focusAreaSize / 2))
                        path.move(to: CGPoint(x: centerX + focusAreaSize / 2, y: centerY - focusAreaSize / 2 + cornerOffset))
                        path.addLine(to: CGPoint(x: centerX + focusAreaSize / 2, y: centerY - focusAreaSize / 2 + cornerLength))
                    }
                    .stroke(style: StrokeStyle(lineWidth: cornerThickness, lineCap: .round, lineJoin: .round))
                    .foregroundColor(frameColor)

                    // Bottom Left Corner
                    Path { path in
                        path.move(to: CGPoint(x: centerX - focusAreaSize / 2 + cornerOffset, y: centerY + focusAreaSize / 2))
                        path.addLine(to: CGPoint(x: centerX - focusAreaSize / 2 + cornerLength, y: centerY + focusAreaSize / 2))
                        path.move(to: CGPoint(x: centerX - focusAreaSize / 2, y: centerY + focusAreaSize / 2 - cornerLength))
                        path.addLine(to: CGPoint(x: centerX - focusAreaSize / 2, y: centerY + focusAreaSize / 2 - cornerOffset))
                    }
                    .stroke(style: StrokeStyle(lineWidth: cornerThickness, lineCap: .round, lineJoin: .round))
                    .foregroundColor(frameColor)

                    // Bottom Right Corner
                    Path { path in
                        path.move(to: CGPoint(x: centerX + focusAreaSize / 2 - cornerLength, y: centerY + focusAreaSize / 2))
                        path.addLine(to: CGPoint(x: centerX + focusAreaSize / 2 - cornerOffset, y: centerY + focusAreaSize / 2))
                        path.move(to: CGPoint(x: centerX + focusAreaSize / 2, y: centerY + focusAreaSize / 2 - cornerLength))
                        path.addLine(to: CGPoint(x: centerX + focusAreaSize / 2, y: centerY + focusAreaSize / 2 - cornerOffset))
                    }
                    .stroke(style: StrokeStyle(lineWidth: cornerThickness, lineCap: .round, lineJoin: .round))
                    .foregroundColor(frameColor)

                    Text("Center the food")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(frameColor)
                        .position(x: centerX, y: textYPosition) // Position the text directly
                }
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)

                VStack {
                    HStack {
                        Button {
                            isPresented = false
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Image(systemName: "house.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.3), in: Circle())
                        }
                        .padding(.leading, 15)
                        .padding(.top, 15)

                        Spacer()
                    }
                    Spacer()
                }

                VStack {
                    Spacer()
                    Button {
                        captureImageAction()
                    } label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: buttonSizeLarge, height: buttonSizeLarge)
                            .shadow(radius: 3)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .disabled(frameHandler.frame == nil)
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationDestination(isPresented: $navigateToCapturedImage) {
                if let capturedUIImage = frameHandler.capturedImage, let userID = authService.currentUser?.uid {
                    CapturedImageView(image: capturedUIImage, isPresented: $isPresented, userID: userID)
                } else if let currentFrame = frameHandler.frame, let userID = authService.currentUser?.uid {
                    CapturedImageView(image: UIImage(cgImage: currentFrame), isPresented: $isPresented, userID: userID)
                }
            }
            .navigationBarHidden(true)
            .statusBarHidden(true)
            .onAppear(perform: runInitialSetup)
            .onDisappear(perform: cleanupOnDisappear)
        }
    }

    private func runInitialSetup() {
        print("FrameView appeared. Starting session.")
        frameHandler.startSession()
        navigateToCapturedImage = false
    }

    private func cleanupOnDisappear() {
        print("FrameView disappeared. Stopping session.")
        frameHandler.stopSession()
    }

    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    private func captureImageAction() {
        print("Capture button tapped.")
        triggerHapticFeedback()
        frameHandler.captureCurrentFrame()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if frameHandler.capturedImage != nil || frameHandler.frame != nil {
                print("Navigating to CapturedImageView.")
                navigateToCapturedImage = true
            } else {
                print("Error: Capture action failed or no frame available.")
            }
        }
    }
}

#Preview {
    FrameView()
        .environmentObject(AuthService())
}
