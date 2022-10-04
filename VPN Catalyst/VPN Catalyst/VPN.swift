//
//  VPN.swift
//  RealmDemo2
//
//  Created by Uday Babariya on 14/10/20.
//

import Foundation


//
//  VPN.swift
//  WhiteHaxDemo
//
//  Created by Vishwas Singh on 14/04/21.
//

import Foundation
import NetworkExtension
//import UIKit

//MARK:- Variables for keychain access
enum VPNKeychain {

    /// Returns a persistent reference for a generic password keychain item, adding it to
    /// (or updating it in) the keychain if necessary.
    ///
    /// This delegates the work to two helper routines depending on whether the item already
    /// exists in the keychain or not.
    ///
    /// - Parameters:
    ///   - service: The service name for the item.
    ///   - account: The account for the item.
    ///   - password: The desired password.
    /// - Returns: A persistent reference to the item.
    /// - Throws: Any error returned by the Security framework.

    static func persistentReferenceFor(service: String, account: String, password: Data) throws -> Data {
        var copyResult: CFTypeRef? = nil
        let err = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnPersistentRef: true,
            kSecReturnData: true
        ] as NSDictionary, &copyResult)
        switch err {
            case errSecSuccess:
                return try self.persistentReferenceByUpdating(copyResult: copyResult!, service: service, account: account, password: password)
            case errSecItemNotFound:
                return try self.persistentReferenceByAdding(service: service, account:account, password: password)
            default:
                try throwOSStatus(err)
                // `throwOSStatus(_:)` only returns in the `errSecSuccess` case.  We know we're
                // not in that case but the compiler can't figure that out, alas.
                fatalError()
        }
    }

    /// Returns a persistent reference for a generic password keychain item by updating it
    /// in the keychain if necessary.
    ///
    /// - Parameters:
    ///   - copyResult: The result from the `SecItemCopyMatching` done by `persistentReferenceFor(service:account:password:)`.
    ///   - service: The service name for the item.
    ///   - account: The account for the item.
    ///   - password: The desired password.
    /// - Returns: A persistent reference to the item.
    /// - Throws: Any error returned by the Security framework.

    private static func persistentReferenceByUpdating(copyResult: CFTypeRef, service: String, account: String, password: Data) throws -> Data {
        let copyResult = copyResult as! [String:Any]
        let persistentRef = copyResult[kSecValuePersistentRef as String] as! NSData as Data
        let currentPassword = copyResult[kSecValueData as String] as! NSData as Data
        if password != currentPassword {
            let err = SecItemUpdate([
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ] as NSDictionary, [
                kSecValueData: password
            ] as NSDictionary)
            try throwOSStatus(err)
        }
        return persistentRef
    }

    /// Returns a persistent reference for a generic password keychain item by adding it to
    /// the keychain.
    ///
    /// - Parameters:
    ///   - service: The service name for the item.
    ///   - account: The account for the item.
    ///   - password: The desired password.
    /// - Returns: A persistent reference to the item.
    /// - Throws: Any error returned by the Security framework.

    private static func persistentReferenceByAdding(service: String, account: String, password: Data) throws -> Data {
        var addResult: CFTypeRef? = nil
        let err = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: password,
            kSecReturnPersistentRef: true,
        ] as NSDictionary, &addResult)
        try throwOSStatus(err)
        return addResult! as! NSData as Data
    }

    /// Throws an error if a Security framework call has failed.
    ///
    /// - Parameter err: The error to check.

    private static func throwOSStatus(_ err: OSStatus) throws {
        guard err == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil)
        }
    }
}
public class VPN: NSObject {
    public static let shared = VPN()
    
    private var userName = ""
    private var password = ""
    private var serverIP = ""
    private var secret = ""
    private let vpnManager = NEVPNManager.shared()
    private var connectHandler: ((Bool) -> Void)?
    private var statusHandler: ((Int) -> Void)?
    
    public var connectedDate: Date?{
       return vpnManager.connection.connectedDate
    }
    
