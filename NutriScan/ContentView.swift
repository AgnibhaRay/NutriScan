//
//  ContentView.swift
//  NutriScan
//
//  Created by Agnibha Ray on 08/04/25.
//

import SwiftUI
import FirebaseAuth
import Foundation
import Combine

// MARK: - Main ContentView
struct ContentView: View {
    // MARK: - State Properties
    @StateObject private var frameHandler = FrameHandler() // Manages camera interaction
    @State private var showCameraView = false // Controls presentation of FrameView
    @State private var animatedGreeting: String = "" // State for the animated greeting text
    @State private var animationState: AnimationState = .welcome
    @State private var greeting: String = "" // To store the actual greeting
    @State private var sliderOffset: CGFloat = 0
    @State private var sliderWidth: CGFloat = 0
    @State private var circleScale: CGFloat = 1.0 // For pulsating animation

    // Access the shared AuthService instance from the environment
    @EnvironmentObject var authService: AuthService

    // Access the shared HistoryService instance
    @ObservedObject private var historyService = HistoryService.shared

    // State for controlling delete confirmation
    @State private var itemToDelete: String? = nil
    @State private var showingDeleteConfirmation = false
    @State private var showingClearAllConfirmation = false

    // MARK: - UI Constants
    let fabBackgroundColor = Color.blue
    let fabForegroundColor = Color.white
    let fabSize: CGFloat = 60
    let sliderHeight: CGFloat = 60

    // MARK: - Animation State Enum
    enum AnimationState {
        case welcome
        case greeting
        case finished
    }

