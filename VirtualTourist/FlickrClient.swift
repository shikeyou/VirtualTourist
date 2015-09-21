//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by Keng Siang Lee on 20/9/15.
//  Copyright (c) 2015 KSL. All rights reserved.
//

import Foundation
import MapKit

class FlickrClient: NSObject {
    
    //constants
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
    
    let BOUNDING_BOX_HALF_WIDTH = 1.0
    let BOUNDING_BOX_HALF_HEIGHT = 1.0
    let LAT_MIN = -90.0
    let LAT_MAX = 90.0
    let LON_MIN = -180.0
    let LON_MAX = 180.0
    
    let PER_PAGE_COUNT_MULT = 1
    
    //store parsed data as arrays of structs/objects
    var photos = [Photo]()
    
    //singleton class function
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
    
    //TODO: optimize this
    func getRandomSubsetFromArray(arr: [AnyObject], count: Int) -> [AnyObject]{
        var arr2 = arr
        for i in 0..<(count - 1) {
            let j = Int(arc4random_uniform(UInt32(count - i))) + i
            (arr2[i], arr2[j]) = (arr2[j], arr2[i])
        }
        return Array(arr2[0..<count])
    }
    
    //adapted from code written by Jarrod Parkes
    func createBboxStringFromCoordinate(coordinate: CLLocationCoordinate2D) -> String {
        
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        
        /* Fix added to ensure box is bounded by minimum and maximums */
        let bottom_left_lon = max(longitude - BOUNDING_BOX_HALF_WIDTH, LON_MIN)
        let bottom_left_lat = max(latitude - BOUNDING_BOX_HALF_HEIGHT, LAT_MIN)
        let top_right_lon = min(longitude + BOUNDING_BOX_HALF_HEIGHT, LON_MAX)
        let top_right_lat = min(latitude + BOUNDING_BOX_HALF_HEIGHT, LAT_MAX)
        
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }

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
    
    private func fetchPhotosForPage(page: Int, args: [String:String], count: Int, completionHandler: (completedIndex: Int, errorMsg: String)->Void) {
        
        //add page to args
        var argsWithPage = args
        argsWithPage["page"] = "\(page)"
        
        println("page: \(page)")
        println("updated flickr request: \(BASE_URL)\(HttpHelper.escapedParameters(argsWithPage))")
        
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
                            
                            //filter number of results
                            //var results = self.getRandomSubsetFromArray(jsonDataPhotosPhoto, count: count)
                            //println("number of filtered results: \(results.count)")
                            
                            //clear the photos array first
                            self.photos.removeAll()
        
                            //populate photos array with Photo that uses parsed data
                            var index = 0
                            for p in jsonDataPhotosPhoto {

                                //get the image url
                                if let imageHttpUrlString = p["url_m"] as? String {
                                    
                                    let imageURL = NSURL(string: imageHttpUrlString)
                                    
                                    println(imageURL)
                                    
                                    if let imageData = NSData(contentsOfURL: imageURL!) {
                                        
                                        //save the file to disk
                                        let imageLocalUrl = FileHelper.saveJpegWithFileName(imageHttpUrlString.lastPathComponent, image: UIImage(data: imageData)!)
                                        
                                        println(imageLocalUrl)
                                        
                                        //create an actual Photo object
                                        let photo = Photo(imageFileUrl: imageLocalUrl)
                                        self.photos.append(photo)
                                        
                                        //return true to callback to indicate success
                                        completionHandler(completedIndex: index, errorMsg: "")
                                        
                                    } else {
                                        
                                        println("Image does not exist at \(imageURL)")
                                    }
                                    
                                    
                                    
                                } else {
                                    
                                    println("Image URL not provided")
                                    
                                }
                                
                                index += 1
                                
                            }
                            
                        } else {
                            
                            //return false to callback to indicate failure
                            completionHandler(completedIndex: -1, errorMsg: "Unable to get photo details from server: photo")
                        }
                        
                    } else {

                        //return false to callback to indicate failure
                        completionHandler(completedIndex: -1, errorMsg: "No photos found at this location")
                    }
                    
                } else {
                    
                    //return false to callback to indicate failure
                    completionHandler(completedIndex: -1, errorMsg: "Unable to get photo details from server: photos")
                }
            }
        )
    }
    
    private func fetchPhotos(args: [String:String], count: Int, completionHandler: (completedIndex: Int, errorMsg: String)->Void) {
        
        println("flickr request: \(BASE_URL)\(HttpHelper.escapedParameters(args))")
        
        //do a http request first to find the total number of pages
        getTotalPages(args, resultHandler: { totalPages in
            
            println("total page: \(totalPages)")
            
            //then do the actual http request to fetch all photos for a random page within this upper limit
            let pageLimit = min(totalPages, 40)
            let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
            self.fetchPhotosForPage(randomPage, args: args, count: count, completionHandler: completionHandler)
            
        }, completionHandler: completionHandler)
    }
    
    func fetchPhotosUsingText(text: String, count: Int, completionHandler: (completedIndex: Int, errorMsg: String)->Void) {
        
        //ask for more photos than required so that we can filter them later for better randomization
        let perPage = min(count * PER_PAGE_COUNT_MULT, 500)  //max of 500 photos per page
        
        //gather method arguments
        var args = STANDARD_PHOTOS_SEARCH_ARGS  //this does a deep copy which is what I need
        args["text"] = text
        args["per_page"] = "\(perPage)"
        
        //fetch photos
        fetchPhotos(args, count: count, completionHandler: completionHandler)
    }
    
    func fetchPhotosUsingCoordinate(coordinate: CLLocationCoordinate2D, count: Int, completionHandler: (completedIndex: Int, errorMsg: String)->Void) {
        
        //TODO: check for valid coordinates
        
        
        //convert coordinates to a string that flickr expects
        let bboxString = createBboxStringFromCoordinate(coordinate)
        
        //ask for more photos than required so that we can filter them later for better randomization
        let perPage = min(count * PER_PAGE_COUNT_MULT, 500)  //max of 500 photos per page
        
        //gather method arguments
        var args = STANDARD_PHOTOS_SEARCH_ARGS  //this does a deep copy which is what I need
        args["bbox"] = bboxString
        args["per_page"] = "\(perPage)"
        
        //fetch photos
        fetchPhotos(args, count: count, completionHandler: completionHandler)
        
    }
    
}