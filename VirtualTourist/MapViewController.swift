//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Keng Siang Lee on 19/9/15.
//  Copyright (c) 2015 KSL. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate {

    //============================================
    // MARK: CONSTANTS
    //============================================
    
    //constants for user prefs
    let MAP_VIEW_REGION_CENTER_LONGITUDE = "mapView_region_center_longitude"
    let MAP_VIEW_REGION_CENTER_LATITUDE = "mapView_region_center_latitude"
    let MAP_VIEW_REGION_SPAN_LONGITUDE_DELTA = "mapView_region_span_longitudeDelta"
    let MAP_VIEW_REGION_SPAN_LATITUDE_DELTA = "mapView_region_span_latitudeDelta"
    
    //============================================
    // MARK: INSTANCE VARIABLES
    //============================================
    
    var pins = [Pin]()
    
    var longPressRecognizer: UILongPressGestureRecognizer!
    
    //============================================
    // MARK: IBOUTLETS
    //============================================
    
    @IBOutlet weak var mapView: MKMapView!
    
    //============================================
    // MARK: LIFE CYCLE METHODS
    //============================================
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //assign delegate
        mapView.delegate = self

        //setup long press gesture recognizer
        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: "longPressedCallback:")
        view.addGestureRecognizer(longPressRecognizer)
        
        //restore map region from user prefs
        loadMapViewRegion()
        
        //load pins from core data
        loadPinsFromCoreData()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //============================================
    // MARK: CALLBACK FUNCTIONS
    //============================================
    
    func longPressedCallback(recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == UIGestureRecognizerState.Began {
            
            //get coordinates
            let pressedPoint = recognizer.locationInView(mapView)
            let pressedCoordinate = mapView.convertPoint(pressedPoint, toCoordinateFromView: mapView)
            
            //add pin from coordinate
            addPinFromCoordinate(pressedCoordinate)
        }
    }
    
    //============================================
    // MARK: METHODS
    //============================================
    
    func addPinFromCoordinate(coordinate: CLLocationCoordinate2D) {
        
        //store a pin
        var pin: Pin!
        CoreDataHelper.sharedContext.performBlockAndWait({
            pin = Pin(latitude: Float(coordinate.latitude), longitude: Float(coordinate.longitude), context: CoreDataHelper.sharedContext)
            self.pins.append(pin)
        })
        
        //add an annotation to the map
        var annotation = PinAnnotation(coordinate: coordinate, pin: pin)
        mapView.addAnnotation(annotation)
        
        //save core data
        saveChangesToCoreData()
        
    }
    
    func showCollectionsViewForPin(pin: PinAnnotation) {
        
        var controller: PhotoAlbumViewController
        controller = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
        controller.pinAnnotation = pin
        navigationController!.pushViewController(controller, animated: true)

    }
    
    //============================================
    // MARK: CORE DATA METHODS
    //============================================
    
    func saveChangesToCoreData() {
        var error: NSError? = nil
        CoreDataHelper.sharedContext.performBlockAndWait({
            CoreDataHelper.sharedContext.save(&error)
        })
        if let error = error {
            UiHelper.showAlertAsync(view: self, title: "Core Data Save Error", msg: "Unable to save changes to Core Data")
            return
        }
    }
    
    func loadPinsFromCoreData() {
        
        //prepare fetch request
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        
        //fetch results
        let error: NSErrorPointer = nil
        var results: [AnyObject]?
        CoreDataHelper.sharedContext.performBlockAndWait({
            results = CoreDataHelper.sharedContext.executeFetchRequest(fetchRequest, error: error)
        })
        if error != nil {
            UiHelper.showAlertAsync(view: self, title: "Core Data Load Error", msg: "Unable to load pins from Core Data")
            return
        }
        pins = results as! [Pin]
        
        //convert to annotations and load them on map
        var annotations = [PinAnnotation]()
        CoreDataHelper.sharedContext.performBlockAndWait({
            for pin in self.pins {
                let annotation = PinAnnotation(coordinate: CLLocationCoordinate2D(latitude: CLLocationDegrees(pin.latitude), longitude: CLLocationDegrees(pin.longitude)), pin: pin)
                annotations.append(annotation)
            }
        })
        mapView.addAnnotations(annotations)
    }
    
    //============================================
    // MARK: MAP VIEW PERSISTENCE METHODS
    //============================================
    
    func saveMapViewRegion() {
        
        let region = mapView.regionThatFits(mapView.region)
        
        //store variables to user defaults
        NSUserDefaults.standardUserDefaults().setDouble(region.center.longitude, forKey: MAP_VIEW_REGION_CENTER_LONGITUDE)
        NSUserDefaults.standardUserDefaults().setDouble(region.center.latitude, forKey: MAP_VIEW_REGION_CENTER_LATITUDE)
        NSUserDefaults.standardUserDefaults().setDouble(region.span.longitudeDelta, forKey: MAP_VIEW_REGION_SPAN_LONGITUDE_DELTA)
        NSUserDefaults.standardUserDefaults().setDouble(region.span.latitudeDelta, forKey: MAP_VIEW_REGION_SPAN_LATITUDE_DELTA)
    }
    
    func loadMapViewRegion() {
        
        var region: MKCoordinateRegion = MKCoordinateRegion()
        
        //read stored variables from user defaults
        region.center.longitude = NSUserDefaults.standardUserDefaults().doubleForKey(MAP_VIEW_REGION_CENTER_LONGITUDE)
        region.center.latitude = NSUserDefaults.standardUserDefaults().doubleForKey(MAP_VIEW_REGION_CENTER_LATITUDE)
        region.span.longitudeDelta = NSUserDefaults.standardUserDefaults().doubleForKey(MAP_VIEW_REGION_SPAN_LONGITUDE_DELTA)
        region.span.latitudeDelta = NSUserDefaults.standardUserDefaults().doubleForKey(MAP_VIEW_REGION_SPAN_LATITUDE_DELTA)
        
        //set map view region if a region save has been done previously (i.e. all variables are not 0)
        if region.center.longitude != 0.0 && region.center.latitude != 0.0 && region.span.longitudeDelta != 0.0 && region.span.latitudeDelta != 0.0 {
            mapView.setRegion(region, animated: true)
        }
        
    }
}

//============================================
// MARK: MAP VIEW DELEGATE METHODS
//============================================

extension MapViewController {
    
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        saveMapViewRegion()
    }
    
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        
        //deselect the annotation so that we can select it immediately again later
        mapView.deselectAnnotation(view.annotation, animated: false)
        
        //show album
        showCollectionsViewForPin(view.annotation as! PinAnnotation)
    }
    
}