    // MARK: - Body
    var body: some View {
        // Use NavigationView to enable navigation bar for Sign Out button
        NavigationView {
            ZStack(alignment: .bottom) { // Changed alignment to .bottom

                // Main Content Area Background
                Color(UIColor.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)

                // Main Content
                VStack(alignment: .leading, spacing: 0) {

                    // Greeting Text with Typewriter Animation
                    Text(animatedGreeting)
                        .font(.largeTitle.weight(.bold))
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 10)

                    // History Section with Clear All Button
                    HStack {
                        Text("Recent Scans")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Spacer()

                        if !historyService.historyItems.isEmpty {
                            Button {
                                showingClearAllConfirmation = true
                            } label: {
                                Text("Clear All")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)

                    // Scan History List
                    if historyService.historyItems.isEmpty {
                        List {
                            HStack {
                                Image(systemName: "list.bullet.rectangle.fill")
                                    .foregroundColor(.gray)
                                Text("Your scan history will appear here.")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .listStyle(.insetGrouped) // Changed list style
                    } else {
                        List {
                            ForEach(historyService.historyItems) { item in
                                NavigationLink(destination: HistoryDetailView(historyItem: item)) {
                                    HistoryItemView(item: item)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        itemToDelete = item.id
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped) // Changed list style
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.bottom, sliderHeight + 20) // Adjust padding for the slider

                // "Slide to Scan" Slider with Pulsating Animation
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background of the slider
                        RoundedRectangle(cornerRadius: sliderHeight / 2)
                            .fill(Color.gray.opacity(0.3))

                        // "Slide to Scan" Text
                        Text("Slide to Scan")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)

                        // Draggable Circle with Pulsating Animation
                        Circle()
                            .fill(fabBackgroundColor)
                            .frame(width: sliderHeight, height: sliderHeight)
                            .shadow(radius: 5, y: 3)
                            .offset(x: sliderOffset)
                            .scaleEffect(circleScale) // Added scale effect for pulsation
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        sliderOffset = max(0, min(value.translation.width, geometry.size.width - sliderHeight))
                                    }
                                    .onEnded { _ in
                                        if sliderOffset > geometry.size.width - sliderHeight - 40 { // Adjust threshold as needed
                                            triggerHapticFeedback()
                                            showCameraView = true
                                            sliderOffset = 0 // Reset the slider
                                        } else {
                                            withAnimation(.spring()) {
                                                sliderOffset = 0 // Return to start if not fully slid
                                            }
                                        }
                                    }
                            )
                    }
                    .frame(height: sliderHeight)
                    .onAppear {
                        sliderWidth = geometry.size.width
                        // Start the pulsating animation
                        withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            circleScale = 1.1
                        }
                    }
                }
                .padding(.horizontal)
                .frame(height: sliderHeight)
                .padding(.bottom, 20)

            } // End ZStack
            .navigationTitle("NutriScan") // Set a navigation title
            .navigationBarTitleDisplayMode(.inline) // Or .large
            .fullScreenCover(isPresented: $showCameraView) {
                // Present FrameView, passing environment object and userID for history
                FrameView(image: frameHandler.frame, isPresented: $showCameraView, frameHandler: frameHandler)
                    .environmentObject(authService)
            }
            // Add Toolbar for Sign Out Button
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        signOutUser()
                    }
                }
            }
            // Add confirmation dialogs
            .alert("Delete Scan", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let id = itemToDelete {
                        deleteHistoryItem(id: id)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this scan?")
            }
            .alert("Clear All History", isPresented: $showingClearAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAllHistory()
                }
            } message: {
                Text("Are you sure you want to clear all scan history? This cannot be undone.")
            }
            .onAppear {
                greeting = greetingText() // Get the actual greeting
                startGreetingAnimation()
                HistoryService.shared.listenForHistoryUpdates()
            }
            .onDisappear {
                HistoryService.shared.stopListening()
            }

        } // End NavigationView
        .background(Color.gray.opacity(0.1)) // Added background color
        .navigationViewStyle(.stack) // Use stack style for consistency
    }

    // MARK: - Helper Functions

    /// Determines the appropriate greeting based on the current time.
    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning!"
        case 12..<18: return "Good Afternoon!"
        case 18..<22: return "Good Evening!"
        default: return "Good Night!"
        }
    }

    private func startGreetingAnimation() {
        animatedGreeting = ""
        animationState = .welcome
        animateText("Welcome", index: 0, state: .welcome)
    }

    private func animateText(_ text: String, index: Int, state: AnimationState) {
        if index < text.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { // Reduced delay to 0.03 seconds
                animatedGreeting.append(text[text.index(text.startIndex, offsetBy: index)])
                animateText(text, index: index + 1, state: state)
            }
        } else {
            if state == .welcome {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Pause after "Welcome"
                    animatedGreeting = ""
                    animationState = .greeting
                    animateText(greeting, index: 0, state: .greeting)
                }
            } else if state == .greeting {
                animationState = .finished
            }
        }
    }

    /// Triggers haptic feedback.
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    /// Calls the AuthService to sign the user out within an asynchronous Task context.
    private func signOutUser() {
        print("Attempting sign out...")
        Task {
            do {
                try await authService.signOut()
                print("Sign out successful (or initiated).")
            } catch {
                print("🔴 Error signing out: \(error.localizedDescription)")
            }
        }
    }

    /// Deletes a single history item
    private func deleteHistoryItem(id: String) {
        HistoryService.shared.deleteHistoryItem(itemId: id) { error in
            if let error = error {
                print("Error deleting history item: \(error.localizedDescription)")
            } else {
                print("Successfully deleted history item")
            }
        }
    }

    /// Clears all history for the current user
    private func clearAllHistory() {
        // This implementation assumes you want to delete each item individually.
        // For a large number of items, a more efficient approach in HistoryService
        // might be needed (e.g., deleting all documents for the user with a specific query).
        for item in historyService.historyItems {
            HistoryService.shared.deleteHistoryItem(itemId: item.id!)
        }
    }
}

// MARK: - History Item View Component
struct HistoryItemView: View {
    let item: ScanHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Food Name or Placeholder
            Text(item.foodName ?? "Unknown Food")
                .font(.headline)
                .lineLimit(1)

            // Date and Time
            Text(formattedDate(from: item.timestamp.dateValue()))
                .font(.caption)
                .foregroundColor(.secondary)

            // Preview of scan result
            Text(truncateText(item.resultText, maxLength: 100))
                .font(.body)
                .lineLimit(2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }

    // Format timestamp to readable format
    private func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // Truncate long results for preview
    private func truncateText(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }

        let index = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<index]) + "..."
    }
}

// MARK: - Preview
#Preview {
    // Preview needs AuthService in environment
    ContentView()
        .environmentObject(AuthService()) // Provide a dummy AuthService for preview
}

// MARK: - Extension for Future-Task Conversion
// Add an extension to make Future's work with async/await
extension Future where Failure: Error {
    var value: Output {
        get async throws {
            try await withCheckedThrowingContinuation { continuation in
                var cancellable: AnyCancellable?

                cancellable = self.sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
            }
        }
    }
}
