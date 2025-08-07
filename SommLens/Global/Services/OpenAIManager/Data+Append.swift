//
//  Data+Append.swift
//  SommLens
//
//  Created by Logan Rausch on 7/15/25.
//

import Foundation

extension Data {
  mutating func appendString(_ string: String) {
    if let d = string.data(using: .utf8) {
      append(d)
    }
  }
}
