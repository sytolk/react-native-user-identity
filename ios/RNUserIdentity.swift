/**
 * Copyright (c) Julian Ramírez.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import CloudKit
import Foundation
import OSLog


@objc(RNUserIdentity)
class RNUserIdentity: NSObject
{

  // MARK: - Services

  /* @objc
  public func getUserIdentity(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock)
  {
    CKContainer.default().fetchUserRecordID()
    {
      recordID, error in

      if let result = recordID?.recordName {
        resolve(result)
      } else {
        if let ckerror = error as? CKError, ckerror.code == CKError.notAuthenticated {
          reject("NO_ACCOUNT_ACCESS_ERROR", "No iCloud account is associated with the device, or access to the account is restricted", nil);
          return;
        }

        if let error = error as? NSError {
          reject("CloudKitError", error.localizedDescription, error);
          return;
        }

        reject("CloudKitError", "Error retrieving record id", nil)
      }
    }
  } */

  @objc
  static func requiresMainQueueSetup() -> Bool
  {
    return true
  }

    //////////
    enum Config {
        /// iCloud container identifier.
        /// Update this if you wish to use your own iCloud container.
        static let containerIdentifier = "iCloud.com.microbit24.cloudkit.sharing" //"iCloud.com.apple.samples.cloudkit.sharing"
    }

    /// Use the specified iCloud container ID, which should also be present in the entitlements file.
    lazy var container = CKContainer.default(); // CKContainer(identifier: Config.containerIdentifier)
    /// This project uses the user's private database.
    private lazy var database = container.privateCloudDatabase
    /// Sharing requires using a custom record zone.
    let recordZone = CKRecordZone(zoneName: "Contacts")

    @objc
    public func getUserIdentity(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        // resolve(a*b)

        fetchContacts(scope: .private, in: [recordZone]) { result in
            switch result {
            case .success(let contacts):
                resolve(contacts)
            case .failure(let error):
                reject("setup_cloudkit_failed", "Failed to setup CloudKit", error)
            }

            // group.leave()
        }

    }

    // MARK: - Private

    /// Asynchronously fetches contacts for a given set of zones in a given database scope.
    /// - Parameters:
    ///   - scope: Database scope to fetch from.
    ///   - zones: Record zones to fetch contacts from.
    ///   - completionHandler: Handler to process success or failure of operation.
    private func fetchContacts(
            scope: CKDatabase.Scope,
            in zones: [CKRecordZone],
            completionHandler: @escaping (Result<[Contact], Error>) -> Void
    ) {
        let database = container.database(with: scope)
        let zoneIDs = zones.map {
            $0.zoneID
        }

        //let changeToken = userDefaults.previousZoneChangeToken

        let operation: CKFetchRecordZoneChangesOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs,
                configurationsByRecordZoneID: [:])
        /*if #available(iOS 12.0, *) {
            var configurations =
                    [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration]()
            zoneIDs.forEach { recordZoneID in
                let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
                config.previousServerChangeToken = tokenCache[recordZoneID]
                configurations[recordZoneID] = config
            }

            operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs,
                    configurationsByRecordZoneID: configurations) // [:])
        } else {
            let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
            options.previousServerChangeToken = changeToken
            let configurations = [zoneID: options]
            operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID],
                    optionsByRecordZoneID: configurations)
        }*/


        var contacts: [Contact] = []

        operation.recordChangedBlock = { record in
            if record.recordType == "Contact", let contact = Contact(record: record) {
                contacts.append(contact)
            }
        }

        operation.fetchRecordZoneChangesCompletionBlock = { error in
            if let error = error {
                completionHandler(.failure(error))
            } else {
                completionHandler(.success(contacts))
            }
        }

        database.add(operation)
    }

    /// Fetches all shared Contacts from all available record zones.
    /// - Parameter completionHandler: Handler to process success or failure.
    func fetchSharedContacts(completionHandler: @escaping (Result<[Contact], Error>) -> Void) {
        // The first step is to fetch all available record zones in user's shared database.
        container.sharedCloudDatabase.fetchAllRecordZones { zones, error in
            if let error = error {
                completionHandler(.failure(error))
            } else if let zones = zones, !zones.isEmpty {
                // Fetch all Contacts in the set of zones in the shared database.
                self.fetchContacts(scope: .shared, in: zones, completionHandler: completionHandler)
            } else {
                // Zones nil or empty so no shared contacts.
                completionHandler(.success([]))
            }
        }
    }

    /// Creates the custom zone in use if needed.
    /// - Parameter completionHandler: An optional completion handler to track operation completion or errors.
    func createZoneIfNeeded(completionHandler: ((Result<Void, Error>) -> Void)? = nil) {
        // Avoid the operation if this has already been done.
        guard !UserDefaults.standard.bool(forKey: "isZoneCreated") else {
            completionHandler?(.success(()))
            return
        }

        let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [recordZone])
        createZoneOperation.modifyRecordZonesCompletionBlock = { _, _, error in
            if let error = error {
                debugPrint("Error: Failed to create custom zone: \(error)")
                completionHandler?(.failure(error))
            } else {
                DispatchQueue.main.async {
                    UserDefaults.standard.setValue(true, forKey: "isZoneCreated")
                    completionHandler?(.success(()))
                }
            }
        }

        database.add(createZoneOperation)
    }
}

