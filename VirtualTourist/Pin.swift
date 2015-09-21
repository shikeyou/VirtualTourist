//
//  Pin.swift
//  VirtualTourist
//
//  Created by Keng Siang Lee on 20/9/15.
//  Copyright (c) 2015 KSL. All rights reserved.
//

import MapKit
import CoreData

@objc(Pin)

class Pin : NSManagedObject {

    @NSManaged var latitude: Float
    @NSManaged var longitude: Float
    @NSManaged var photos: [Photo]
    
    //standard core data init method
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(latitude: Float, longitude: Float, context: NSManagedObjectContext) {
        
        //add entity to context
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        //set attributes
        self.latitude = latitude
        self.longitude = longitude
        
    }
    
}