//
//  PopVC.swift
//  Pixel City
//
//  Created by Kristyan Danailov on 10.05.18 г..
//  Copyright © 2018 г. Kristyan Danailov. All rights reserved.
//

import UIKit

class PopVC: UIViewController {

    @IBOutlet weak var selectedImage: UIImageView!
    
    var popImage: UIImage!
    
    func initData(forImage image: UIImage) {
        self.popImage = image
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        selectedImage.image = popImage
        doubleTapOnScreen()
    }

    func doubleTapOnScreen(){
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(addTap(sender:)))
        doubleTap.numberOfTapsRequired = 2
        self.view.addGestureRecognizer(doubleTap)
    }
    
     @objc func addTap(sender: UITapGestureRecognizer) {
        dismiss(animated: true, completion: nil)
    }
}
