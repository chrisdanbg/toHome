//
//  Constants.swift
//  Pixel City
//
//  Created by Kristyan Danailov on 9.05.18 г..
//  Copyright © 2018 г. Kristyan Danailov. All rights reserved.
//

import Foundation

let apiKey = "7f5409a4715ccc0c049cb7a4379c16f7"

func getPhotos(forApiKey key: String, coordinates: DroppedPin , numberOfPhotos: Int) -> String {
let URL = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(apiKey)&lat=\(coordinates.coordinate.latitude)&lon=\(coordinates.coordinate.longitude)&radius=1&radius_units=km&per_page=\(numberOfPhotos)&format=json&nojsoncallback=1"
    print(URL)
    return URL
}
