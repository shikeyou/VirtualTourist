//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Keng Siang Lee on 19/9/15.
//  Copyright (c) 2015 KSL. All rights reserved.
//

import Foundation

import UIKit
import MapKit

class PhotoAlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    let NUM_PHOTOS_PER_COLLECTION = 20
    
    var annotation: MKAnnotation!
    var photos = [Photo]()

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //add a pin to the map
        addPinFromCoordinate(annotation.coordinate)

        //set region
        let radius: CLLocationDistance = 1000000
        let region = MKCoordinateRegionMakeWithDistance(annotation.coordinate, radius, radius)
        mapView.setRegion(region, animated: true)
    }

    //TODO: make this generic
    func addPinFromCoordinate(coordinate: CLLocationCoordinate2D) {
        var annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
    }
    
    

    func fetchFlickrPhotosForCoordinate(coordinate: CLLocationCoordinate2D) {
        
        //TODO: error check the coordinates
        
        //clear the data and collection view
        self.photos.removeAll(keepCapacity: false)
        self.collectionView.reloadData()
        
        //disable new collection button
        self.newCollectionButton.enabled = false
        
        //show activity indicator
        UiHelper.showActivityIndicator(view: self.view)
        
        //perform the api request
        FlickrClient.sharedInstance().fetchPhotosUsingCoordinate(coordinate, count: NUM_PHOTOS_PER_COLLECTION, completionHandler: { completedIndex, errorMsg in
            
            if completedIndex != -1 {

                dispatch_async(dispatch_get_main_queue(), {
                    
                    println("completedIndex: \(completedIndex)")
                    
                    //get photos data from flickr client
                    self.photos = FlickrClient.sharedInstance().photos
                    
                    //reload specific parts of the collection view with the new data
                    self.collectionView.insertItemsAtIndexPaths([NSIndexPath(forRow: completedIndex, inSection: 0)])
                    
                })
                
                //hide activity indicator after the last photo is fetched
                if completedIndex == self.NUM_PHOTOS_PER_COLLECTION - 1 {
                    dispatch_async(dispatch_get_main_queue(), {
                        UiHelper.hideActivityIndicator()
                        self.newCollectionButton.enabled = true
                    })
                }
                
            } else {
                
                //hide activity indicator on error
                dispatch_async(dispatch_get_main_queue(), {
                    UiHelper.hideActivityIndicator()
                })
                
                //show error msg
                UiHelper.showAlertAsync(view: self, title: "Flickr request failed", msg: errorMsg)
                
            }
            
        })
    }
    
    @IBAction func newCollectionClicked(sender: UIButton) {
        fetchFlickrPhotosForCoordinate(annotation.coordinate)
    }
}

extension PhotoAlbumViewController {

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }

    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {

        //dequeue a reusable cell
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("photoCollectionCell", forIndexPath: indexPath) as! PhotoCollectionViewCell

        //get the photo
        let photo = photos[indexPath.row]
        
        //set appropriate data in the cell
        if let imageData = NSData(contentsOfURL: photo.imageFileUrl!) {
            cell.imageView.image = UIImage(data: imageData)
        } else {
            cell.imageView.image = UIImage(named: "Error")
        }
        cell.backgroundColor = UIColor.blackColor()

        return cell
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSize(width: 75, height: 75)
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

}

class PhotoCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
}