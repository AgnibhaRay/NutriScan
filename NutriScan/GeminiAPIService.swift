import Foundation
import GoogleGenerativeAI
import UIKit
import SwiftUI

// MARK: - API Service Class
class GeminiAPIService: ObservableObject {
    
    // MARK: Properties
    private var model: GenerativeModel?

    // MARK: Initialization
    init() {
       
        let apiKey = "AIzaSyAioZCkx-IpUC4ZieJD60ot_PAm2ys_Toc"
        
        guard apiKey != "YOUR_API_KEY_HERE", !apiKey.isEmpty else {
            print("🔴 ERROR: API Key is missing or is still the placeholder value.")
            return
        }

        self.model = GenerativeModel(name: "gemini-1.5-flash", apiKey: apiKey)
        
        if self.model != nil {
            print("✅ GeminiAPIService initialized successfully.")
        } else {
             print("🔴 ERROR: Model initialization failed. Check API key and model name.")
         }
    }

    // MARK: - Public Methods
    func analyzeImage(image: UIImage, prompt: String) async throws -> String {
        guard let model = model else {
            print("🔴 ERROR: Gemini model not initialized.")
            throw APIError.modelNotInitialized
        }


        print("✅ Sending prompt and image to Gemini...")
        do {
            
            let response = try await model.generateContent(prompt, image)

            guard let text = response.text else {
                print("🔴 ERROR: Gemini response contained no text.")
                throw APIError.noTextResponse
            }
            
            print("✅ Received response from Gemini.")
            return text

        } catch {
            print("🔴 ERROR generating content via Gemini: \(error)")
            throw APIError.apiError(underlyingError: error)
        }
    }

}

// MARK: - Custom Error Enum
enum APIError: Error, LocalizedError {
    case modelNotInitialized
    case imageConversionFailed
    case noTextResponse
    case apiError(underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .modelNotInitialized:
            return "Couldn't initialize the AI model. Please check the API key setup."
        case .imageConversionFailed:
            return "Failed preparing the image for analysis."
        case .noTextResponse:
            return "The AI analysis completed, but returned no text description."
        case .apiError(let underlyingError):
            return "Gemini API Error: \(underlyingError.localizedDescription)"
        }
    }
}
