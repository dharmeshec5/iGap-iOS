/*
 * This is the source code of iGap for iOS
 * It is licensed under GNU AGPL v3.0
 * You should have received a copy of the license in this archive (see LICENSE).
 * Copyright © 2017 , iGap - www.iGap.net
 * iGap Messenger | Free, Fast and Secure instant messaging application
 * The idea of the RooyeKhat Media Company - www.RooyeKhat.co
 * All rights reserved.
 */

import UIKit

class iGPhoneNumberPageViewController: UIViewController {

    let greenColor = UIColor(red: 49.0/255.0, green: 189.0/255.0, blue: 182.0/255.0, alpha: 1)
    override func viewDidLoad() {
        super.viewDidLoad()
        let backImage = UIImage(named: "IG_Settigns_Bg")
        let backgroundImageView = UIImageView(image: backImage)
        setBarbuttonItem()
    }
    @IBAction func changeNumberButtonClicked(_ sender: UIButton) {}
    func setBarbuttonItem(){
        //cancelButton
        let cancelBtn = UIButton()
        cancelBtn.frame = CGRect(x: 8, y: 300, width: 60, height: 0)
        cancelBtn.setTitle("Cancel", for: UIControlState.normal)
        cancelBtn.setTitleColor(greenColor, for: .normal)
        cancelBtn.addTarget(self, action: #selector(iGPhoneNumberPageViewController.cancelButtonClicked), for: UIControlEvents.touchUpInside)
        let topLeftbarButtonItem = UIBarButtonItem(customView: cancelBtn)
        self.navigationItem.leftBarButtonItem = topLeftbarButtonItem
    }
    func cancelButtonClicked(){
        self.dismiss(animated: true, completion: nil)
    }
}
