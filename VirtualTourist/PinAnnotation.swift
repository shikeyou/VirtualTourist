//
//  PinAnnotation.swift
//  VirtualTourist
//
//  Created by Keng Siang Lee on 20/9/15.
//  Copyright (c) 2015 KSL. All rights reserved.
//

import Foundation
import MapKit

//This class is for storing a Pin in an annotation
class PinAnnotation: NSObject, MKAnnotation {
    
    var title: String
    var subtitle: String
    var coordinate: CLLocationCoordinate2D
    var pin: Pin
    
    //main initializer
    init(title: String, subtitle: String, coordinate: CLLocationCoordinate2D, pin: Pin) {
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.pin = pin
    }
    
    //convenience initializer
    convenience init(coordinate: CLLocationCoordinate2D, pin: Pin) {
        self.init(
            title: "",
            subtitle: "",
            coordinate: coordinate,
            pin: pin
        )
    }
    
}