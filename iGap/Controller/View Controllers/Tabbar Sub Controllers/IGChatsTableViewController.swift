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
import IGProtoBuff
import ProtocolBuffers
import RealmSwift
import RxRealm
import RxSwift
import RxCocoa
import MGSwipeTableCell
import MBProgressHUD

class IGChatsTableViewController: UITableViewController {
    
    var selectedRoomForSegue : IGRoom?
    var cellIdentifer = IGChatRoomListTableViewCell.cellReuseIdentifier()
    var rooms: Results<IGRoom>? = nil
    var notificationToken: NotificationToken?
    var hud = MBProgressHUD()
    var connectionStatus: IGAppManager.ConnectionStatus?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let predicate = NSPredicate(format: "typeRaw = %d AND isParticipant = 1", IGRoom.IGType.chat.rawValue)
        rooms = try! Realm().objects(IGRoom.self).filter(predicate).sorted(byKeyPath: "sortimgTimestamp", ascending: false)
        
        self.tableView.register(IGChatRoomListTableViewCell.nib(), forCellReuseIdentifier: IGChatRoomListTableViewCell.cellReuseIdentifier())
        
        self.tableView.backgroundColor = UIColor(red: 247.0/255.0, green: 247.0/255.0, blue: 247.0/255.0, alpha: 1.0)
        self.view.backgroundColor = UIColor(red: 247.0/255.0, green: 247.0/255.0, blue: 247.0/255.0, alpha: 1.0)
        self.tableView.tableHeaderView?.backgroundColor = UIColor(red: 247.0/255.0, green: 247.0/255.0, blue: 247.0/255.0, alpha: 1.0)
        
        self.notificationToken = rooms!.addNotificationBlock { (changes: RealmCollectionChange) in
            switch changes {
            case .initial:
                self.tableView.reloadData()
                self.setTabbarBadge()
                break
            case .update(_, let deletions, let insertions, let modifications):
                print("updating chats VC")
                // Query messages have changed, so apply them to the TableView
                self.tableView.beginUpdates()
                self.tableView.insertRows(at: insertions.map { IndexPath(row: $0, section: 0) }, with: .none)
                self.tableView.deleteRows(at: deletions.map { IndexPath(row: $0, section: 0) }, with: .none)
                self.tableView.reloadRows(at: modifications.map { IndexPath(row: $0, section: 0) }, with: .none)
                self.tableView.endUpdates()
                self.setTabbarBadge()
                break
            case .error(let err):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(err)")
                break
            }
        }
        if IGAppManager.sharedManager.isUserLoggiedIn() {
            self.fetchRoomList()
        } else {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(self.fetchRoomList),
                                                   name: NSNotification.Name(rawValue: kIGUserLoggedInNotificationName),
                                                   object: nil)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.isUserInteractionEnabled = true
        //self.setTabbarHidden(false, animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //MARK: Room List actions
    @objc private func fetchRoomList() {
        IGClientGetRoomListRequest.Generator.generate().success { (responseProtoMessage) in
            DispatchQueue.main.async {
                switch responseProtoMessage {
                case let response as IGPClientGetRoomListResponse:
                    IGClientGetRoomListRequest.Handler.interpret(response: response)
                default:
                    break;
                }
            }
            }.error({ (errorCode, waitTime) in
                
            }).send()
    }
    
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rooms!.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell: IGChatRoomListTableViewCell = self.tableView.dequeueReusableCell(withIdentifier: cellIdentifer) as! IGChatRoomListTableViewCell
        cell.setRoom(room: rooms![indexPath.row])
        
