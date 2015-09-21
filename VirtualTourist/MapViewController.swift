//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Keng Siang Lee on 19/9/15.
//  Copyright (c) 2015 KSL. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    //var annotations = [MKPointAnnotation]()
    
    var longPressRecognizer: UILongPressGestureRecognizer!
    
    //constants for user prefs
    let MAP_VIEW_REGION_CENTER_LONGITUDE = "mapView_region_center_longitude"
    let MAP_VIEW_REGION_CENTER_LATITUDE = "mapView_region_center_latitude"
    let MAP_VIEW_REGION_SPAN_LONGITUDE_DELTA = "mapView_region_span_longitudeDelta"
    let MAP_VIEW_REGION_SPAN_LATITUDE_DELTA = "mapView_region_span_latitudeDelta"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //assign delegate
        mapView.delegate = self
        
        //restore map region from user prefs
        loadMapViewRegion()

        //set long press gesture recognizer
        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: "longPressedCallback:")
        view.addGestureRecognizer(longPressRecognizer)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func longPressedCallback(recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == UIGestureRecognizerState.Began {
            
            //get coordinates
            let pressedPoint = recognizer.locationInView(mapView)
            let pressedCoordinate = mapView.convertPoint(pressedPoint, toCoordinateFromView: mapView)
            
            //add pin from coordinate
            addPinFromCoordinate(pressedCoordinate)
            
            //update map
            
            //mapView.showAnnotations(annotations, animated: false)
        }
    }
    
    func addPinFromCoordinate(coordinate: CLLocationCoordinate2D) {
        var annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
        //annotations.append(annotation)
    }
    
    func showCollectionsViewForPin(pin: MKAnnotation) {
        
        var controller: PhotoAlbumViewController
        controller = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
        controller.annotation = pin
        //presentViewController(controller, animated:true, completion:nil)
        navigationController!.pushViewController(controller, animated: true)

    }
}

//============================================
// MARK: Map View User Preferences
//============================================

extension MapViewController {
    
    func saveMapViewRegion() {
        println("saving map region")
        let region = mapView.regionThatFits(mapView.region)
        NSUserDefaults.standardUserDefaults().setDouble(region.center.longitude, forKey: MAP_VIEW_REGION_CENTER_LONGITUDE)
        NSUserDefaults.standardUserDefaults().setDouble(region.center.latitude, forKey: MAP_VIEW_REGION_CENTER_LATITUDE)
        NSUserDefaults.standardUserDefaults().setDouble(region.span.longitudeDelta, forKey: MAP_VIEW_REGION_SPAN_LONGITUDE_DELTA)
        NSUserDefaults.standardUserDefaults().setDouble(region.span.latitudeDelta, forKey: MAP_VIEW_REGION_SPAN_LATITUDE_DELTA)
        println("\(region.center.longitude) \(region.center.latitude) \(region.span.longitudeDelta) \(region.span.latitudeDelta)")
    }
    
    func loadMapViewRegion() {
        
        println("loading map region")
        
        var region: MKCoordinateRegion = MKCoordinateRegion()
        
        let centerLongitude = NSUserDefaults.standardUserDefaults().doubleForKey(MAP_VIEW_REGION_CENTER_LONGITUDE)
        if centerLongitude != 0.0 {
            region.center.longitude = centerLongitude
        }
        
        let centerLatitude = NSUserDefaults.standardUserDefaults().doubleForKey(MAP_VIEW_REGION_CENTER_LATITUDE)
        if centerLatitude != 0.0 {
            region.center.latitude = centerLatitude
        }
        
        let spanLongitudeDelta = NSUserDefaults.standardUserDefaults().doubleForKey(MAP_VIEW_REGION_SPAN_LONGITUDE_DELTA)
        if spanLongitudeDelta != 0.0 {
            region.span.longitudeDelta = spanLongitudeDelta
        }
        
        let spanLatitudeDelta = NSUserDefaults.standardUserDefaults().doubleForKey(MAP_VIEW_REGION_SPAN_LATITUDE_DELTA)
        if spanLatitudeDelta != 0.0 {
            region.span.latitudeDelta = spanLatitudeDelta
        }
        
        println("\(region.center.longitude) \(region.center.latitude) \(region.span.longitudeDelta) \(region.span.latitudeDelta)")
        mapView.setRegion(region, animated: true)
        //mapView.setCenterCoordinate(region.center, animated: true)
        
    }
}

//============================================
// MARK: Map View Delegate
//============================================

extension MapViewController {

    func mapView(mapView: MKMapView!, regionWillChangeAnimated animated: Bool) {
        //println("xxx")
    }
    
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        //println("\(mapView.region.center.longitude) \(mapView.region.center.latitude)")
        //println("\(mapView.region.span.longitudeDelta) \(mapView.region.span.latitudeDelta)")
        //println("\(NSUserDefaults.standardUserDefaults().doubleForKey(MAP_VIEW_REGION_CENTER_LONGITUDE))")
        //println("\(NSUserDefaults.standardUserDefaults().doubleForKey(MAP_VIEW_REGION_CENTER_LATITUDE))")
        //println("\(NSUserDefaults.standardUserDefaults().doubleForKey(MAP_VIEW_REGION_SPAN_LONGITUDE_DELTA))")
        //println("\(NSUserDefaults.standardUserDefaults().doubleForKey(MAP_VIEW_REGION_SPAN_LATITUDE_DELTA))")
        saveMapViewRegion()
    }
    
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        println("\(view.annotation.coordinate.longitude) \(view.annotation.coordinate.latitude)")
        showCollectionsViewForPin(view.annotation)
        
    }
    
}