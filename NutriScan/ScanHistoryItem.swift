import Foundation
import FirebaseFirestore // Import Firestore

struct ScanHistoryItem: Identifiable, Codable, Hashable {
    @DocumentID var id: String? // Firestore document ID, maps automatically
    let userID: String          // ID of the user who made the scan
    let timestamp: Timestamp    // Firebase Timestamp for ordering/display
    let foodName: String?       // Name identified by Gemini (optional)
    let resultText: String      // The full analysis result text from Gemini
    // Add other fields if needed, e.g., imageURL if storing images

    // Conform to Hashable if needed for ForEach without explicit id
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Conform to Equatable if needed for Hashable
    static func == (lhs: ScanHistoryItem, rhs: ScanHistoryItem) -> Bool {
        lhs.id == rhs.id
    }
    
    // Formatted date string for display
    var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: timestamp.dateValue()) // Convert Timestamp to Date
    }
}
