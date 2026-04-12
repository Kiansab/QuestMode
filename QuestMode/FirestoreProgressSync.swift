import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Stores one JSON document per user: `{ "json": "<UserProgressSnapshot JSON>", "updatedAt": Timestamp }`.
enum FirestoreProgressSync {

    private static let collection = "users"

    private static func docRef() -> DocumentReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return Firestore.firestore().collection(collection).document(uid)
    }

    static func deleteRemoteProgress(completion: @escaping (Error?) -> Void) {
        guard let ref = docRef() else {
            completion(nil)
            return
        }
        ref.delete(completion: completion)
    }

    static func push(_ snapshot: UserProgressSnapshot, completion: ((Error?) -> Void)? = nil) {
        guard let ref = docRef() else {
            completion?(nil)
            return
        }
        do {
            let data = try JSONEncoder().encode(snapshot)
            guard let json = String(data: data, encoding: .utf8) else {
                completion?(NSError(domain: "QuestMode", code: 1))
                return
            }
            ref.setData([
                "json": json,
                "updatedAt": FieldValue.serverTimestamp()
            ]) { err in
                completion?(err)
            }
        } catch {
            completion?(error)
        }
    }

    static func pull(completion: @escaping (Result<UserProgressSnapshot?, Error>) -> Void) {
        guard let ref = docRef() else {
            completion(.success(nil))
            return
        }
        ref.getDocument { snap, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let snap = snap, snap.exists,
                  let json = snap.data()?["json"] as? String,
                  let data = json.data(using: .utf8) else {
                completion(.success(nil))
                return
            }
            DispatchQueue.main.async {
                do {
                    let decoded = try JSONDecoder().decode(UserProgressSnapshot.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
}
