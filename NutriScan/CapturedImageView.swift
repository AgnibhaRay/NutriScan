import SwiftUI
import Combine
import FirebaseAuth

struct CapturedImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var geminiService = GeminiAPIService()
    @StateObject private var historyService = HistoryService.shared
    let userID: String
    @State private var analysisResult: String? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var foodName: String? = nil
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var showSaveSuccess: Bool = false // New state to track save success
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button { presentationMode.wrappedValue.dismiss() } label: { HStack { Image(systemName: "chevron.left"); Text("Retake") }.padding() }
                    Spacer()
                }
                .padding(.horizontal)

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal)
                    .padding(.bottom, 5)

                VStack {
                    if isLoading {
                        ProgressView("Analyzing...")
                            .padding()
                    } else if let result = analysisResult {
                        HStack(alignment: .top, spacing: 8) {
                            ScrollView {
                                Text(result)
                                    .font(.body)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .frame(maxHeight: 250)

                        if showSaveSuccess {
                            Button {
                                isPresented = false // Go back to the home page
                            } label: {
                                Text("Done")
                                    .fontWeight(.bold)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 8)
                            }
                        } else {
                            Button {
                                saveToHistory()
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Save to History")
                                        .fontWeight(.semibold)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(isSaving ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 8)
                            }
                            .disabled(isSaving)
                        }

                        if let saveError = saveError {
                            Text(saveError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.bottom, 8)
                        }
                    } else if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                    }

                    if analysisResult == nil && !isLoading {
                        Button {
                            performAnalysis()
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet.rectangle")
                                Text("Analyse")
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isLoading ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal, 40)
                            .padding(.vertical)
                        }
                        .disabled(isLoading)
                    }
                }
                Spacer()
            }
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
        }
    }

    private func clearAnalysis() {
        analysisResult = nil
        errorMessage = nil
        isLoading = false
        foodName = nil
        saveError = nil
        isSaving = false
        showSaveSuccess = false
    }

    private func performAnalysis() {
        isLoading = true
        analysisResult = nil
        errorMessage = nil
        saveError = nil
        foodName = nil

        let prompt = """
        Identify the primary food item in this image. Only List its common ingredients and also their macro values and also estimate freshness of the item and no other garbage texts to divert the attention.
        - If it's a single raw ingredient (like an apple or flour), just state the item name and also give their macro values per 100g and also estimate the freshness of the item.
        - If it's a prepared dish (like a salad or curry), list typical key ingredients and also give the potential macro values per 100g also help user in estimating the freshness of the dish.
        - If it's packaged food, try to infer common ingredients if possible, otherwise state you cannot determine ingredients from packaging and also give their macro values per 100g and estimate the freshness of the item.
        - If the image does not contain a recognizable food item, please state that clearly.

        Present the ingredients as a list if applicable. Extract the primary food name and place it on the very first line by itself, followed by the ingredients/macros list/Freshness Estimation.

        If you get any other sort of image expect food items, you can be a bit playful, naughty, flirty and crack jokes on the image provided to you, but jon't joke in pictures with food, only provide data when the picture is a food
        """

        Task {
            do {
                let result = try await geminiService.analyzeImage(image: image, prompt: prompt)
                await MainActor.run {
                    analysisResult = result
                    foodName = extractFoodName(from: result)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func extractFoodName(from result: String) -> String? {
        guard let firstLine = result.components(separatedBy: "\n").first else {
            return nil
        }
        let name = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name.count > 50 || name.hasPrefix("-") || name.hasPrefix("•") || name.lowercased().contains("cannot identify") || name.lowercased().contains("not food") {
            return nil
        }
        return name
    }

    private func saveToHistory() {
        guard let result = analysisResult else {
            saveError = "No analysis result to save."
            return
        }
        guard !userID.isEmpty, userID != "preview-user-id" else {
            saveError = "Cannot save history: Invalid User ID."
            return
        }

        isSaving = true
        saveError = nil

        historyService.saveScanResult(userID: userID, foodName: foodName, resultText: result)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isSaving = false
                if case .failure(let error) = completion {
                    self.saveError = "Failed to save: \(error.localizedDescription)"
                } else {
                    withAnimation {
                        self.showSaveSuccess = true // Set the state to show the "Done" button
                    }
                }
            }, receiveValue: {})
            .store(in: &cancellables)
    }
}
