# Brisk Changelog

## 4.0.0 -- 10/28/17

* Swift 4.0 support

## 3.1.1 -- 3/31/17

* Trying to fix cocoapods internal version tagging issue

## 3.1.0 -- 3/30/17

* Updates for Xcode 8.3/Swift 3.1

## 3.0.2 -- 12/24/16

* Added fatalerror calls when passing an optional function to the await operators (<<+) since those must guarantee to call their return function.

## 3.0.1 -- 10/13/16

* Fixed podspec issue for Swift 3.0/cocoapods

## 3.0.0 -- 9/22/16

* First release for Swift 3.0
* Changed GCD component for LibDispatch updates

## 2.3.1 -- 9/11/16

* First release for Swift 2.3
* Removed OSSpinLock API [info](http://engineering.postmates.com/Spinlocks-Considered-Harmful-On-iOS/)

## 2.2.2 -- 8/16/16

* Added operators for optional functions (```?+>>``` and ```?~>>```)

## 2.2.1 -- 8/14/16

* Initial Release for Swift 2.2
