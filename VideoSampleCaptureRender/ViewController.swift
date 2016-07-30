//
//  ViewController.swift
//  VideoSampleCaptureRender
//
//  Created by Piyush Tank on 3/10/16.
//  Copyright © 2016 Twilio. All rights reserved.
//

import UIKit

import TwilioConversationsClient
import TwilioCommon.TwilioAccessManager
import SwiftyJSON

let JID = "PN43bf6a7cd78d4af7d6ac05284dd06216"

class ViewController: UIViewController, UITextFieldDelegate {
    
    // Twilio Access Token - Generate a demo Access Token at https://www.twilio.com/user/account/video/dev-tools/testing-tools
    var twilioAccessToken = ""
    
    // Storyboard's outlets
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var statusMessage: UILabel!
    @IBOutlet weak var inviteeTextField: UITextField!
    @IBOutlet weak var disconnectButton: UIButton!
    
    //Calling view
    @IBOutlet weak var callingView: UIView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var cancelLabel: UILabel!
    @IBOutlet weak var receivingImage: UIImageView!
    @IBOutlet weak var nameReceivingLabel: UILabel!
    
    //Receiving a call
    @IBOutlet weak var receivingView: UIView!
    @IBOutlet weak var rejectButton: UIButton!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var callingImage: UIImageView!
    
    @IBOutlet weak var nameCallingLabel: UILabel!
    @IBOutlet weak var turnCameraButton: UIButton!
    var front = true
    
    @IBOutlet weak var muteButton: UIButton!
    
    // Key Twilio ConversationsClient SDK objects
    var client: TwilioConversationsClient?
    var localMedia: TWCLocalMedia?
    var camera: TWCCameraCapturer?
    var conversation: TWCConversation?
    var outgoingInvite: TWCOutgoingInvite?
    var remoteVideoRenderer: TWCVideoViewRenderer?
    
    // Video containers used to display local camera track and remote Participant's camera track
    var localVideoContainer: UIView?
    var remoteVideoContainer: UIView?
    
    var lastInvite : TWCIncomingInvite?
    
    // If set to true, the remote video renderer (of type TWCVideoViewRenderer) will not automatically handle rotation of the remote party's video track. Instead, you should respond to the 'renderer:orientiationDidChange:' method in your TWCVideoViewRendererDelegate.
    let applicationHandlesRemoteVideoFrameRotation = false
    
    // ConversationsClient status - used to dynamically update our UI
    enum ConversationsClientStatus: Int {
        case None = 0
        case FailedToListen
        case Listening
        case Connecting
        case Connected
    }
    
    enum Corner: Int {
        case TopRight = 0
        case TopLeft
        case BottomRight
        case BottomLeft
    }
    
    var currentCorner = Corner.BottomRight
    
    // Default status to None
    var clientStatus: ConversationsClientStatus = .None
    
