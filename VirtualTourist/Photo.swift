//
//  Photo.swift
//  VirtualTourist
//
//  Created by Keng Siang Lee on 19/9/15.
//  Copyright (c) 2015 KSL. All rights reserved.
//

import UIKit

struct Photo {
    var imageFileUrl: NSURL?
    
    init(imageFileUrl: NSURL?) {
        self.imageFileUrl = imageFileUrl
    }
}