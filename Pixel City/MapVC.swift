//
//  MapVC.swift
//  Pixel City
//
//  Created by Kristyan Danailov on 9.05.18 г..
//  Copyright © 2018 г. Kristyan Danailov. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Alamofire
import AlamofireImage


import UIKit.UIGestureRecognizerSubclass

// MARK: - State

private enum State {
    case closed
    case open
}

extension State {
    var opposite: State {
        switch self {
        case .open: return .closed
        case .closed: return .open
        }
    }
}

@IBDesignable class MapVC: UIViewController {

    // Variables
    var locationManager = CLLocationManager()
    let authorizationStatus = CLLocationManager.authorizationStatus()
    let regionRadius: Double = 1000
    
    var homeLocation = CLLocationCoordinate2D()
    var newHomeLocation = CLLocationCoordinate2D()
    var screenSize = UIScreen.main.bounds
   
    var spinner: UIActivityIndicatorView?
    var progressLbl: UILabel?
    
    var flowLayout = UICollectionViewFlowLayout()
    var collectionView: UICollectionView?
    
    var imgUrlArray = [String]()
    var imgArray = [UIImage]()
    
    
    // Outlets
    @IBOutlet weak var pullUpViewHeight: NSLayoutConstraint!
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var pullUpView: UIView!
    
    
    // View Did Load
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        locationManager.delegate = self
        configureLocationServices()
        doubleTapOnScreen()
        
        
        // Pop Up Button Layout and Gesture Recognizers
        layout()
        littleView.addGestureRecognizer(littlepanRecognizer)
        popupView.addGestureRecognizer(panRecognizer)
        setHomeButton.addGestureRecognizer(setHomeRecognizer)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
        collectionView?.register(PhotoCell.self, forCellWithReuseIdentifier: "photoCell")
        collectionView?.delegate = self
        collectionView?.dataSource = self
        collectionView?.backgroundColor = #colorLiteral(red: 0.9999960065, green: 1, blue: 1, alpha: 1)
        
