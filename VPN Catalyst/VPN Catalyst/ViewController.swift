//
//  ViewController.swift
//  VPN Catalyst
//
//  Created by Apple on 04/10/22.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var btnConnect: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        btnConnect.addTarget(self, action: #selector(btnConnectDisconnect), for: .touchUpInside)
        loadPreferences()
        
        VPN.shared.startVPNStatusNotifier {[weak self] (status) in
            
            self?.updateUI()
        }
        
        self.updateUI()

    }
    
    @objc func btnConnectDisconnect() {
        if buttonTitle == "Connecting" { return }
        if buttonTitle == "Connect" {
            VPN.shared.connectVPN { status in
                  print("status", status)
              }
        } else if buttonTitle == "Connected" || buttonTitle == "Disconnect" {
            VPN.shared.disconnectVPN()
        }
    }
    @objc func updateUI() {
        
        btnConnect.setTitle(buttonTitle, for: .normal)
    }


}

extension ViewController{
    var buttonTitle: String {
        if vpnStatus == "Disconnecting" || vpnStatus == "Disconnected" || vpnStatus == "Invalid" {
            return "Connect"
        } else if vpnStatus == "Connected" {
            return "Disconnect"
        }
        return vpnStatus
        
    }
    var vpnStatus: String{
        let status = VPN.shared.status //disconnected
        if status == 0{
            return "Invalid"
        }else if status == 1 {
            return "Disconnected"
        }else if status == 2 {
            return "Connecting"
        }else if status == 3 {
            return "Connected"
        }else if status == 4 {
            return "Reconnecting"
        }else if status == 5 {
            return "Disconnecting"
        }else{
            return "Disconnected"
        }
    }
    
    func loadPreferences() {
        VPN.shared.loadPreferences(userName: "vpnuser", password: "YWszdh787dLKPY9P", serverIP: "52.41.74.147", secret: "S7DJenmEvvLWUVxt3yPF") { [weak self] vpnConfigDone, string in
            if vpnConfigDone {
                print("vpnConfigDone", vpnConfigDone)
              
            }
        }
    }
    
    func connectVPN() {
        VPN.shared.connectVPN { (success) in
        }
    }
    
    func disconnectVPN() {
        VPN.shared.disconnectVPN()
    }
}