        cell.rightButtons =
            [MGSwipeButton(title: "Delete", backgroundColor: UIColor(red: 252.0/255.0, green: 23.0/255.0, blue: 22.0/255.0, alpha: 1), callback: { (sender: MGSwipeTableCell!) -> Bool in
                let room = cell.room!
                //let room = self.rooms![indexPath.row]
                let title = room.title != nil ? room.title! : "Delete"
                let alertC = UIAlertController(title: title, message: "What do you want to do?", preferredStyle: .actionSheet)
                let clear = UIAlertAction(title: "Clear History", style: .default, handler: { (action) in
                    switch room.type{
                    case .chat:
                        if self.connectionStatus == .waitingForNetwork || self.connectionStatus == .connecting {
                            let alert = UIAlertController(title: "Error", message: "No Network Connection", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                            alert.addAction(okAction)
                            self.present(alert, animated: true, completion: nil)
                            
                        } else {
                            self.clearChatMessageHistory(room: room)
                        }
                    case .group:
                        if self.connectionStatus == .waitingForNetwork || self.connectionStatus == .connecting {
                            let alert = UIAlertController(title: "Error", message: "No Network Connection", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                            alert.addAction(okAction)
                            self.present(alert, animated: true, completion: nil)
                            
                        } else {
                            self.clearGroupMessageHistory(room: room)
                        }
                    default:
                        break
                    }
                    
                })
                
                let remove = UIAlertAction(title: "Delete", style: .destructive, handler: { (action) in
                    switch room.type {
                    case .chat:
                        if self.connectionStatus == .waitingForNetwork || self.connectionStatus == .connecting {
                            let alert = UIAlertController(title: "Error", message: "No Network Connection", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                            alert.addAction(okAction)
                            self.present(alert, animated: true, completion: nil)
                            
                        } else {
                            self.deleteChat(room: room)
                        }
                    case .group:
                        if self.connectionStatus == .waitingForNetwork || self.connectionStatus == .connecting {
                            let alert = UIAlertController(title: "Error", message: "No Network Connection", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                            alert.addAction(okAction)
                            self.present(alert, animated: true, completion: nil)
                            
                        } else {
                            self.deleteGroup(room: room)
                        }
                    default:
                        break
                    }
                })
                
                
                
                let leave = UIAlertAction(title: "Leave", style: .destructive, handler: { (action) in
                    switch room.type {
                    case .chat:
                        break
                    case .group:
                        if self.connectionStatus == .waitingForNetwork || self.connectionStatus == .connecting {
                            let alert = UIAlertController(title: "Error", message: "No Network Connection", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                            alert.addAction(okAction)
                            self.present(alert, animated: true, completion: nil)
                            
                            
                        } else {
                            self.leaveGroup(room: room)
                        }
                    case .channel:
                        if self.connectionStatus == .waitingForNetwork || self.connectionStatus == .connecting {
                            let alert = UIAlertController(title: "Error", message: "No Network Connection", preferredStyle: .alert)
                            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                            alert.addAction(okAction)
                            self.present(alert, animated: true, completion: nil)
                            
                            
                        } else {
                            self.leaveChannel(room: room)
                        }
                    }
                })
                
                let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
                    
                })
                
                
                if room.type == .chat || room.type == .group {
                    alertC.addAction(clear)
                }
                if room.chatRoom != nil {
                    alertC.addAction(remove)
                } else {
                    if let groupRoom = room.groupRoom {
                        if groupRoom.role == .owner {
                            alertC.addAction(leave)
                            alertC.addAction(remove)
                        } else{
                            alertC.addAction(leave)
                        }
                    } else if let channel = room.channelRoom {
                        if channel.role == .owner {
                            alertC.addAction(remove)
                            alertC.addAction(leave)
                        } else{
                            alertC.addAction(leave)
                        }
                    }
                }
                
                
                alertC.addAction(cancel)
                
                self.present(alertC, animated: true, completion: {
                    
                })
                
                return true
            })]
        cell.rightSwipeSettings.transition = MGSwipeTransition.border
        
        
        cell.leftExpansion.buttonIndex = 0
        cell.leftExpansion.fillOnTrigger = true
        cell.leftExpansion.threshold = 2.0
        
        cell.rightExpansion.buttonIndex = 0
        cell.rightExpansion.fillOnTrigger = true
        cell.rightExpansion.threshold = 1.5
        
        
        cell.separatorInset = UIEdgeInsets(top: 0, left: 82.0, bottom: 0, right: 0)
        cell.layoutMargins = UIEdgeInsets.zero

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedRoomForSegue = rooms![indexPath.row]
        self.tableView.isUserInteractionEnabled = false
        performSegue(withIdentifier: "showRoomMessages", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "showRoomMessages") {
            let destination = segue.destination as! IGMessageViewController
            destination.room = selectedRoomForSegue
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 78.0
    }
    
    //MARK: - Tabbar badge
    func setTabbarBadge() {
//        var unreadCount = 0
//        rooms.forEach{unreadCount += Int($0.unreadCount)}
//        if unreadCount == 0 {
//            self.tabBarController?.tabBar.items?[1].badgeValue = nil
//        } else {
//            self.tabBarController?.tabBar.items?[1].badgeValue = "\(unreadCount)"
//        }
    }

}
extension IGChatsTableViewController {
    func clearChatMessageHistory(room: IGRoom) {
        self.hud = MBProgressHUD.showAdded(to: self.view.superview!, animated: true)
        self.hud.mode = .indeterminate
        IGChatClearMessageRequest.Generator.generate(room: room).success({ (protoResponse) in
            DispatchQueue.main.async {
                switch protoResponse {
                case let clearChatMessages as IGPChatClearMessageResponse:
                    IGChatClearMessageRequest.Handler.interpret(response: clearChatMessages)
                default:
                    break
                }
                self.hud.hide(animated: true)
            }
        }).error({ (errorCode , waitTime) in
            switch errorCode {
            case .timeout:
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Timeout", message: "Please try again later", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(okAction)
                    self.hud.hide(animated: true)
                    self.present(alert, animated: true, completion: nil)
                }
            default:
                DispatchQueue.main.async {
                    self.hud.hide(animated: true)
                }
                break
            }
            
        }).send()
    }
    
    func clearGroupMessageHistory(room: IGRoom) {
        self.hud = MBProgressHUD.showAdded(to: self.view.superview!, animated: true)
        self.hud.mode = .indeterminate
        IGGroupClearMessageRequest.Generator.generate(group: room).success({ (protoResponse) in
            DispatchQueue.main.async {
                switch protoResponse {
                case let deleteGroupMessageHistory as IGPGroupClearMessageResponse:
                    IGGroupClearMessageRequest.Handler.interpret(response: deleteGroupMessageHistory)
                default:
                    break
                }
                self.hud.hide(animated: true)
            }
        }).error({ (errorCode , waitTime) in
            DispatchQueue.main.async {
                switch errorCode {
                case .timeout:
                    let alert = UIAlertController(title: "Timeout", message: "Please try again later", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(okAction)
                    self.present(alert, animated: true, completion: nil)
                default:
                    break
                }
                self.hud.hide(animated: true)
            }
        }).send()
    }
    
    func deleteChat(room: IGRoom) {
        self.hud = MBProgressHUD.showAdded(to: self.view.superview!, animated: true)
        self.hud.mode = .indeterminate
        IGChatDeleteRequest.Generator.generate(room: room).success({ (protoResponse) in
            DispatchQueue.main.async {
                switch protoResponse {
                case let deleteChat as IGPChatDeleteResponse:
                    IGChatDeleteRequest.Handler.interpret(response: deleteChat)
                default:
                    break
                }
                self.hud.hide(animated: true)
            }
        }).error({ (errorCode , waitTime) in
            DispatchQueue.main.async {
                switch errorCode {
                case .timeout:
                    let alert = UIAlertController(title: "Timeout", message: "Please try again later", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(okAction)
                    self.hud.hide(animated: true)
                    self.present(alert, animated: true, completion: nil)
                default:
                    break
                }
                self.hud.hide(animated: true)
            }
            
        }).send()
    }
    
    func deleteGroup(room: IGRoom) {
        self.hud = MBProgressHUD.showAdded(to: self.view.superview!, animated: true)
        self.hud.mode = .indeterminate
        IGGroupDeleteRequest.Generator.generate(group: room).success({ (protoResponse) in
            DispatchQueue.main.async {
                switch protoResponse {
                case let deleteGroup as IGPGroupDeleteResponse:
                    IGGroupDeleteRequest.Handler.interpret(response: deleteGroup)
                default:
                    break
                }
                self.hud.hide(animated: true)
            }
        }).error({ (errorCode , waitTime) in
            DispatchQueue.main.async {
                switch errorCode {
                case .timeout:
                    let alert = UIAlertController(title: "Timeout", message: "Please try again later", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alert.addAction(okAction)
                    self.present(alert, animated: true, completion: nil)
                default:
                    break
                }
                self.hud.hide(animated: true)
            }
        }).send()
    }
    
    func leaveGroup(room: IGRoom) {
        self.hud = MBProgressHUD.showAdded(to: self.view.superview!, animated: true)
        self.hud.mode = .indeterminate
        IGGroupLeftRequest.Generator.generate(room: room).success{ (protoResponse) in
            DispatchQueue.main.async {
                switch protoResponse {
                case let response as IGPGroupLeftResponse:
                    IGGroupLeftRequest.Handler.interpret(response: response)
                default:
                    break
                }
                self.hud.hide(animated: true)
            }
            }.error { (errorCode, waitTime) in
                DispatchQueue.main.async {
                    switch errorCode {
                    case .timeout:
                        let alert = UIAlertController(title: "Timeout", message: "Please try again later", preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alert.addAction(okAction)
                        self.present(alert, animated: true, completion: nil)
                    default:
                        let alert = UIAlertController(title: "Error", message: "There was an error leaving this group.", preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alert.addAction(okAction)
                        self.present(alert, animated: true, completion: nil)
                    }
                    self.hud.hide(animated: true)
                }
            }.send()
    }
    
    func leaveChannel(room: IGRoom) {
        self.hud = MBProgressHUD.showAdded(to: self.view.superview!, animated: true)
        self.hud.mode = .indeterminate
        IGChannelLeftRequest.Generator.generate(room: room).success { (protoResponse) in
            DispatchQueue.main.async {
                switch protoResponse {
                case let response as IGPChannelLeftResponse:
                    IGChannelLeftRequest.Handler.interpret(response: response)
                default:
                    break
                }
                self.hud.hide(animated: true)
            }
            }.error { (errorCode, waitTime) in
                DispatchQueue.main.async {
                    switch errorCode {
                    case .timeout:
                        let alert = UIAlertController(title: "Timeout", message: "Please try again later", preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alert.addAction(okAction)
                        self.present(alert, animated: true, completion: nil)
                    default:
                        let alert = UIAlertController(title: "Error", message: "There was an error leaving this channel.", preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alert.addAction(okAction)
                        self.present(alert, animated: true, completion: nil)
                    }
                    self.hud.hide(animated: true)
                }
            }.send()
    }
}

