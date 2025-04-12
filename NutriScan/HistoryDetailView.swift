// HistoryDetailView.swift
import SwiftUI
import FirebaseFirestore

struct HistoryDetailView: View {
    let historyItem: ScanHistoryItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(historyItem.foodName ?? "Unknown Food")
                    .font(.title2.weight(.bold))

                VStack(alignment: .leading) {
                    Text("Scan Time:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(formattedDate(from: historyItem.timestamp.dateValue()))
                        .font(.subheadline)
                }

                VStack(alignment: .leading) {
                    Text("Analysis Result:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(historyItem.resultText)
                        .font(.body)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading) // Make text wrap
                }
            }
            .padding()
            .navigationTitle("Scan Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryDetailView(historyItem: ScanHistoryItem(userID: "testUser", timestamp: FirebaseFirestore.Timestamp(date: Date()), foodName: "Apple", resultText: "This is a detailed analysis result for an apple. It contains vitamins, fiber, and natural sugars."))
}
