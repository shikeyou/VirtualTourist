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
import CoreData

class PhotoAlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    //============================================
    // MARK: CONSTANTS
    //============================================
    
    let NUM_PHOTOS_PER_COLLECTION = 20
    let NUM_PHOTOS_PER_ROW: CGFloat = 4
    let BORDER_SIZE: CGFloat = 2
    
    //============================================
    // MARK: INSTANCE VARIABLES
    //============================================
    
    var pinAnnotation: PinAnnotation!
    var photos = [Photo]()
    
    //for keeping track of fetch requests
    var isFetching = false
    var totalPhotosFetched = 0
    
    //for keeping track of selection states
    var isSelecting = false
    var selectedIndices = Set<Int>()

    //============================================
    // MARK: IBOUTLETS
    //============================================
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
    @IBOutlet weak var removeSelectedButton: UIButton!
    
    //============================================
    // MARK: LIFE CYCLE METHODS
    //============================================
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //add an annotation to the map
        addPointAnnotationFromCoordinate(pinAnnotation.coordinate)
        
        //set region
        let radius: CLLocationDistance = 1000000
        let region = MKCoordinateRegionMakeWithDistance(pinAnnotation.coordinate, radius, radius)
        mapView.setRegion(region, animated: true)
        
        //load photos from core data
        let fetchedPhotos = fetchPhotosFromCoreData()
        if fetchedPhotos.count > 0 {
            //just assign photos variable to the array that has been fetched and refresh view
            photos = fetchedPhotos
            collectionView.reloadData()
        } else {
            //otherwise, auto download flickr photos
            fetchFlickrPhotos()
        }
        
    }

    //============================================
    // MARK: CORE DATA METHODS
    //============================================
    
    func saveChangesToCoreData() {
        var error: NSError? = nil
        CoreDataHelper.sharedContext.save(&error)
        if let error = error {
            UiHelper.showAlert(view: self, title: "Core Data Save Error", msg: "Unable to save photo changes to Core Data")
        }
    }
    
    func fetchPhotosFromCoreData() -> [Photo] {
        
        //prepare fetch request - photos for this specific pin
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.predicate = NSPredicate(format: "pin==%@", self.pinAnnotation.pin)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        //fetch the results
        let error: NSErrorPointer = nil
        let results = CoreDataHelper.sharedContext.executeFetchRequest(fetchRequest, error: error)
        if error != nil {
            UiHelper.showAlert(view: self, title: "Core Data Load Error", msg: "Unable to load photos from Core Data for this pin")
        }
        
        return results as! [Photo]
    }
    
    //============================================
    // MARK: METHODS
    //============================================
    
    func addPointAnnotationFromCoordinate(coordinate: CLLocationCoordinate2D) {
        var annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
    }
    
    func clearPhotoAtIndex(index: Int, updateImmediately: Bool = true) {
        
        let photo = photos[index]
        
        //remove the local image file
        let error: NSErrorPointer = nil
        let imageFilePath = FileHelper.getDocumentPathForFile(photo.imageFileName!)
        NSFileManager.defaultManager().removeItemAtPath(imageFilePath, error: error)
        if error != nil {
            UiHelper.showAlert(view: self, title: "File Deletion Error", msg: "Unable to delete image file \(imageFilePath)")
        }
        
        //remove association with pin
        photo.pin = nil
        
        //delete the object in core data
        CoreDataHelper.sharedContext.deleteObject(photo)
        
        if updateImmediately {
            
            //save in core data
            saveChangesToCoreData()
            
            //remove item from array
            photos.removeAtIndex(index)
        }
        
    }
    
    func clearAllPhotos() {
        
        //clear each photo
        for i in 0..<photos.count {
            clearPhotoAtIndex(i, updateImmediately: false)
        }
        
        //save in core data
        saveChangesToCoreData()
        
        //empty the photos array
        photos.removeAll(keepCapacity: false)
    }

    func fetchFlickrPhotos() {
        
        //enable fetch guard
        isFetching = true
        
        //disable new collection button
        newCollectionButton.enabled = false
        
        //show activity indicator
        dispatch_async(dispatch_get_main_queue(), {
            UiHelper.showActivityIndicator(view: self.view)
        })
        
        //perform the api request
        FlickrClient.sharedInstance().fetchPhotosUsingCoordinate(
            pinAnnotation.coordinate,
            count: NUM_PHOTOS_PER_COLLECTION,
            totalHandler: { total in
                
                //store total photos
                self.totalPhotosFetched = total
                
                //place in that number of placeholders
                self.clearAllPhotos()
                for index in 0..<total {
                    self.photos.append(Photo(imageFileName: "loading", context: CoreDataHelper.scratchContext))
                }
                
                //reload view
                dispatch_async(dispatch_get_main_queue(), {
                    self.collectionView.reloadData()
                })
                
            },
            completionHandler: { completedIndex, errorMsg in
            
                if completedIndex != -1 {

                    dispatch_async(dispatch_get_main_queue(), {
                        
                        //update photo data to use main shared context
                        let completedImageFileName = FlickrClient.sharedInstance().photos[completedIndex].imageFileName
                        self.photos[completedIndex] = Photo(imageFileName: completedImageFileName, context: CoreDataHelper.sharedContext)
                        self.photos[completedIndex].pin = self.pinAnnotation.pin
                        
                        //reload specific parts of the collection view with the new data
                        self.collectionView.reloadItemsAtIndexPaths([NSIndexPath(forItem: completedIndex, inSection: 0)])
                        
                    })
                    
                    //do some cleaning up when last photo is fetched
                    if completedIndex == self.totalPhotosFetched - 1 {
                        dispatch_async(dispatch_get_main_queue(), {
                            
                            //hide the activity indicator
                            UiHelper.hideActivityIndicator()
                            
                            //enable new collection button
                            self.newCollectionButton.enabled = true
                            
                            //disable fetch guard
                            self.isFetching = false
                            
                            //save core data
                            self.saveChangesToCoreData()
                        })
                    }
                    
                } else {
                    
                    dispatch_async(dispatch_get_main_queue(), {
                        
                        //hide activity indicator on error
                        UiHelper.hideActivityIndicator()
                        
                        //enable new collection button
                        self.newCollectionButton.enabled = true
                        
                        //disable fetch guard
                        self.isFetching = false

                    })
                    
                    //show error msg
                    UiHelper.showAlertAsync(view: self, title: "Flickr request failed", msg: errorMsg)

                }
            }
        )
    }
    
    func setSelectionState(isSelecting: Bool) {
        
        //set overall state variable
        self.isSelecting = isSelecting
        
        //show hide buttons
        newCollectionButton.hidden = isSelecting
        removeSelectedButton.hidden = !isSelecting
        
        //clear selection set if selection has ended
        if !self.isSelecting {
            selectedIndices.removeAll(keepCapacity: false)
        }
        
    }
    
    //============================================
    // MARK: IBACTIONS AND CALLBACKS
    //============================================
    
    @IBAction func newCollectionClicked(sender: UIButton) {
        fetchFlickrPhotos()
    }
    
    @IBAction func removeSelectedClicked(sender: UIButton) {
        
        //remove selected indices
        for i in reverse(sorted(selectedIndices)) {
            
            //deselect the reusable cell if it is accessible
            if let cell = collectionView.cellForItemAtIndexPath(NSIndexPath(forItem: i, inSection: 0)) as? PhotoCollectionViewCell {
                cell.deselect()
            }
            
            //clear and remove
            clearPhotoAtIndex(i, updateImmediately: false)
            photos.removeAtIndex(i)
            
        }
        
        //save to core data
        saveChangesToCoreData()
        
        //reload collection view
        collectionView.reloadData()
        
        //end selection state
        setSelectionState(false)
        
    }
    
}