    func updateClientStatus(status: ConversationsClientStatus, animated: Bool) {
        self.clientStatus = status
        
        // Update UI elements when the ConversationsClient status changes
        switch self.clientStatus {
        case .None:
            break
        case .FailedToListen:
            //spinner.stopAnimating()
            self.statusMessage.hidden = false
            self.statusMessage.text = "Failure while attempting to listen for Conversation Invites."
            self.view.bringSubviewToFront(self.statusMessage)
            self.localVideoContainer?.hidden = true
            print("Faled to listen")
        case .Listening:
            spinner.stopAnimating()
            self.disconnectButton.hidden = true
            self.inviteeTextField.hidden = false
            self.turnCameraButton.hidden = false
            self.muteButton.hidden = true
            self.localVideoContainer?.hidden = false
            self.statusMessage.hidden = true
            print("Listening")
        case .Connecting:
            //self.spinner.startAnimating()
            self.inviteeTextField.hidden = true
            self.turnCameraButton.hidden = true
            self.muteButton.hidden = true
            self.localVideoContainer?.hidden = false
            print("Connecting")
        case .Connected:
            //self.spinner.stopAnimating()
            self.inviteeTextField.hidden = true
            //self.turnCameraButton.hidden = false
            //self.muteButton.hidden = false
            self.resetTimer()
            self.view.endEditing(true)
            //self.disconnectButton.hidden = false
            self.localVideoContainer?.hidden = false
            print("Connected")
        }
        // Update UI Layout, optionally animated
        self.view.setNeedsLayout()
        if animated {
            UIView.animateWithDuration(0.2) { () -> Void in
                self.view.layoutIfNeeded()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // self.view is loaded from Main.storyboard, however the local and remote video containers are created programmatically
        
        //Setup and hide receiving call view
        self.receivingView.hidden = true
        self.acceptButton.layer.cornerRadius = 35
        self.rejectButton.layer.cornerRadius = 35
        self.receivingImage.layer.cornerRadius = self.receivingImage.frame.height/2
        self.receivingImage.contentMode = UIViewContentMode.ScaleAspectFit
        
        //Setup and hide calling view
        self.callingView.hidden = true
        self.cancelButton.layer.cornerRadius = 35
        self.callingImage.layer.cornerRadius = self.callingImage.frame.height/2
        self.callingImage.contentMode = UIViewContentMode.ScaleAspectFit
        
        // Video containers
        self.remoteVideoContainer = UIView(frame: self.view.frame)
        self.view.addSubview(self.remoteVideoContainer!)
        self.remoteVideoContainer!.backgroundColor = UIColor.blackColor()
        self.localVideoContainer = UIView(frame: self.view.frame)
        self.view.addSubview(self.localVideoContainer!)
        self.localVideoContainer!.backgroundColor = UIColor.blackColor()
        self.localVideoContainer!.hidden = true
        self.localVideoContainer!.userInteractionEnabled = false
        
        // Entry text field for the identity to invite to a Conversation (the invitee)
        inviteeTextField.alpha = 0.9
        inviteeTextField.hidden = true
        inviteeTextField.autocorrectionType = .No
        inviteeTextField.returnKeyType = .Send
        self.view.bringSubviewToFront(self.inviteeTextField)
        self.inviteeTextField.delegate = self
        
        //setup turning camera
        self.turnCameraButton.layer.cornerRadius = 35
        self.view.bringSubviewToFront(self.turnCameraButton)
        self.turnCameraButton.layer.borderWidth = 3
        self.turnCameraButton.layer.borderColor = UIColor.whiteColor().CGColor
        self.turnCameraButton.hidden = true
        
        //setup muting
        self.muteButton.layer.cornerRadius = 35
        self.view.bringSubviewToFront(self.muteButton)
        self.muteButton.layer.borderWidth = 3
        self.muteButton.layer.borderColor = UIColor.whiteColor().CGColor
        self.muteButton.hidden = true
        
        // Spinner - shown when attempting to listen for Invites and when sending an Invite
        self.view.addSubview(spinner)
        spinner.startAnimating()
        self.view.bringSubviewToFront(self.spinner)
        
        // Status message - used to display errors
        statusMessage.hidden = true
        
        // Disconnect button
        self.view.bringSubviewToFront(self.disconnectButton)
        self.disconnectButton.hidden = true
        self.disconnectButton.layer.cornerRadius = 35

        TwilioConversationsClient.setLogLevel(.Warning)
        self.listenForInvites()
        self.setupLocalMedia()
        
        timer = NSTimer.scheduledTimerWithTimeInterval(5, target: self, selector: #selector(ViewController.idleTimeExceeded), userInfo: nil, repeats: false)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // Layout video containers
        self.layoutLocalVideoContainer()
        self.layoutRemoteVideoContainer()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    var touchx: CGFloat?
    var touchy: CGFloat?
    
    // Hide the keyboard whenever a touch is detected on this view
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        super.touchesBegan(touches, withEvent: event)
        self.view.endEditing(true)
        
        let touch = touches.first
        let location = touch?.locationInView(self.localVideoContainer)
        if location!.x >= 0 && location!.y >= 0 && location!.x < self.localVideoContainer?.frame.width && location!.y < self.localVideoContainer?.frame.height && self.conversation != nil {
            let touchPlace = touch?.locationInView(self.view)
            let currentCenter = self.localVideoContainer?.center
            touchx = touchPlace!.x - currentCenter!.x
            touchy = touchPlace!.y - currentCenter!.y
            print("touches began")
            self.view.bringSubviewToFront(self.localVideoContainer!)
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let touch = touches.first
        let location = touch?.locationInView(self.localVideoContainer)
        if location!.x >= 0 && location!.y >= 0 && location!.x < self.localVideoContainer?.frame.width && location!.y < self.localVideoContainer?.frame.height {
            let whereIsNow = touch?.locationInView(self.view)
            if conversation != nil {
                self.localVideoContainer?.center = CGPoint(x: whereIsNow!.x - touchx!, y: whereIsNow!.y - touchy!)
            }
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if conversation != nil {
            let location = self.localVideoContainer?.center
            if location!.x > self.view.frame.width/2 {
                if location!.y > self.view.frame.height/2 {
                    self.currentCorner = .BottomRight
                } else {
                    self.currentCorner = .TopRight
                }
            } else {
                if location!.y > self.view.frame.height/2 {
                    self.currentCorner = .BottomLeft
                } else {
                    self.currentCorner = .TopLeft
                }
            }
            self.resetTimer()
            UIView.animateWithDuration(0.3, animations: {
                // CONSIDER ADDING ANIMATION HERE?
                if location!.x > self.view.frame.width/2 {
                    if location!.y > self.view.frame.height/2 {
                        if self.buttonsShowed {
                            self.localVideoContainer!.center = CGPointMake(self.view.frame.width - self.localVideoContainer!.frame.width/2 - 10, self.view.frame.height - self.localVideoContainer!.frame.height/2 - 10 - 100)
                        } else {
                            self.localVideoContainer!.center = CGPointMake(self.view.frame.width - self.localVideoContainer!.frame.width/2 - 10, self.view.frame.height - self.localVideoContainer!.frame.height/2 - 10)
                        }
                    } else {
                        self.localVideoContainer!.center = CGPointMake(self.view.frame.width - self.localVideoContainer!.frame.width/2 - 10, self.localVideoContainer!.frame.height/2 + 10)
                    }
                } else {
                    if location!.y > self.view.frame.height/2 {
                        if self.buttonsShowed {
                            self.localVideoContainer!.center = CGPointMake(self.localVideoContainer!.frame.width/2 + 10, self.view.frame.height - self.localVideoContainer!.frame.height/2 - 10 - 100)
                        } else {
                            self.localVideoContainer!.center = CGPointMake(self.localVideoContainer!.frame.width/2 + 10, self.view.frame.height - self.localVideoContainer!.frame.height/2 - 10)
                        }
                    } else {
                        self.localVideoContainer!.center = CGPointMake(self.localVideoContainer!.frame.width/2 + 10, self.localVideoContainer!.frame.height/2 + 10)
                    }
                }
            })
        }
    }
    
    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        if conversation != nil {
            let location = self.localVideoContainer?.center
            if location!.x > self.view.frame.width/2 {
                if location!.y > self.view.frame.height/2 {
                    self.currentCorner = .BottomRight
                } else {
                    self.currentCorner = .TopRight
                }
            } else {
                if location!.y > self.view.frame.height/2 {
                    self.currentCorner = .BottomLeft
                } else {
                    self.currentCorner = .TopLeft
                }
            }
            self.resetTimer()
            UIView.animateWithDuration(0.3, animations: {
                // CONSIDER ADDING ANIMATION HERE?
                if location!.x > self.view.frame.width/2 {
                    if location!.y > self.view.frame.height/2 {
                        if self.buttonsShowed {
                            self.localVideoContainer!.center = CGPointMake(self.view.frame.width - self.localVideoContainer!.frame.width/2 - 10, self.view.frame.height - self.localVideoContainer!.frame.height/2 - 10 - 100)
                        } else {
                            self.localVideoContainer!.center = CGPointMake(self.view.frame.width - self.localVideoContainer!.frame.width/2 - 10, self.view.frame.height - self.localVideoContainer!.frame.height/2 - 10)
                        }
                    } else {
                        self.localVideoContainer!.center = CGPointMake(self.view.frame.width - self.localVideoContainer!.frame.width/2 - 10, self.localVideoContainer!.frame.height/2 + 10)
                    }
                } else {
                    if location!.y > self.view.frame.height/2 {
                        if self.buttonsShowed {
                            self.localVideoContainer!.center = CGPointMake(self.localVideoContainer!.frame.width/2 + 10, self.view.frame.height - self.localVideoContainer!.frame.height/2 - 10 - 100)
                        } else {
                            self.localVideoContainer!.center = CGPointMake(self.localVideoContainer!.frame.width/2 + 10, self.view.frame.height - self.localVideoContainer!.frame.height/2 - 10)
                        }
                    } else {
                        self.localVideoContainer!.center = CGPointMake(self.localVideoContainer!.frame.width/2 + 10, self.localVideoContainer!.frame.height/2 + 10)
                    }
                }
            })
        }
    }
    
    var buttonsShowed = true
    var timer : NSTimer?
    
    //idle checking
    func resetTimer() {
        print("reset timer")
        print(self.buttonsShowed)
        if let mytimer = timer {
            mytimer.invalidate()
            self.timer = NSTimer.scheduledTimerWithTimeInterval(5, target: self, selector: #selector(ViewController.idleTimeExceeded), userInfo: nil, repeats: false)
        }
        if !self.buttonsShowed {
            self.buttonsShowed = true
            self.turnCameraButton.hidden = false
            self.muteButton.hidden = false
            self.disconnectButton.hidden = false
            UIView.animateWithDuration(0.3, animations: {
                //if !self.buttonsShowed {
                    self.turnCameraButton.center = CGPoint(x: self.turnCameraButton.center.x, y: self.view.frame.height - self.turnCameraButton.frame.height/2 - 30)
                    self.muteButton.center = CGPoint(x: self.muteButton.center.x, y: self.view.frame.height - self.muteButton.frame.height/2 - 30)
                    self.disconnectButton.center = CGPoint(x: self.disconnectButton.center.x, y: self.view.frame.height - self.disconnectButton.frame.height/2 - 30)
                    if self.currentCorner == .BottomLeft || self.currentCorner == .BottomRight {
                        self.localVideoContainer!.center = CGPoint(x: self.localVideoContainer!.center.x, y: self.view.frame.height - self.localVideoContainer!.frame.height/2 - 110)
                    }
                //}
            }) { (success) in
                //self.buttonsShowed = true
            }
        }
    }
    
    
    
    func idleTimeExceeded() {
        print("idle exceeded")
        if self.conversation == nil {
            return
        }
        UIView.animateWithDuration(0.3, animations: {
            //if self.buttonsShowed {
            self.turnCameraButton.center = CGPoint(x: self.turnCameraButton.center.x, y: self.view.frame.height - self.turnCameraButton.frame.height/2 + 70)
            self.muteButton.center = CGPoint(x: self.muteButton.center.x, y: self.view.frame.height - self.muteButton.frame.height/2 + 70)
            self.disconnectButton.center = CGPoint(x: self.disconnectButton.center.x, y: self.view.frame.height - self.disconnectButton.frame.height/2 + 70)
            if self.currentCorner == .BottomLeft || self.currentCorner == .BottomRight {
                self.localVideoContainer!.center = CGPoint(x: self.localVideoContainer!.center.x, y: self.view.frame.height - self.localVideoContainer!.frame.height/2 - 10)
            }
            //}
            }) { (success) in
                //self.buttonsShowed = false
                self.turnCameraButton.hidden = true
                self.muteButton.hidden = true
                self.disconnectButton.hidden = true
        }
        self.buttonsShowed = false
    }
    
    // Disconnect button
    @IBAction func disconnectButtonClicked (sender : AnyObject) {
        if conversation != nil {
            conversation?.disconnect()
            self.localVideoContainer!.userInteractionEnabled = false
        }
    }
    
    var muted = false
    
    @IBAction func muteClicked(sender: AnyObject) {
        self.muted = !self.muted
        setMuteImage()
        self.localMedia!.microphoneMuted = self.muted
    }
    
    func setMuteImage() {
        if self.muted {
            self.muteButton.setImage(UIImage(named: "microphoneMutedIcon"), forState: UIControlState.Normal)
        } else {
            self.muteButton.setImage(UIImage(named: "microphoneIcon"), forState: UIControlState.Normal)
        }
    }
    
    func layoutLocalVideoContainer() {
        var rect:CGRect! = CGRectZero
        
        // If connected to a Conversation, display a small representaiton of the local video track in the bottom right corner
        if clientStatus == .Connected {
            rect!.size = UIDeviceOrientationIsLandscape(UIDevice.currentDevice().orientation) ? CGSizeMake(160, 90) : CGSizeMake(90, 160)
            if self.currentCorner == .BottomRight {
                if buttonsShowed {
                    rect!.origin = CGPointMake(self.view.frame.width - rect!.width - 10, self.view.frame.height - rect!.height - 10 - 100)
                } else {
                    rect!.origin = CGPointMake(self.view.frame.width - rect!.width - 10, self.view.frame.height - rect!.height - 10)
                }
            } else if self.currentCorner == .TopRight {
                rect!.origin = CGPointMake(self.view.frame.width - rect!.width - 10, 10)
            } else if self.currentCorner == .BottomLeft {
                if buttonsShowed {
                    rect!.origin = CGPointMake(10, self.view.frame.height - rect!.height - 10 - 100)
                } else {
                    rect!.origin = CGPointMake(10, self.view.frame.height - rect!.height - 10)
                }
            } else {
                rect!.origin = CGPointMake(10, 10)
            }
        } else {
            // If not yet connected to a Conversation (e.g. Camera preview), display the local video feed as full screen
            rect = self.view.frame
        }
        self.localVideoContainer!.frame = rect
        //self.localVideoContainer?.alpha = clientStatus == .Connecting ? 0.25 : 1.0
    }
    
    func layoutRemoteVideoContainer() {
        if clientStatus == .Connected {
            // When connected to a Conversation, display the remote video feed as full screen.
            if applicationHandlesRemoteVideoFrameRotation {
                // This block demonstrates how to manually handle remote video track rotation
                let rotated = TWCVideoOrientationIsRotated(self.remoteVideoRenderer!.videoFrameOrientation)
                let transform = TWCVideoOrientationMakeTransform(self.remoteVideoRenderer!.videoFrameOrientation)
                self.remoteVideoRenderer!.view.transform = transform
                self.remoteVideoContainer!.bounds = (rotated == true) ?
                    CGRectMake(0, 0, self.view.frame.height, self.view.frame.width) :
                    CGRectMake(0, 0, self.view.frame.width,  self.view.frame.height)
            } else {
                // In this block, because the TWCVideoViewRenderer is handling remote video track rotation automatically, we simply set the remote video container size to full screen
                self.remoteVideoContainer!.bounds = CGRectMake(0,0,self.view.frame.width, self.view.frame.height)
            }
            self.remoteVideoContainer!.center = self.view.center
            self.remoteVideoRenderer!.view.bounds = self.remoteVideoContainer!.frame
        } else {
            // If not connected to a Conversation, there is no remote video to display
            self.remoteVideoContainer!.frame = CGRectZero
        }
    }
    
    func listenForInvites() {
        assert(self.twilioAccessToken != "TWILIO_ACCESS_TOKEN", "Set the value of the placeholder property 'twilioAccessToken' to a valid Twilio Access Token.")
        print("access manager")
        let accessManager = TwilioAccessManager(token: self.twilioAccessToken, delegate:nil)
        print(accessManager.identity())
        print("client")
        self.client = TwilioConversationsClient(accessManager: accessManager!, delegate: self);
        self.client!.listen()
    }
    
    func setupLocalMedia() {
        // LocalMedia represents the collection of tracks that we are sending to other Participants from our ConversationsClient
        self.localMedia = TWCLocalMedia()
        // Currently, the microphone is automatically captured and an audio track is added to our LocalMedia. However, we should manually create a video track using the device's camera and the TWCCameraCapturer class
        if Platform.isSimulator == false {
            createCapturer()
            setupLocalPreview()
        }
    }
    @IBAction func turnCamera(sender: AnyObject) {
        self.front = !self.front
        //createCapturer()
        self.camera!.flipCamera()
        
        
    }
    
    var lastVideoTrack : TWCLocalVideoTrack?
    
    func createCapturer() {
        if front {
            self.camera = TWCCameraCapturer(delegate: self, source: .FrontCamera)
        } else {
            self.camera = TWCCameraCapturer(delegate: self, source: .BackCamera)
        }
        let videoCaptureConstraints = self.videoCaptureConstraints()
        let videoTrack = TWCLocalVideoTrack(capturer: self.camera!, constraints: videoCaptureConstraints)
        if let lastTrack = self.lastVideoTrack {
            self.localMedia!.removeTrack(lastTrack)
        }
        self.lastVideoTrack = videoTrack
        if self.localMedia!.addTrack(videoTrack) == false {
            print("Error: Failed to create a video track using the local camera.")
        }
    }
    
    func videoCaptureConstraints () -> TWCVideoConstraints {
        /* Video constraints provide a mechanism to capture a video track using a preferred frame size and/or frame rate.
        
         Here, we set the captured frame size to 960x540. Check TWCCameraCapturer.h for other valid video constraints values. 
         
         960x540 video will fill modern iPhone screens. However, older 32-bit devices (A5, A6 based) will have trouble capturing, and encoding video at HD quality. For these devices we constrain the capturer to produce 480x360 video at 15fps. */
        
        if (Platform.isLowPerformanceDevice) {
            return TWCVideoConstraints.init(block: { (constraints) in
                constraints.maxSize = TWCVideoConstraintsSize480x360
                constraints.minSize = TWCVideoConstraintsSize480x360
                constraints.maxFrameRate = 15
                constraints.minFrameRate = 15
            })
        } else {
            return TWCVideoConstraints.init(block: { (constraints) in
                constraints.maxSize = TWCVideoConstraintsSize960x540
                constraints.minSize = TWCVideoConstraintsSize960x540
                constraints.maxFrameRate = TWCVideoFrameRateConstraintsNone
                constraints.minFrameRate = TWCVideoFrameRateConstraintsNone
            })
        }
    }
    
    func setupLocalPreview() {
        self.camera!.startPreview()
        
        // Preview our local camera track in the local video container
        self.localVideoContainer!.addSubview((self.camera!.previewView)!)
        self.camera!.previewView!.frame = self.localVideoContainer!.bounds
    }
    
    func destroyLocalMedia() {
        self.camera?.previewView?.removeFromSuperview()
        self.camera = nil
        self.localMedia = nil
    }
    
    func resetClientStatus() {
        // Reset the local media
        destroyLocalMedia()
        setupLocalMedia()
        
        // Reset the client ui status
        updateClientStatus(self.client!.listening ? .Listening : .FailedToListen, animated: true)
    }
    
    // Respond to "Send" button on keyboard
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.view.endEditing(true)
        inviteParticipant(textField.text!)
        return false
    }
    
    func inviteParticipant(inviteeIdentity: String) {
        if inviteeIdentity.isEmpty == false {
            self.nameCallingLabel.text = inviteeIdentity
            self.outgoingInvite =
                self.client?.inviteToConversation(inviteeIdentity, localMedia:self.localMedia!) { conversation, err in
                    self.outgoingInviteCompletionHandler(conversation, err: err)
            }
            self.updateClientStatus(.Connecting, animated: false)
        }
        self.callingView.hidden = false
        self.inviteeTextField.hidden = true
        self.view.bringSubviewToFront(self.callingView)
        
        print("inviteParticipant")
    }
    
    @IBAction func cancelClicked(sender: AnyObject) {
        self.outgoingInvite?.cancel()
        self.callingView.hidden = true
    }
    
    func outgoingInviteCompletionHandler(conversation: TWCConversation?, err: NSError?) {
        if err == nil {
            // The invitee accepted our Invite
            self.conversation = conversation
            self.conversation?.delegate = self
            self.localVideoContainer!.userInteractionEnabled = true
            self.disconnectButton.hidden = true
            self.cancelLabel.hidden = true
            UIView.animateWithDuration(0.5, animations: {
                let currentCenter = self.cancelButton.center
                self.cancelButton.center = CGPoint(x: currentCenter.x, y: currentCenter.y+20)
            }) { (success) in
                self.callingView.hidden = true
                self.cancelLabel.hidden = false
                self.disconnectButton.hidden = false
                self.muteButton.hidden = false
                self.turnCameraButton.hidden = false
                let currentCenter = self.cancelButton.center
                self.cancelButton.center = CGPoint(x: currentCenter.x, y: currentCenter.y-20)
            }
        } else if err!.code == 107 { // rejected
            print(err?.code)
            // The invitee rejected our Invite or the Invite was not acknowledged
            let alertController = UIAlertController(title: "Oops!", message: "Your call got rejected!", preferredStyle: .Alert)
            let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in  }
            alertController.addAction(OKAction)
            self.presentViewController(alertController, animated: true) { }
            
            // Destroy the old local media and set up new local media.
            self.resetClientStatus()
            self.view.bringSubviewToFront(self.inviteeTextField)
            self.callingView.hidden = true
        }  else if err!.code != 110 { // not canceled yourself
            print(err?.code)
            // The invitee rejected our Invite or the Invite was not acknowledged
            let alertController = UIAlertController(title: "Oops!", message: "We could not connect to the remote client.", preferredStyle: .Alert)
            let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in  }
            alertController.addAction(OKAction)
            self.presentViewController(alertController, animated: true) { }
            
            // Destroy the old local media and set up new local media.
            self.resetClientStatus()
            self.view.bringSubviewToFront(self.inviteeTextField)
            self.callingView.hidden = true
        } else {
            self.resetClientStatus()
            self.view.bringSubviewToFront(self.inviteeTextField)
            self.callingView.hidden = true
        }
    }
}

// MARK: TwilioConversationsClientDelegate
extension ViewController: TwilioConversationsClientDelegate {
    func conversationsClient(conversationsClient: TwilioConversationsClient,
        didFailToStartListeningWithError error: NSError) {
        
        // Do not interrupt the on going conversation UI. Client status will
        // changed to .FailedToListen when conversation ends.
        if (conversation == nil) {
            self.updateClientStatus(.FailedToListen, animated: false)
        }
    }
    
    func conversationsClientDidStartListeningForInvites(conversationsClient: TwilioConversationsClient) {
        // Successfully listening for Invites

        // Do not interrupt the on going conversation UI. Client status will
        // changed to .Listening when conversation ends.
        if (conversation == nil) {
            self.updateClientStatus(.Listening, animated: true)
        }
    }
    
    func conversationsClientDidStopListeningForInvites(conversationsClient: TwilioConversationsClient, error: NSError?) {
        // Do not interrupt the on going conversation UI. Client status will
        // changed to .Listening when conversation ends.
        if (conversation == nil) {
            self.updateClientStatus(.FailedToListen, animated: true)
        }
    }
    
    // Automatically accept any incoming Invite
    func conversationsClient(conversationsClient: TwilioConversationsClient,
        didReceiveInvite invite: TWCIncomingInvite) {
        //TUTAJ EKRAN GDZIE BĘDZIE ŻE DZWONI
        print(invite.from)
        self.nameReceivingLabel.text = invite.from
        self.receivingView.hidden = false
        self.inviteeTextField.hidden = true
        self.muteButton.hidden = true
        self.turnCameraButton.hidden = true
        self.view.bringSubviewToFront(self.receivingView)
        self.lastInvite = invite
            /*
            let alertController = UIAlertController(title: "Incoming Invite!", message: "Invite from \(invite.from)", preferredStyle: .Alert)
            let acceptAction = UIAlertAction(title: "Accept", style: .Default) { (action) in
                // Accept the incoming Invite with pre-configured LocalMedia
                self.updateClientStatus(.Connecting, animated: false)
                invite.acceptWithLocalMedia(self.localMedia!, completion: { (conversation, err) -> Void in
                    if err == nil {
                        self.conversation = conversation
                        conversation!.delegate = self
                    } else {
                        print("Error: Unable to connect to accepted Conversation")
                        
                        // Destroy the old local media and set up new local media.
                        self.resetClientStatus()
                    }
                })
            }
            alertController.addAction(acceptAction)
            let rejectAction = UIAlertAction(title: "Reject", style: .Cancel) { (action) in
                invite.reject()
            }
            alertController.addAction(rejectAction)
            self.presentViewController(alertController, animated: true) { }
            */
    }
    
    @IBAction func rejectClicked(sender: AnyObject) {
        self.lastInvite?.reject()
        self.receivingView.hidden = true
        self.inviteeTextField.hidden = false
        self.turnCameraButton.hidden = false
        self.muteButton.hidden = true
    }
    
    @IBAction func acceptClicked(sender: AnyObject) {
        self.updateClientStatus(.Connecting, animated: false)
        self.lastInvite?.acceptWithLocalMedia(self.localMedia!, completion: { (conversation, err) -> Void in
            if err == nil {
                self.conversation = conversation
                conversation!.delegate = self
                self.localVideoContainer!.userInteractionEnabled = true
            } else {
                print("Error: Unable to connect to accepted Conversation")
                
                // Destroy the old local media and set up new local media.
                self.resetClientStatus()
            }
        })
        self.receivingView.hidden = true
        //self.buttonsShowed = true
        self.turnCameraButton.center = CGPoint(x: self.turnCameraButton.center.x, y: self.view.frame.height - self.turnCameraButton.frame.height/2 + 70)
        self.muteButton.center = CGPoint(x: self.muteButton.center.x, y: self.view.frame.height - self.muteButton.frame.height/2 + 70)
        self.disconnectButton.center = CGPoint(x: self.disconnectButton.center.x, y: self.view.frame.height - self.disconnectButton.frame.height/2 + 70)
        self.buttonsShowed = false
        /*UIView.animateWithDuration(0.3, animations: {
            //if !self.buttonsShowed {
            self.turnCameraButton.center = CGPoint(x: self.turnCameraButton.center.x, y: self.view.frame.height - self.turnCameraButton.frame.height/2 - 30)
            self.muteButton.center = CGPoint(x: self.muteButton.center.x, y: self.view.frame.height - self.muteButton.frame.height/2 - 30)
            self.disconnectButton.center = CGPoint(x: self.disconnectButton.center.x, y: self.view.frame.height - self.disconnectButton.frame.height/2 - 30)
            //}
        }) { (success) in
            //self.buttonsShowed = true
        }*/
    }
    
    func conversationsClient(conversationsClient: TwilioConversationsClient, inviteDidCancel invite: TWCIncomingInvite) {
        self.receivingView.hidden = true
        self.inviteeTextField.hidden = false
        self.turnCameraButton.hidden = false
        self.muteButton.hidden = true
        self.view.bringSubviewToFront(self.inviteeTextField)
        self.view.bringSubviewToFront(self.muteButton)
        self.view.bringSubviewToFront(self.turnCameraButton)
    }
    
    func conversationEnded(conversation: TWCConversation, error: NSError) {
        //do some stuff
    }
}

// MARK: TWCConversationDelegate
extension ViewController: TWCConversationDelegate {
    func conversation(conversation: TWCConversation, didConnectParticipant participant: TWCParticipant) {
        // Remote Participant connected
        participant.delegate = self
    }
    
    func conversationEnded(conversation: TWCConversation) {
        self.conversation = nil
        self.resetClientStatus()
        self.receivingView.hidden = true
        self.view.bringSubviewToFront(self.inviteeTextField)
        self.view.bringSubviewToFront(self.muteButton)
        self.view.bringSubviewToFront(self.turnCameraButton)
        
        let alertController = UIAlertController(title: "Oops!", message: "The call ended!", preferredStyle: .Alert)
        let OKAction = UIAlertAction(title: "OK", style: .Default) { (action) in  }
        alertController.addAction(OKAction)
        self.presentViewController(alertController, animated: true) { }
    }
}

// MARK: TWCParticipantDelegate
extension ViewController: TWCParticipantDelegate {
    func participant(participant: TWCParticipant, addedVideoTrack videoTrack: TWCVideoTrack) {
        // Remote Participant added a video track. Render it onto the remote video track container.
        self.remoteVideoRenderer = TWCVideoViewRenderer(delegate: self)
        videoTrack.addRenderer(self.remoteVideoRenderer!)
        self.remoteVideoRenderer!.view.bounds = self.remoteVideoContainer!.frame
        
        self.remoteVideoContainer!.addSubview(self.remoteVideoRenderer!.view)
        
        // Animate the remote video track onto the screen.
        self.updateClientStatus(.Connected, animated: true)
    }
    
    func participant(participant: TWCParticipant, removedVideoTrack videoTrack: TWCVideoTrack) {
        // Remote Participant removed their video track
        self.remoteVideoRenderer!.view.removeFromSuperview()
    }
}

// MARK: TWCLocalMediaDelegate
extension ViewController: TWCLocalMediaDelegate {
    func localMedia(media: TWCLocalMedia, didFailToAddVideoTrack videoTrack: TWCVideoTrack, error: NSError) {
        // Called when there is a failure attempting to add a local video track to LocalMedia. In this application, it is likely to be caused when capturing a video track from the device camera using invalid video constraints.
        print("Error: failed to add a local video track to LocalMedia.")
    }
}

// MARK: TWCCameraCapturerDelegate
extension ViewController : TWCCameraCapturerDelegate {
    func cameraCapturerPreviewDidStart(capturer: TWCCameraCapturer) {
        if (self.client!.listening) {
            self.localVideoContainer!.hidden = false
        }
    }
    
    func cameraCapturer(capturer: TWCCameraCapturer, didStartWithSource source: TWCVideoCaptureSource) {
        self.statusMessage.hidden = true
    }
    
    func cameraCapturer(capturer: TWCCameraCapturer, didStopRunningWithError error: NSError) {
        // Failed to capture video from the local device camera
        self.statusMessage.hidden = false
        self.statusMessage.text = "Error: failed to capture video from your device's camera."
    }
    
    /* The local video track representing your captured camera will be automatically disabled (paused) when there is an interruption - for example, when the app is backgrounded.
    If you do not wish to pause the local video track when the TWCCameraCapturer is interrupted, you should also implement the 'cameraCapturerWasInterrupted' delegate method. */
}

// MARK: TWCVideoViewRendererDelegate
extension ViewController: TWCVideoViewRendererDelegate {
    func rendererDidReceiveVideoData(renderer: TWCVideoViewRenderer) {
        // Called when the first frame of video is received on the remote Participant's video track
        self.view.setNeedsLayout()
    }
    
    func renderer(renderer: TWCVideoViewRenderer, dimensionsDidChange dimensions: CMVideoDimensions) {
        // Called when the remote Participant's video track changes dimensions
        self.view.setNeedsLayout()
    }
    
    func renderer(renderer: TWCVideoViewRenderer, orientationDidChange orientation: TWCVideoOrientation) {
        // Called when the remote Participant's video track is rotated. Only ever called if 'rendererShouldRotateContent' returns true.
        self.view.setNeedsLayout()
        UIView.animateWithDuration(0.2) { () -> Void in
            self.view.layoutIfNeeded()
        }
    }
    
    func rendererShouldRotateContent(renderer: TWCVideoViewRenderer) -> Bool {
        return !applicationHandlesRemoteVideoFrameRotation
    }
}
