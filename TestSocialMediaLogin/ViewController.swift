//
//  ViewController.swift
//  TestSocialMediaLogin
//
//  Created by Ashish Keshan on 2/4/18.
//  Copyright © 2018 Ashish Keshan. All rights reserved.
//

import UIKit
import FBSDKLoginKit
import FacebookLogin
import SwiftyJSON
import GoogleSignIn
import Google

class ViewController: UIViewController, LoginButtonDelegate, GIDSignInUIDelegate, GIDSignInDelegate {

    @IBOutlet weak var numLikesLabel: UILabel!
    @IBOutlet weak var numFollowersLabel: UILabel!
    let webV:UIWebView = UIWebView(frame: UIScreen.main.bounds)
    var numFollowers:Int64 = 0
    var maxLikes = -1
    var dict : [String : AnyObject]!
    var pageID:String = ""
    var fbpageID:String = ""
    var igAccountID:Int = 0
    var youtubeAccountID: String = ""
    var accessToken:String = ""
    
    @IBAction func instagramLoginPressed(_ sender: Any) {
        self.view.addSubview(webV)
        let authURL = String(format:"%@?client_id=%@&redirect_uri=%@&response_type=token&scope=%@&DEBUG=True", arguments: [API.INSTAGRAM_AUTHURL,API.INSTAGRAM_CLIENT_ID,API.INSTAGRAM_REDIRECT_URI, API.INSTAGRAM_SCOPE])
        let urlRequest = URLRequest.init(url: URL.init(string: authURL)!)
        webV.loadRequest(urlRequest)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        webV.delegate = self;
        let loginButton = LoginButton(readPermissions: [ .publicProfile, .pagesShowList])
        loginButton.center = view.center
        loginButton.delegate = self
        //adding it to view
        view.addSubview(loginButton)
        if (FBSDKAccessToken.current()) != nil{
            getFBUserData()
        }
        
        var error: NSError?
        GGLContext.sharedInstance().configureWithError(&error)
        
        if error != nil {
            print(error)
            return
        }
        
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().delegate = self
        let scope: NSString = "https://www.googleapis.com/auth/youtube.readonly"
        let currentScopes: NSArray = GIDSignIn.sharedInstance().scopes! as NSArray
        GIDSignIn.sharedInstance().scopes = currentScopes.adding(scope)
        
        let googleSignInButton = GIDSignInButton()
        googleSignInButton.center = CGPoint(x: view.center.x, y: view.center.y + 200)
        view.addSubview(googleSignInButton)
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if error != nil {
            print(error ?? "some error")
            return
        }
        print("USER ID: ", user.userID)
        self.accessToken = user.authentication.accessToken
        print(accessToken)
        getYoutubeData()
    }
    
    func getYoutubeData(){
        let url = URL(string: "https://www.googleapis.com/youtube/v3/channels?part=statistics&mine=true&access_token=\(self.accessToken)")
        URLSession.shared.dataTask(with: (url as URL?)!, completionHandler: {(data, response, error) -> Void in
            if let jsonObj = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? NSDictionary {
                print(jsonObj!)
                let itemsJson = jsonObj!["items"] as? [[String:AnyObject]]
                self.youtubeAccountID = itemsJson![0]["id"]! as! String
                let statsDict = itemsJson![0]["statistics"] as! [String:AnyObject]
                print("subscriber count: ", statsDict["subscriberCount"]!.int32Value)
                print("youtube account ID: ", self.youtubeAccountID)
            }
        }).resume()
    }
    
    func loginButtonDidCompleteLogin(_ loginButton: LoginButton, result: LoginResult) {
        print("logged in")
        self.getFBUserData()
    }
    
    func loginButtonDidLogOut(_ loginButton: LoginButton) {
        print("logged out")
    }
    
    //function is fetching the user data
    func getFBUserData(){
        if((FBSDKAccessToken.current()) != nil){
            FBSDKGraphRequest(graphPath: "me", parameters: ["fields": "accounts"]).start(completionHandler: { (connection, result, error) -> Void in
                if (error == nil){
                    let json = JSON.init(result ?? "")
                    print(json)
                    let accounts = json["accounts"].dictionaryValue
                    let data = accounts["data"]!.arrayValue
                    for account in data {
                        self.pageID = account["id"].stringValue
                        self.getFBPageLikes(pageID: self.pageID)
                    }
                }
            })
        }
    }
    
    func getFBPageLikes(pageID: String) {
        var request: FBSDKGraphRequest?
        let accessToken = FBSDKAccessToken.current().tokenString
        let params = ["access_token" : accessToken ?? ""]
        request = FBSDKGraphRequest.init(graphPath: "/\(self.pageID)?fields=fan_count", parameters: params, httpMethod: "GET")
        request?.start(completionHandler: { (_, result, _) in
            let json = JSON.init(result ?? "") // Converting result into JSON using SwiftyJSON
            print(json)
            let numLikes = json["fan_count"].intValue
            if (numLikes > self.maxLikes) {
                self.maxLikes = numLikes
                self.fbpageID = pageID
            }
            DispatchQueue.main.async {
                self.numLikesLabel.text = String(self.maxLikes)
            }
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func checkRequestForCallbackURL(request: URLRequest) -> Bool {
        let requestURLString = (request.url?.absoluteString)! as String
        if requestURLString.hasPrefix(API.INSTAGRAM_REDIRECT_URI) {
            let range: Range<String.Index> = requestURLString.range(of: "#access_token=")!
            handleAuth(authToken: requestURLString.substring(from: range.upperBound))
            return false;
        }
        return true
    }
    func handleAuth(authToken: String) {
        print("Instagram authentication token ==", authToken)
        webV.removeFromSuperview()
        getJsonFromUrl(token: String(authToken))
    }
    
    func getJsonFromUrl(token: String){
        //creating a NSURL
        let url = NSURL(string: "https://api.instagram.com/v1/users/self/?access_token=\(token)")
        //fetching the data from the url
        URLSession.shared.dataTask(with: (url as URL?)!, completionHandler: {(data, response, error) -> Void in
            if let jsonObj = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? NSDictionary {
                //printing the json in console
                print(jsonObj!.value(forKey: "data")!)
                if let userJson = jsonObj!["data"] as? [String : AnyObject] {
                    self.igAccountID = (userJson["id"]?.intValue)!
                    print("instagram account ID: ", self.igAccountID)
                    if let countsJson = userJson["counts"] as? [String:AnyObject] {
                        if let followed_by = countsJson["followed_by"] as? Int64 {
                            print("Followers: ", followed_by)
                            DispatchQueue.main.async {
                                self.numFollowersLabel.text = String(followed_by)
                            }
                        }
                    }
                }
            }
        }).resume()
    }
}

extension ViewController: UIWebViewDelegate{
    func webView(_ webView: UIWebView, shouldStartLoadWith request:URLRequest, navigationType: UIWebViewNavigationType) -> Bool{
        return checkRequestForCallbackURL(request: request)
    }
}

