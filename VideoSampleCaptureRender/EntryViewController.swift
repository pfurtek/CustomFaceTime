//
//  EntryViewController.swift
//  VideoSampleCaptureRender
//
//  Created by Pawel Furtek on 7/29/16.
//  Copyright © 2016 Twilio. All rights reserved.
//

import UIKit

let appDomain = "talkshop.im"

class EntryViewController: UIViewController, UITextViewDelegate {
    @IBOutlet weak var numberTextField: UITextField!
    
    var token : String = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImN0eSI6InR3aWxpby1mcGE7dj0xIn0.eyJqdGkiOiJTSzE5ODhkZmE3NDFkNGVmZTNjZDE3MDFlNThlOWE3Yzk0LTE0Njk4MzE2MDMiLCJpc3MiOiJTSzE5ODhkZmE3NDFkNGVmZTNjZDE3MDFlNThlOWE3Yzk0Iiwic3ViIjoiQUM5OWNlMzg2MjUzNWI2NWNkNWRmOTU3ZTQxZGI4NGJkMyIsImV4cCI6MTQ2OTgzNTIwMywiZ3JhbnRzIjp7ImlkZW50aXR5IjoiUE40M2JmNmE3Y2Q3OGQ0YWY3ZDZhYzA1Mjg0ZGQwNjIxNiIsInJ0YyI6eyJjb25maWd1cmF0aW9uX3Byb2ZpbGVfc2lkIjoiVlM2MzExNzVkMmIzNGUxMDMwYWUzNThkOTU1ZDdhNTk0ZSJ9fX0.-2QYVfa4EUmRb-NVnNh66Gd3IZhASha3VGNIr7Rll4U"

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.numberTextField.text = NSUserDefaults.standardUserDefaults().stringForKey("number")

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func retrieveAccessTokenFromServer(number: String, completion: (Bool, ErrorType?)->Void) {
        print("Get that Twilio access token please.")
        let requestURL: NSURL = NSURL(string: "https://mfygscq.\(appDomain)/api/v1/tokens/new.json?jid=\(number)")!
        let urlRequest: NSMutableURLRequest = NSMutableURLRequest(URL: requestURL)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(urlRequest) {
            (data, response, error) -> Void in
            
            let httpResponse = response as! NSHTTPURLResponse
            let statusCode = httpResponse.statusCode
            
            if (statusCode == 200) {
                
                do{
                    
                    let json = try NSJSONSerialization.JSONObjectWithData(data!, options:.AllowFragments)
                    
                    print("\(json)")
                    
                    if let accessToken = json["token"] as? String {
                        print("DAT TOKEN!\(accessToken)")
                        /*self.accessManager = TwilioAccessManager(token: accessToken, delegate: self)
                         self.conversationsClient = TwilioConversationsClient(accessManager: self.accessManager, delegate: self)
                         self.conversationsClient.listen()*/
                        self.token = accessToken
                        completion(true, nil)
                    }
                } catch {
                    //print("Error with Json: \(error)")
                    completion(false, error)
                }
            }
        }
        
        task.resume()
    }
    
    @IBAction func goClicked(sender: AnyObject) {
        if let number = numberTextField.text {
            //perform a call to get the token
            if number != "" {
                self.login = "\(number)@talkshop.co"
                NSUserDefaults.standardUserDefaults().setObject(number, forKey: "number")
                retrieveAccessTokenFromServer(login, completion: { (success,error) in
                    dispatch_async(dispatch_get_main_queue(), {
                        if success {
                            self.performSegueWithIdentifier("tokenValid", sender: self)
                        } else {
                            print(error)
                        }
                    })
                })
            }
        }
    }
    
    var login: String = ""
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if let number = numberTextField.text {
            //perform a call to get the token
            if number != "" {
                self.login = "\(number)@talkshop.co"
                NSUserDefaults.standardUserDefaults().setObject(number, forKey: "number")
                retrieveAccessTokenFromServer(login, completion: { (success,error) in
                    dispatch_async(dispatch_get_main_queue(), {
                        if success {
                            self.performSegueWithIdentifier("tokenValid", sender: self)
                        } else {
                            print(error)
                        }
                    })
                })
            }
        }
        return false
    }
    
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.numberTextField.resignFirstResponder()
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.destinationViewController is ViewController {
            let destination = segue.destinationViewController as! ViewController
            destination.twilioAccessToken = self.token
            destination.number = self.login
        }
    }


}