//
//  Contact.swift
//  RnCloudKit
//
//  Created by Stanimir Marinov on 7.03.22.
//  Copyright © 2022 Facebook. All rights reserved.
//

import Foundation
import CloudKit

struct Contact: Identifiable {
    let id: String
    let name: String
    let phoneNumber: String
    let associatedRecord: CKRecord
}

extension Contact {
    /// Initializes a `Contact` object from a CloudKit record.
    /// - Parameter record: CloudKit record to pull values from.
    init?(record: CKRecord) {
        guard let name = record["name"] as? String,
              let phoneNumber = record["phoneNumber"] as? String else {
            return nil
        }

        self.id = record.recordID.recordName
        self.name = name
        self.phoneNumber = phoneNumber
        self.associatedRecord = record
    }
}