//============================================
// MARK: COLLECTION VIEW DELEGATE METHODS
//============================================

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
        if let fileName = photo.imageFileName {
            
            //if file path is set to "loading", show the loading icon as a placeholder
            if fileName == "loading" {
                cell.imageView.image = UIImage(named: "Loading")
            } else {
                
                //get current documents directory with file name
                let filePath = FileHelper.getDocumentPathForFile(fileName)
                
                if let imageData = NSData(contentsOfURL: NSURL.fileURLWithPath(filePath)!) {
                    cell.imageView.image = UIImage(data: imageData)
                } else {
                    cell.imageView.image = UIImage(named: "Error")
                }
                
            }
            
        } else {
            cell.imageView.image = UIImage(named: "Error")
        }

        //set image view alpha value to appropriate value based on selection
        if selectedIndices.contains(indexPath.row) {
            cell.select()
        } else {
            cell.deselect()
        }
        
        //set background to white
        cell.backgroundColor = UIColor.whiteColor()

        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        //don't allow selection during fetching
        if isFetching {
            return
        }
        
        //turn on global selection state to indicate that selection has started
        setSelectionState(true)
        
        //toggle highlight of image
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoCollectionViewCell
        cell.toggleSelection()
        
        //update selectedIndices set accordingly
        if cell.isCurrentlySelected() {
            selectedIndices.insert(indexPath.row)
        } else {
            selectedIndices.remove(indexPath.row)
        }
        
        //if nothing is selected anymore, turn off global selection state
        if selectedIndices.count == 0 {
            setSelectionState(false)
        }

    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let size = (collectionView.bounds.size.width - (NUM_PHOTOS_PER_ROW + 1) * BORDER_SIZE) / NUM_PHOTOS_PER_ROW
        return CGSize(width: size, height: size)
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: BORDER_SIZE, left: BORDER_SIZE, bottom: BORDER_SIZE, right: BORDER_SIZE)
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return BORDER_SIZE
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return BORDER_SIZE
    }

}

//============================================
// MARK: CUSTOM COLLECTION VIEW CELL
//============================================

class PhotoCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    
    let SELECTION_ALPHA: CGFloat = 0.5
    
    func select() {
        imageView.alpha = SELECTION_ALPHA
    }
    
    func deselect() {
        imageView.alpha = 1.0
    }
    
    func toggleSelection() {
        imageView.alpha = imageView.alpha == SELECTION_ALPHA ? 1.0 : SELECTION_ALPHA
    }
    
    func isCurrentlySelected() -> Bool {
        return imageView.alpha == SELECTION_ALPHA
    }
}