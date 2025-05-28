//
//  ActiveAlert.swift
//  SommLens
//
//  Created by Logan Rausch on 5/27/25.
//

import Foundation
// ActiveAlert.swift
enum ActiveAlert: Identifiable {
    case resetScans
    case iCloudEnabled
    case iCloudDisabled
    var id: Int { hashValue }
}
