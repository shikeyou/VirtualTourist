//
//  HelperFunctions.swift
//  VirtualTourist
//
//  Created by Keng Siang Lee on 26/7/15.
//  Copyright (c) 2015 KSL. All rights reserved.
//

import Foundation
import UIKit
import CoreData

//helper class for HTTP requests
class HttpHelper {
    
    //method that makes a HTTP request
    class func makeHttpRequest(#requestUrl: String, requestMethod: String, requestAddValues: [(String, String)]? = nil, requestBody: NSData? = nil, requestRemoveXsrfToken: Bool = false, requestDataHandler: (data: NSData!, response: NSURLResponse!, error: NSError!)->Void) {
        
        //create the request object
        let request = NSMutableURLRequest(URL: NSURL(string: requestUrl)!)
        request.HTTPMethod = requestMethod
        if requestAddValues != nil {
            for (requestAddValue1, requestAddValue2) in requestAddValues! {
                request.addValue(requestAddValue1, forHTTPHeaderField: requestAddValue2)
            }
        }
        request.HTTPBody = requestBody
        
        //add removal of cross-site request forgery token from request object if requested
        if requestRemoveXsrfToken {
            var xsrfCookie: NSHTTPCookie? = nil
            let sharedCookieStorage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
            for cookie in sharedCookieStorage.cookies as! [NSHTTPCookie] {
                if cookie.name == "XSRF-TOKEN" { xsrfCookie = cookie }
            }
            if let xsrfCookie = xsrfCookie {
                request.addValue(xsrfCookie.value!, forHTTPHeaderField: "X-XSRF-Token")
            }
        }
        
        //get shared session
        let session = NSURLSession.sharedSession()
        
        //create task
        let task = session.dataTaskWithRequest(request, completionHandler: requestDataHandler)
        
        //execute the task
        task.resume()
        
    }
    
    //method that converts a dictionary of parameters to an escaped string for a url (by Jarrod Parkes)
    class func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
            
        }
        
        return (!urlVars.isEmpty ? "?" : "") + join("&", urlVars)
    }
    
    //method that parses raw JSON data into an NSDictionary
    class func parseJsonData(data: NSData) -> (NSDictionary, NSError?) {
        
        var parsingError: NSError? = nil
        
        //parse json data
        let jsonData: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parsingError)
        if parsingError != nil {
            return (NSDictionary(), parsingError)
        }
        
        return (jsonData as! NSDictionary, parsingError)
    }
    
    //method that opens URLs in default browser
    class func openUrl(url: String, view: UIViewController) {
        
        //add http to start of url if it is not already there, otherwise the browser won't open the url
        var newUrl = url
        if url.substringToIndex(advance(url.startIndex, 4)) != "http" {
            newUrl = "http://\(url)"
        }
        
        //create NSURL
        let nsurl = NSURL(string: newUrl)
        if nsurl != nil {
            
            //open the url with default browser
            UIApplication.sharedApplication().openURL(nsurl!)
            
        } else {  //happens when a malformed URL is given e.g. "test test"
            
            UiHelper.showAlert(view: view, title: "Open Url Failed", msg: "Malformed URL provided: \(url)")
            
        }
        
    }
    
}

//helper class for file-related stuff
class FileHelper {
    
    //method that saves a UIImage as a JPEG
    class func saveImageAsJpeg(image: UIImage, filename: String) -> String {
        
        //create the filename for the local file
        let filePath = FileHelper.getDocumentPathForFile(filename)
        
        //create the jpeg data
        let jpegImageData = UIImageJPEGRepresentation(image, 1.0)
        
        //write the jpeg data to disk
        jpegImageData.writeToFile(filePath, atomically: true)
        
        //return the file path
        return filePath
    }
    
    //method that gets the full path to the current Document directory when given a filename
    class func getDocumentPathForFile(filename: String) -> String {
        let dirPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! String
        return dirPath.stringByAppendingPathComponent(filename)
    }
    
}

//helper class for Core Data stuff
class CoreDataHelper {
    
    //method that gets a scratch context for temporary work
    //this is computed lazily by default
    static var scratchContext: NSManagedObjectContext = {
        var context = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
        context.persistentStoreCoordinator = delegate.persistentStoreCoordinator
        return context
    }()
    
    //method that gets the main context
    static var sharedContext: NSManagedObjectContext {
        let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
        return delegate.managedObjectContext!
    }
    
}

//helper class for UI-related stuff
class UiHelper {
    
    static var activityIndicator = UIActivityIndicatorView()
    
    //method that shows the activity indicator
    class func showActivityIndicator(#view: UIView) {
        activityIndicator.frame = CGRect(x: view.frame.midX - 25, y: view.frame.midY - 25, width: 50, height: 50)
        activityIndicator.layer.cornerRadius = 10
        activityIndicator.backgroundColor = UIColor.grayColor()
        activityIndicator.alpha = 0.5
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
    }
    
    //method that hides the activity indicator
    class func hideActivityIndicator() {
        activityIndicator.removeFromSuperview()
        activityIndicator.hidesWhenStopped = true
        activityIndicator.stopAnimating()
    }
    
    //method that shows an alert asynchronously on the main UI thread
    class func showAlertAsync(#view: UIViewController, title: String, msg: String) {
        dispatch_async(dispatch_get_main_queue(), {
            self.showAlert(view: view, title: title, msg: msg)
        })
    }
    
    //method that shows an alert
    class func showAlert(#view: UIViewController, title: String, msg: String) {
        let alertController = UIAlertController()
        alertController.title = title
        alertController.message = msg
        alertController.addAction(
            UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: {
                action in
                alertController.dismissViewControllerAnimated(true, completion: nil)
            })
        )
        view.presentViewController(alertController, animated: true, completion: nil)
    }
    
}
