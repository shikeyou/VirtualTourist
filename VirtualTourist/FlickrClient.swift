//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by Keng Siang Lee on 20/9/15.
//  Copyright (c) 2015 KSL. All rights reserved.
//

import Foundation
import MapKit
import CoreData

class FlickrClient: NSObject {
    
    //============================================
    // MARK: CONSTANTS
    //============================================
    
    //constants for flickr photos search
    let BASE_URL = "https://api.flickr.com/services/rest/"
    static let FLICKR_API_KEY = "ce190e05b11ca689a9c1fac8c9de619d"
    let STANDARD_PHOTOS_SEARCH_ARGS = [
        "method": "flickr.photos.search",
        "api_key": FLICKR_API_KEY,
        "safe_search": "1",
        "extras": "url_m",
        "format": "json",
        "nojsoncallback": "1"
    ]
    
    //constants for lat long
    let BOUNDING_BOX_HALF_WIDTH = 1.0
    let BOUNDING_BOX_HALF_HEIGHT = 1.0
    let LAT_MIN = -90.0
    let LAT_MAX = 90.0
    let LON_MIN = -180.0
    let LON_MAX = 180.0
    
    //============================================
    // MARK: INSTANCE VARIABLES
    //============================================
    
    //variables for storing parsed data
    var photos = [Photo]()
    
    //============================================
    // MARK: CLASS FUNCTIONS
    //============================================
    
