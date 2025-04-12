// HistoryService.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine // Needed for ObservableObject AND Publishers

class HistoryService: ObservableObject {

    // Singleton pattern
    static let shared = HistoryService()

    private let db = Firestore.firestore()
    private var usersCollectionRef: CollectionReference {
        return db.collection("users")
    }

    private func historyCollectionRef(forUserID userID: String) -> CollectionReference {
        return usersCollectionRef.document(userID).collection("history")
    }

    // Published property for the history list view
    @Published var historyItems: [ScanHistoryItem] = []

    // To keep track of the Firestore listener
    private var listenerRegistration: ListenerRegistration?

    // Private initializer for Singleton
    private init() {}

    // MARK: - Public Methods

    /// Saves a new scan history item to Firestore under the user's document using Combine.
    /// - Parameters:
    ///   - userID: The ID of the user performing the scan. **Crucial that this is correct.**
    ///   - foodName: Optional name of the food identified.
    ///   - resultText: The full analysis result text.
    /// - Returns: A Combine publisher that emits Void on success or an Error on failure.
    func saveScanResult(userID: String, foodName: String?, resultText: String) -> AnyPublisher<Void, Error> {
        Deferred {
            Future<Void, Error> { promise in
                guard !userID.isEmpty else {
                    print("Error: Attempted to save history with empty userID in HistoryService.")
                    promise(.failure(NSError(domain: "HistoryService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid User ID provided"])))
                    return
                }

                guard Auth.auth().currentUser?.uid == userID else {
                    print("Error: Provided userID \(userID) does not match current authenticated user \(Auth.auth().currentUser?.uid ?? "nil").")
                    promise(.failure(NSError(domain: "HistoryService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID mismatch or not authenticated"])))
                    return
                }

                let newItem = ScanHistoryItem(
                    userID: userID, // Still store userID in the document
                    timestamp: Timestamp(date: Date()),
                    foodName: foodName,
                    resultText: resultText
                )

                do {
                    _ = try self.historyCollectionRef(forUserID: userID).addDocument(from: newItem) { error in
                        if let error = error {
                            print("Error saving history item to Firestore under user \(userID): \(error.localizedDescription)")
                            promise(.failure(error))
                        } else {
                            print("History item saved successfully under user \(userID) via Combine publisher.")
                            promise(.success(()))
                        }
                    }
                } catch {
                    print("Error encoding history item: \(error.localizedDescription)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }


    /// Starts listening for real-time updates to the scan history for the current user.
    /// Updates the `historyItems` published property.
    /// **CALL THIS FROM THE VIEW THAT DISPLAYS THE HISTORY LIST (e.g., ContentView)**
    func listenForHistoryUpdates() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("HistoryService: User not logged in. Cannot fetch history.")
            if !self.historyItems.isEmpty {
                DispatchQueue.main.async {
                    self.historyItems = []
                }
            }
            stopListening()
            return
        }

        print("HistoryService: Starting listener for user \(userID)...")
        stopListening()

        let query = historyCollectionRef(forUserID: userID)
            .order(by: "timestamp", descending: true)
            // .limit(to: 50) // Optional: Limit the number of items fetched

        listenerRegistration = query.addSnapshotListener { [weak self] (querySnapshot, error) in
            guard let self = self else { return }

            if let error = error {
                print("HistoryService: Error listening for history updates for user \(userID): \(error.localizedDescription)")
                return
            }

            guard let documents = querySnapshot?.documents else {
                print("HistoryService: No history documents found for user \(userID).")
                DispatchQueue.main.async {
                    self.historyItems = []
                }
                return
            }

            let newItems = documents.compactMap { document -> ScanHistoryItem? in
                do {
                    return try document.data(as: ScanHistoryItem.self)
                } catch {
                    print("HistoryService: Error decoding history document \(document.documentID) for user \(userID): \(error.localizedDescription)")
                    return nil
                }
            }

            DispatchQueue.main.async {
                self.historyItems = newItems
                print("HistoryService: History updated for user \(userID) with \(self.historyItems.count) items.")
            }
        }
    }

    /// Stops the Firestore listener. Call this when the view displaying history disappears
    /// or when the user logs out.
    func stopListening() {
        if listenerRegistration != nil {
            listenerRegistration?.remove()
            listenerRegistration = nil
            print("HistoryService: Stopped listening for history updates.")
        }
    }

    /// Deletes a specific history item for the current user.
    func deleteHistoryItem(itemId: String, completion: ((Error?) -> Void)? = nil) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion?(NSError(domain: "HistoryService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        historyCollectionRef(forUserID: userID).document(itemId).delete { error in
            if let error = error {
                print("Error deleting history item \(itemId) for user \(userID): \(error.localizedDescription)")
            } else {
                print("History item \(itemId) deleted successfully for user \(userID).")
                // Listener will automatically update the list if active
            }
            completion?(error)
        }
    }

    // Deinit to ensure listener is removed if the service instance is somehow destroyed
    deinit {
        stopListening()
    }
}