        pullUpView.addSubview(collectionView!)
    }
    
    // Actions
    @IBAction func centerButtonWasPressed(_ sender: Any) {
        if CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            centerMapOnUser()
        }
    }
    
    // Functions
    func animateViewUp() {
        pullUpViewHeight.constant = 300
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    func spinnerView() {
        spinner = UIActivityIndicatorView()
        spinner?.center = CGPoint(x: (screenSize.width / 2) - ((spinner?.frame.width)! / 2), y: 150)
        spinner?.activityIndicatorViewStyle = .whiteLarge
        spinner?.color = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
        spinner?.startAnimating()
        collectionView?.addSubview(spinner!)
    }
    
    func addProgressLbl() {
        progressLbl = UILabel()
        progressLbl?.frame = CGRect(x: screenSize.width / 2 - 120, y: 180, width: 240, height: 25)
        progressLbl?.font = UIFont(name: "Avenir Next", size: 18)
        progressLbl?.textColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
        progressLbl?.textAlignment = .center
        collectionView?.addSubview(progressLbl!)
    }
    func removeSpinner() {
        if spinner != nil {
            spinner?.removeFromSuperview()
        }
    }
    func removeProgressLbl() {
        if progressLbl != nil {
            progressLbl?.removeFromSuperview()
        }
    }
    
    func retrieveUrls(forAnnotation annotation: DroppedPin, handler: @escaping (_ status: Bool) -> ()) {
        Alamofire.request(getPhotos(forApiKey: apiKey, coordinates: annotation, numberOfPhotos: 40)).responseJSON { (response) in
            guard let json = response.result.value as? Dictionary<String,AnyObject> else {return}
            let photosDictionary = json["photos"] as! Dictionary<String,AnyObject>
            let photoPage = photosDictionary["photo"] as! [Dictionary<String, AnyObject>]
            for photo in photoPage {
                let postUrl = "https://farm\(photo["farm"]!).staticflickr.com/\(photo["server"]!)/\(photo["id"]!)_\(photo["secret"]!)_h_d.jpg"
                self.imgUrlArray.append(postUrl)

                
            }
            handler(true)
        }
        
    }
    
    func retrieveImg(handler: @escaping (_ status: Bool) -> ()) {
        for URL in imgUrlArray {
            Alamofire.request(URL).responseImage(completionHandler: {(response) in
                guard let image = response.result.value else {return}
                self.imgArray.append(image)
                self.progressLbl?.text = "\(self.imgArray.count)/40 Images Loaded"
                
                if self.imgArray.count == self.imgUrlArray.count {
                    print("finished")
                    handler(true)
                }
            })
        }
    }
    
    func cancelAllSesions() {
        Alamofire.SessionManager.default.session.getTasksWithCompletionHandler { (sessionDataTask, sessionDataUpload, sessionDataDownload) in
            sessionDataTask.forEach({ $0.cancel() })
            sessionDataDownload.forEach({ $0.cancel() })
        }
    }
    
    // Swipes and Taps
    func addSwipe() {
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(closeSwipe(_:)))
        swipeDown.direction = .down
        self.view.addGestureRecognizer(swipeDown)
    }
    
    func doubleTapOnScreen(){
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(addTap(sender:)))
        doubleTap.numberOfTapsRequired = 2
        self.view.addGestureRecognizer(doubleTap)
    }

    @objc func closeSwipe(_ recognizer: UISwipeGestureRecognizer) {
        pullUpViewHeight.constant = 0
        doubleTapOnScreen()
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    // Collection view

    func takeMeHome() {
        let myHomeDestination = loadCoordinates()
        
        let sourceCoordinates = locationManager.location?.coordinate
        let destCoordinates = myHomeDestination![0]
        
        let sourcePlacemark = MKPlacemark(coordinate: sourceCoordinates!)
        let destPlacemark = MKPlacemark(coordinate: destCoordinates)
        
        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        let destItem = MKMapItem(placemark: destPlacemark)
        
        let directionRequiest = MKDirectionsRequest()
        directionRequiest.source = sourceItem
        directionRequiest.destination = destItem
        directionRequiest.transportType = .automobile
        
        let directions = MKDirections(request: directionRequiest)
        directions.calculate { (response, error) in
            guard let response = response  else {
                if let error = error {
                    print("Somethine went wrong")
                }
                return
            }
            let route = response.routes[0]
            self.mapView.add(route.polyline, level: .aboveRoads)
            
            let rekt = route.polyline.boundingMapRect
            self.mapView.setRegion(MKCoordinateRegionForMapRect(rekt), animated: true)
            
        }
        
        
        
    }
    
    func storeCoordinates(_ coordinates: [CLLocationCoordinate2D]) {
        let locations = coordinates.map { coordinate -> CLLocation in
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        let archived = NSKeyedArchiver.archivedData(withRootObject: locations)
        UserDefaults.standard.set(archived, forKey: "coordinates")
        UserDefaults.standard.synchronize()
    }
    
    func loadCoordinates() -> [CLLocationCoordinate2D]? {
        guard let archived = UserDefaults.standard.object(forKey: "coordinates") as? Data,
            let locations = NSKeyedUnarchiver.unarchiveObject(with: archived) as? [CLLocation] else {
                return nil
        }
        
        let coordinates = locations.map { location -> CLLocationCoordinate2D in
            return location.coordinate
        }
        
        return coordinates
    }
    ////////////////// POPUPVIEWBEGINS
    
    // MARK: - Constants
    
    private let popupOffset: CGFloat = 440
    private let offset: CGFloat = 150
    
    // MARK: - Views
    private lazy var littleView: UIView = {
        let view = UIView ()
        view.backgroundColor = .white
        view.layer.shadowOpacity = 0.4
        view.layer.shadowRadius = 10
        view.layer.cornerRadius = 20.0
        view.alpha = 1
        view.layer.masksToBounds = true
        view.layer.backgroundColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
        return view
    }()
    
    private lazy var overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.alpha = 0
        return view
    }()
    
    private lazy var popupView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 10
        return view
    }()
    
    private lazy var arrowImg: UIImageView = {
        let imageView = UIImageView()
        imageView.image = #imageLiteral(resourceName: "home-icon-silhouette")
        return imageView
    }()
    
    private lazy var closedTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Set My Home"
        label.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.medium)
        label.textColor = #colorLiteral(red: 0, green: 0.5898008943, blue: 1, alpha: 1)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var openTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Set My Home"
        label.font = UIFont.systemFont(ofSize: 24, weight: UIFont.Weight.heavy)
        label.textColor = .black
        label.textAlignment = .center
        label.alpha = 0
        label.transform = CGAffineTransform(scaleX: 0.65, y: 0.65).concatenating(CGAffineTransform(translationX: 0, y: -15))
        return label
    }()
    
        var toHomeButton: UIButton = {
        let button = UIButton()
        button.setTitle("To Home", for: .normal)
        button.layer.cornerRadius = 20.0
        button.clipsToBounds = true
        button.backgroundColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
        button.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 18)
        button.showsTouchWhenHighlighted = true
        button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        return button
    }()
    
        var setHomeButton: UIButton = {
        let newbutton = UIButton()
        newbutton.setTitle("Set Pin As Your Home", for: .normal)
        newbutton.layer.cornerRadius = 20.0
        newbutton.clipsToBounds = true
        newbutton.backgroundColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
        newbutton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 18)
        newbutton.showsTouchWhenHighlighted = true
        newbutton.addTarget(self, action: #selector(setNewHome), for: .touchUpInside)
        return newbutton
    }()
    
    @objc func setNewHome(sender: UIButton!) {
        newHomeLocation = homeLocation
        storeCoordinates([newHomeLocation])
    }
    
    @objc func buttonAction(sender: UIButton!) {
        takeMeHome()
        UIView.animate(withDuration: 0.6,
                       animations: {
                        self.toHomeButton.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        },
                       completion: { _ in
                        UIView.animate(withDuration: 0.6) {
                            self.toHomeButton.transform = CGAffineTransform.identity
                        }
        })
    }

    // MARK: - View Controller Lifecycle

    
    override var prefersStatusBarHidden: Bool {
        return true
        
    }
    
    // MARK: - Layout
    
    private var bottomConstraint = NSLayoutConstraint()

    private func layout() {
        
        setHomeButton.translatesAutoresizingMaskIntoConstraints = false
        popupView.addSubview(setHomeButton)
        setHomeButton.leadingAnchor.constraint(equalTo: popupView.leadingAnchor, constant: 60).isActive = true
        setHomeButton.trailingAnchor.constraint(equalTo: popupView.trailingAnchor, constant: -60).isActive = true
        setHomeButton.bottomAnchor.constraint(equalTo: popupView.bottomAnchor, constant: -370).isActive = true
        setHomeButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        toHomeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toHomeButton)
        toHomeButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        toHomeButton.widthAnchor.constraint(equalToConstant: 140).isActive = true
        toHomeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        toHomeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32).isActive = true
        
        arrowImg.translatesAutoresizingMaskIntoConstraints = false
        littleView.addSubview(arrowImg)
        arrowImg.bottomAnchor.constraint(equalTo: littleView.bottomAnchor, constant: -5).isActive = true
        arrowImg.trailingAnchor.constraint(equalTo: littleView.trailingAnchor, constant: -10).isActive = true
        arrowImg.heightAnchor.constraint(equalToConstant: 40).isActive = true
        arrowImg.widthAnchor.constraint(equalToConstant: 40).isActive = true
        
        
        littleView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(littleView)
        littleView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -15).isActive = true
        bottomConstraint = littleView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32)
        bottomConstraint.isActive = true
        littleView.heightAnchor.constraint(equalToConstant: 50).isActive = true
        littleView.widthAnchor.constraint(equalToConstant: 75).isActive = true
        
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        overlayView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        popupView.alpha = 0
        popupView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(popupView)
        popupView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        popupView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        bottomConstraint = popupView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: popupOffset)
        bottomConstraint.isActive = true
        popupView.heightAnchor.constraint(equalToConstant: 500).isActive = true
        
        closedTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        popupView.addSubview(closedTitleLabel)
        closedTitleLabel.leadingAnchor.constraint(equalTo: popupView.leadingAnchor).isActive = true
        closedTitleLabel.trailingAnchor.constraint(equalTo: popupView.trailingAnchor).isActive = true
        closedTitleLabel.topAnchor.constraint(equalTo: popupView.topAnchor, constant: 20).isActive = true
        
        openTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        popupView.addSubview(openTitleLabel)
        openTitleLabel.leadingAnchor.constraint(equalTo: popupView.leadingAnchor).isActive = true
        openTitleLabel.trailingAnchor.constraint(equalTo: popupView.trailingAnchor).isActive = true
        openTitleLabel.topAnchor.constraint(equalTo: popupView.topAnchor, constant: 30).isActive = true
        
        
    }
    
    // MARK: - Animation
    
    /// The current state of the animation. This variable is changed only when an animation completes.
    private var currentState: State = .closed
    
    /// All of the currently running animators.
    private var runningAnimators = [UIViewPropertyAnimator]()
    
    /// The progress of each animator. This array is parallel to the `runningAnimators` array.
    private var animationProgress = [CGFloat]()
    
    private lazy var panRecognizer: InstantPanGestureRecognizer = {
        let recognizer = InstantPanGestureRecognizer()
        recognizer.addTarget(self, action: #selector(popupViewPanned(recognizer:)))
        return recognizer
    }()
    private lazy var littlepanRecognizer: InstantPanGestureRecognizer = {
        let recognizer = InstantPanGestureRecognizer()
        recognizer.addTarget(self, action: #selector(popupViewPanned(recognizer:)))
        return recognizer
    }()
    private lazy var setHomeRecognizer: InstantPanGestureRecognizer = {
        let recognizer = InstantPanGestureRecognizer()
        recognizer.addTarget(self, action: #selector(setNewHome(sender:)))
        return recognizer
    }()
    
    
    /// Animates the transition, if the animation is not already running.
    private func animateTransitionIfNeeded(to state: State, duration: TimeInterval) {
        
        // ensure that the animators array is empty (which implies new animations need to be created)
        guard runningAnimators.isEmpty else { return }
        
        // an animator for the transition
        let transitionAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1, animations: {
            switch state {
            case .open:
                
                self.setHomeButton.transform = .identity
                self.bottomConstraint.constant = 280
                self.popupView.layer.cornerRadius = 20
                self.popupView.alpha = 1
                self.overlayView.alpha = 0.5
                self.closedTitleLabel.transform = CGAffineTransform(scaleX: 1.6, y: 1.6).concatenating(CGAffineTransform(translationX: 0, y: 15))
                self.openTitleLabel.transform = .identity
            case .closed:
               
                
                self.bottomConstraint.constant = self.popupOffset
                self.popupView.layer.cornerRadius = 0
                self.popupView.alpha = 0
                self.overlayView.alpha = 0
                self.closedTitleLabel.transform = .identity
                self.openTitleLabel.transform = CGAffineTransform(scaleX: 0.65, y: 0.65).concatenating(CGAffineTransform(translationX: 0, y: -15))
            }
            self.view.layoutIfNeeded()
        })
        
        // the transition completion block
        transitionAnimator.addCompletion { position in
            
            // update the state
            switch position {
            case .start:
                self.currentState = state.opposite
            case .end:
                self.currentState = state
            case .current:
                ()
            }
            
            // manually reset the constraint positions
            switch self.currentState {
            case .open:
                self.bottomConstraint.constant = 280
            case .closed:
                self.bottomConstraint.constant = self.popupOffset
            
            }
            
            // remove all running animators
            self.runningAnimators.removeAll()
            
        }
        
        // an animator for the title that is transitioning into view
        let inTitleAnimator = UIViewPropertyAnimator(duration: duration, curve: .easeIn, animations: {
            switch state {
            case .open:
                self.openTitleLabel.alpha = 1
            case .closed:
                self.closedTitleLabel.alpha = 1
            }
        })
        inTitleAnimator.scrubsLinearly = false
        
        // an animator for the title that is transitioning out of view
        let outTitleAnimator = UIViewPropertyAnimator(duration: duration, curve: .easeOut, animations: {
            switch state {
            case .open:
                self.closedTitleLabel.alpha = 0
            case .closed:
                self.openTitleLabel.alpha = 0
            }
        })
        outTitleAnimator.scrubsLinearly = false
        
        // start all animators
        transitionAnimator.startAnimation()
        inTitleAnimator.startAnimation()
        outTitleAnimator.startAnimation()
        
        // keep track of all running animators
        runningAnimators.append(transitionAnimator)
        runningAnimators.append(inTitleAnimator)
        runningAnimators.append(outTitleAnimator)
        
    }
    
    @objc private func popupViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            
            // start the animations
            animateTransitionIfNeeded(to: currentState.opposite, duration: 1)
            
            // pause all animations, since the next event may be a pan changed
            runningAnimators.forEach { $0.pauseAnimation() }
            
            // keep track of each animator's progress
            animationProgress = runningAnimators.map { $0.fractionComplete }
            
        case .changed:
            
            // variable setup
            let translation = recognizer.translation(in: popupView)
            var fraction = -translation.y / popupOffset
            
            // adjust the fraction for the current state and reversed state
            if currentState == .open { fraction *= -1 }
            if runningAnimators[0].isReversed { fraction *= -1 }
            
            // apply the new fraction
            for (index, animator) in runningAnimators.enumerated() {
                animator.fractionComplete = fraction + animationProgress[index]
            }
            
        case .ended:
            
            // variable setup
            let yVelocity = recognizer.velocity(in: popupView).y
            let shouldClose = yVelocity > 0
            
            // if there is no motion, continue all animations and exit early
            if yVelocity == 0 {
                runningAnimators.forEach { $0.continueAnimation(withTimingParameters: nil, durationFactor: 0) }
                break
            }
            
            // reverse the animations based on their current state and pan motion
            switch currentState {
            case .open:
                if !shouldClose && !runningAnimators[0].isReversed { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
                if shouldClose && runningAnimators[0].isReversed { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
            case .closed:
                if shouldClose && !runningAnimators[0].isReversed { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
                if !shouldClose && runningAnimators[0].isReversed { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
            }
            
            // continue all animations
            runningAnimators.forEach { $0.continueAnimation(withTimingParameters: nil, durationFactor: 0) }
            
        default:
            ()
        }
    }
    
}

// MARK: - InstantPanGestureRecognizer

/// A pan gesture that enters into the `began` state on touch down instead of waiting for a touches moved event.

    /////////////// POPUP VIEW END
extension MapVC: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        let colorpin = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "droppablePin")
        colorpin.pinTintColor = #colorLiteral(red: 0.9607843161, green: 0.7058823705, blue: 0.200000003, alpha: 1)
        colorpin.animatesDrop = true
        return colorpin
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let render = MKPolylineRenderer(overlay: overlay)
        render.strokeColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
        render.lineWidth = 5.0
        return render
    }
    
    func centerMapOnUser() {
        guard let coordinate = locationManager.location?.coordinate else { return }
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(coordinate, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
 
    
    @objc func addTap(sender: UITapGestureRecognizer) {
        cancelAllSesions()
      //  removePin()
      //  removeProgressLbl()
       // removeSpinner()
       
     //  imgUrlArray = []
     //   imgArray = []
      //  self.collectionView?.reloadData()
        
        ///// 
        /////
       // spinnerView()
       // animateViewUp()
       // addProgressLbl()
       // addSwipe()

        
        let touchPoint = sender.location(in: mapView)
        let touchCoordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        homeLocation = touchCoordinate
        
        let annotation = DroppedPin(coordinate: touchCoordinate, identifier: "droppablePin")
        mapView.addAnnotation(annotation)
        
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(touchCoordinate, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
        
           
        }

    
    func removePin() {
        for annotation in mapView.annotations {
            mapView.removeAnnotation(annotation)
            
        }
    }
}
extension MapVC: CLLocationManagerDelegate {
    func configureLocationServices() {
        if authorizationStatus == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        } else { return }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        centerMapOnUser()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
}
extension MapVC: UICollectionViewDelegate, UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imgArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? PhotoCell else { return UICollectionViewCell() }
        let imageFromIndex = imgArray[indexPath.row]
        let imageView = UIImageView(image: imageFromIndex)
        cell.addSubview(imageView)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let popVC = storyboard?.instantiateViewController(withIdentifier: "PopVC") as? PopVC else {return}
        popVC.initData(forImage: imgArray[indexPath.row])
        present(popVC, animated: true, completion: nil)
    }
}
class InstantPanGestureRecognizer: UIPanGestureRecognizer {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if (self.state == UIGestureRecognizerState.began) { return }
        super.touchesBegan(touches, with: event)
        self.state = UIGestureRecognizerState.began
    }
    
}
