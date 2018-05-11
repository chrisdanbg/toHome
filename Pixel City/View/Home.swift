//
//  Home.swift
//  Pixel City
//
//  Created by Kristyan Danailov on 10.05.18 г..
//  Copyright © 2018 г. Kristyan Danailov. All rights reserved.
//

import Foundation
import UIKit
import MapKit

class Home: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var identifier: String
    
    init(coordinate: CLLocationCoordinate2D, identifier: String) {
        self.coordinate = coordinate
        self.identifier = identifier
        super.init()
    }
}