    public var status: Int{
        return vpnManager.connection.status.rawValue
    }

    
    override init() {
        super.init()
        self.vpnManager.loadFromPreferences { (error) in
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.vPNStatusDidChange(_:)), name: NSNotification.Name.NEVPNStatusDidChange, object: nil)
    }
    
    public class func initialise(){
        let _ = VPN.shared
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func loadPreferences(userName: String, password: String, serverIP: String, secret: String, completionHandler: ((Bool, String?) -> Void)?) {
        self.userName = userName
        self.password = password
        self.serverIP = serverIP
        self.secret = secret
        
        self.vpnManager.loadFromPreferences {[weak self] (error) in
            guard let `self` = self else {
                completionHandler?(false, nil)
                return
            }
            
            if let tempError = error{
                completionHandler?(false, tempError.localizedDescription)
            }else{
                let vpnProtocol = NEVPNProtocolIPSec()
                vpnProtocol.username = self.userName
                vpnProtocol.serverAddress = self.serverIP
                vpnProtocol.includeAllNetworks = true
                vpnProtocol.authenticationMethod = NEVPNIKEAuthenticationMethod.sharedSecret
                if let secretRef = try? VPNKeychain.persistentReferenceFor(service: "VPN_SECRET", account: "VPN_SECRET2", password: self.secret.data(using: .utf8)!){
                    vpnProtocol.sharedSecretReference = secretRef
                }
                
                if let passRef = try? VPNKeychain.persistentReferenceFor(service: "VPN_PASSWORD", account: "VPN_PASSWORD2", password: self.password.data(using: .utf8)!){
                    vpnProtocol.passwordReference = passRef
                }
                
                vpnProtocol.useExtendedAuthentication = true
                vpnProtocol.disconnectOnSleep = false
                self.vpnManager.protocolConfiguration = vpnProtocol
                self.vpnManager.localizedDescription = "Whitehax VPN"
                self.vpnManager.isEnabled = true
                self.vpnManager.saveToPreferences {(error) in
                    if let tempError = error{
                        completionHandler?(false, tempError.localizedDescription)
                    }else{
                        completionHandler?(true, nil)
                    }
                }
            }
        }
    }
    
    public func connectVPN(completionHandler: ((Bool) -> Void)?) {
//        print("connectVPN", vpnManager.connection.status.rawValue)
//        if vpnManager.connection.status == .invalid {
//            print("invalid")
//            self.loadPreferences(userName: "vpnuser", password: "YWszdh787dLKPY9P", serverIP: "52.41.74.147", secret: "S7DJenmEvvLWUVxt3yPF") { [weak self] vpnConfigDone, string in
//                if vpnConfigDone {
//                    print("vpnConfigDone", vpnConfigDone)
//                    self?.connectVPN { status in
//                        print("status", status)
//                    }
//                }
//            }
//            return
//        }
        if vpnManager.connection.status == .connecting || vpnManager.connection.status == .connected  { return }
        
        self.connectHandler = completionHandler
        do {
            try self.vpnManager.connection.startVPNTunnel()
        } catch {
            print("connectVPN failed: \(error.localizedDescription)")
        }
    }
    
    public func disconnectVPN() ->Void {
        vpnManager.connection.stopVPNTunnel()
    }
    
    public func startVPNStatusNotifier(completionHandler: ((Int) -> Void)?){
        self.statusHandler = completionHandler
    }
    
    
    
    @objc private func vPNStatusDidChange(_ notification: Notification?) {

        print("VPN Status changed:")
        let status = self.vpnManager.connection.status
        switch status {
        case .connecting:
            print("Connecting...")
            break
        case .connected:
            print("Connected")
            UserDefaults.standard.setValue(Date(), forKey: "lastVPNConnectedDate")
            UserDefaults.standard.synchronize()
            
            self.connectHandler?(true)
            break
        case .disconnecting:
            print("Disconnecting...")
            break
        case .disconnected:
            print("Disconnected")
            UserDefaults.standard.setValue(Date(), forKey: "lastVPNDisconnectedDate")
            UserDefaults.standard.synchronize()
            
            break
        case .invalid:
            print("Invalid")
            break
        case .reasserting:
            print("Reasserting...")
            break
        @unknown default:
            print("default...")
        }
        
        self.statusHandler?(status.rawValue)
    }
    
    
    private func sendLocalNotification() {
        
    }
    
}

public extension VPN {
    func profilerConfiguration() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("vpnManager"), object: nil, queue: OperationQueue.main) { [weak self] val in
            guard let vpnStatus = val.userInfo?["status"] as? Bool else { return }
            print("vpnStatus", vpnStatus)
            guard let `self` = self else { return }
            print("NSNotification.Name(vpnManager)")
            self.loadPreferences(userName: "vpnuser", password: "YWszdh787dLKPY9P", serverIP: "52.41.74.147", secret: "S7DJenmEvvLWUVxt3yPF") { [weak self] vpnConfigDone, string in
                if vpnConfigDone {
                    print("vpnConfigDone", vpnConfigDone)
                    if vpnStatus {
                        self?.connectVPN { status in
                            print("status", status)
                        }
                    } else {
                        self?.disconnectVPN()
                    }
                }
            }
        }
    }
}