    //singleton class function
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }

    //============================================
    // MARK: PRIVATE METHODS
    //============================================

    //creates a flickr bbox string from lat long coordinates, adapted from code by Jarrod Parkes
    private func createBboxStringFromCoordinate(coordinate: CLLocationCoordinate2D) -> String {
        
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        
        /* Fix added to ensure box is bounded by minimum and maximums */
        let bottom_left_lon = max(longitude - BOUNDING_BOX_HALF_WIDTH, LON_MIN)
        let bottom_left_lat = max(latitude - BOUNDING_BOX_HALF_HEIGHT, LAT_MIN)
        let top_right_lon = min(longitude + BOUNDING_BOX_HALF_HEIGHT, LON_MAX)
        let top_right_lat = min(latitude + BOUNDING_BOX_HALF_HEIGHT, LAT_MAX)
        
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }

    //gets total pages for a flickr request
    private func getTotalPages(args: [String: String], resultHandler: (totalPages: Int)->Void, completionHandler: (completedIndex: Int, errorMsg: String)->Void) {
        
        //make http GET request to flickr's api
        HttpHelper.makeHttpRequest(
            requestUrl: "\(BASE_URL)\(HttpHelper.escapedParameters(args))",
            requestMethod: "GET",
            requestDataHandler: { data, response, error in
                
                //check for request error
                if error != nil {
                    completionHandler(completedIndex: -1, errorMsg: error.localizedDescription)
                    return
                }
                
                //parse json data
                let (jsonData, jsonParseError) = HttpHelper.parseJsonData(data)
                if jsonParseError != nil {
                    completionHandler(completedIndex: -1, errorMsg: jsonParseError!.localizedDescription)
                    return
                }
                
                //extract json data into Photo array
                if let jsonDataPhotos = jsonData["photos"] as? [String:AnyObject] {
                    
                    if let jsonDataPhotosPages = jsonDataPhotos["pages"] as? Int {
                        
                        //call the result handler with total number of pages
                        resultHandler(totalPages: jsonDataPhotosPages)
                        
                    } else {
                        
                        //return false to callback to indicate failure
                        completionHandler(completedIndex: -1, errorMsg: "Unable to get photo details from server: pages")
                        
                    }
                    
                } else {
                    
                    //return false to callback to indicate failure
                    completionHandler(completedIndex: -1, errorMsg: "Unable to get photo details from server: photos")
                }
            }
        )
    }
    
    private func fetchPhotosForPage(page: Int, args: [String:String], count: Int, totalHandler: (total: Int)->Void, completionHandler: (completedIndex: Int, errorMsg: String)->Void) {
        
        //add page to args
        var argsWithPage = args
        argsWithPage["page"] = "\(page)"
        
        //make http GET request to flickr's api
        HttpHelper.makeHttpRequest(
            requestUrl: "\(BASE_URL)\(HttpHelper.escapedParameters(argsWithPage))",
            requestMethod: "GET",
            requestDataHandler: { data, response, error in
                
                //check for request error
                if error != nil {
                    completionHandler(completedIndex: -1, errorMsg: error.localizedDescription)
                    return
                }
                
                //parse json data
                let (jsonData, jsonParseError) = HttpHelper.parseJsonData(data)
                if jsonParseError != nil {
                    completionHandler(completedIndex: -1, errorMsg: jsonParseError!.localizedDescription)
                    return
                }
                
                //extract json data into Photo array
                if let jsonDataPhotos = jsonData["photos"] as? [String:AnyObject] {
                    
                    var totalPhotosVal = 0
                    if let jsonDataPhotosTotal = jsonDataPhotos["total"] as? String {
                        totalPhotosVal = (jsonDataPhotosTotal as NSString).integerValue
                    }
                    
                    if totalPhotosVal > 0 {
                        
                        if let jsonDataPhotosPhoto = jsonDataPhotos["photo"] as? [[String: AnyObject]] {
                            
                            //clear the photos array first
                            self.photos.removeAll()
                            
                            //call handler with total number of photos expected
                            totalHandler(total: jsonDataPhotosPhoto.count)
                            
                            //populate photos array with Photo that uses parsed data
                            var hasError = false
                            var index = 0
                            for p in jsonDataPhotosPhoto {

                                //get the image url
                                if let imageHttpUrlString = p["url_m"] as? String {
                                    
                                    let imageURL = NSURL(string: imageHttpUrlString)
                                    
                                    //get data from url
                                    if let imageData = NSData(contentsOfURL: imageURL!) {
                                        
                                        //save the file to disk
                                        let imageLocalFilePath = FileHelper.saveImageAsJpeg(UIImage(data: imageData)!, filename: imageHttpUrlString.lastPathComponent)
                                        
                                        //get the file name, we only want to store this (because document directory changes)
                                        let imageLocalFileName = imageLocalFilePath.lastPathComponent
                                        
                                        //create an actual Photo object
                                        let photo = Photo(imageFileName: imageLocalFileName, context: CoreDataHelper.scratchContext)
                                        self.photos.append(photo)
                                        
                                        //call handler
                                        completionHandler(completedIndex: index, errorMsg: "")
                                        
                                    } else {
                                        
                                        hasError = true
                                        
                                    }
                                    
                                } else {
                                    
                                    hasError = true
                                    
                                }
                                
                                if (hasError) {
                                    
                                    //we still have to create a Photo object with an empty file name
                                    //the UI will show an empty image to handle the error
                                    let photo = Photo(imageFileName: "", context: CoreDataHelper.scratchContext)
                                    self.photos.append(photo)
                                    
                                    //call handler
                                    completionHandler(completedIndex: index, errorMsg: "")
                                    
                                }
                                
                                index += 1
                                
                            }
                            
                        } else {
                            
                            //return false to callback to indicate failure
                            completionHandler(completedIndex: -1, errorMsg: "Unable to get photo details from server: photo")
                        }
                        
                    } else {

                        //return false to callback to indicate failure
                        totalHandler(total: 0)
                        completionHandler(completedIndex: -1, errorMsg: "No photos found at this location")
                    }
                    
                } else {
                    
                    //return false to callback to indicate failure
                    completionHandler(completedIndex: -1, errorMsg: "Unable to get photo details from server: photos")
                }
            }
        )
    }
    
    private func fetchPhotos(args: [String:String], count: Int, totalHandler: (total: Int)->Void, completionHandler: (completedIndex: Int, errorMsg: String)->Void) {
        
        //do a http request first to find the total number of pages
        getTotalPages(args, resultHandler: { totalPages in
            
            //then do the actual http request to fetch all photos for a random page within this upper limit
            let pageLimit = min(totalPages, 40)
            let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
            self.fetchPhotosForPage(randomPage, args: args, count: count, totalHandler: totalHandler, completionHandler: completionHandler)
            
        }, completionHandler: completionHandler)
    }
    
    //============================================
    // MARK: PUBLIC METHODS
    //============================================
    
    func fetchPhotosUsingText(text: String, count: Int, totalHandler: (total: Int)->Void, completionHandler: (completedIndex: Int, errorMsg: String)->Void) {
        
        //set max of 500 photos per page
        let perPage = min(count, 500)
        
        //gather method arguments
        var args = STANDARD_PHOTOS_SEARCH_ARGS  //this does a deep copy which is what I need
        args["text"] = text
        args["per_page"] = "\(perPage)"
        
        //fetch photos
        fetchPhotos(args, count: count, totalHandler: totalHandler, completionHandler: completionHandler)
    }
    
    func fetchPhotosUsingCoordinate(coordinate: CLLocationCoordinate2D, count: Int, totalHandler: (total: Int)->Void, completionHandler: (completedIndex: Int, errorMsg: String)->Void) {
        
        //convert coordinates to a string that flickr expects
        let bboxString = createBboxStringFromCoordinate(coordinate)
        
        //set max of 500 photos per page
        let perPage = min(count, 500)
        
        //gather method arguments
        var args = STANDARD_PHOTOS_SEARCH_ARGS  //this does a deep copy which is what I need
        args["bbox"] = bboxString
        args["per_page"] = "\(perPage)"
        
        //fetch photos
        fetchPhotos(args, count: count, totalHandler: totalHandler, completionHandler: completionHandler)
        
    }
    
}