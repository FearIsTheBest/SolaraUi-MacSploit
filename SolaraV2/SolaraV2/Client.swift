//
//  Client.swift
//  MacSploit
//
//  Created by Nexus Pancakes on 13/11/2022.
//

import Foundation
import Network
import SwiftUI

class Client : ObservableObject {
    let host: NWEndpoint.Host
    let port: NWEndpoint.Port
    var connection: NWConnection
    let dispatchQueue = DispatchQueue(label: "IPC Socket")
    var scriptWaiting: String? = nil
    
    @Published var autoExecute: Bool = true;
    @Published var autoInject: Bool = true;
    @Published var multiInstance: Bool = true;
    @Published var executeInstances: Bool = false;
    
    @Published var allowTeleports: Bool = true;
    @Published var placeRestrictions: Bool = true;
    @Published var dumpScripts: Bool = false;
    @Published var logHttp: Bool = true;
    @Published var workInk: Bool = false;
    
    @Published var fileSystem: Bool = true;
    @Published var debugLibrary: Bool = true;
    @Published var httpTraffic: Bool = true;
    @Published var settingsControl: Bool = true;
    
    @Published var norbUnc: Bool = true;
    @Published var resumeHandle: Bool = true;
    
    @Published var connectionState = "Offline";
    @Published var connectionColor = Color.red;
    
    struct raw_send {
        var type: UInt8;
        var size: Int = 0;
    };
    
    enum ipc_types {
        case IPC_SCRIPT,
             IPC_SETTING,
             IPC_PING;
    };
    
    init(port: UInt16) {
        self.host = NWEndpoint.Host("127.0.0.1")
        self.port = NWEndpoint.Port(rawValue: port)!
        print("CLIENT INIT TCP " + String(port))
        
        let tcp = NWProtocolTCP.Options.init()
        let params = NWParameters.init(tls: nil, tcp: tcp)
        tcp.noDelay = true
        
        self.connection = NWConnection(to: NWEndpoint.hostPort(host: self.host, port: self.port), using: params)
        connection.stateUpdateHandler = stateChange(to:)
        connection.start(queue: dispatchQueue)
        load_settings();
    }
    
    func stateChange(to state: NWConnection.State) {
        switch state {
        case .waiting(_):
            connectionState = "Offline";
            connectionColor = Color.red;
            print("Waiting...")
        case .failed(_):
            connectionState = "Offline";
            connectionColor = Color.red;
            print("Connection Closed. Restarting...")
            self.connection.stateUpdateHandler = nil
            self.connection.cancel()
            
            let tcp = NWProtocolTCP.Options.init()
            let params = NWParameters.init(tls: nil, tcp: tcp)
            tcp.noDelay = true
            
            self.connection = NWConnection(to: NWEndpoint.hostPort(host: self.host, port: self.port), using: params)
            self.connection.stateUpdateHandler = self.stateChange(to:)
            self.connection.start(queue: self.dispatchQueue)
        case .ready:
            connectionState = "Online";
            connectionColor = Color.green;
            print("Connection Established!")
            if self.scriptWaiting != nil {
                print("Executing Previous Script.")
                send(data: self.scriptWaiting ?? "");
            }
        default:
            print("Failed to establish connection. Trying again in 2 seconds...")
            dispatchQueue.asyncAfter(deadline: .now() + 2) {
                let state: NWConnection.State = self.connection.state
                if state != .ready {
                    self.connection.restart()
                }
            }
        }
    }
    
    func ping(completion: @escaping (_ success: Bool) -> Void) {
        var send_data: raw_send = raw_send(type: 2, size: 0);
        connection.send(content: NSData(bytes: &send_data, length: MemoryLayout.size(ofValue: send_data)), completion: .contentProcessed({ error in
            if error != nil {
                print(error.unsafelyUnwrapped)
            }
        }))
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 2, completion: { data, ctx, _, err in
            if err != nil || data == nil {
                completion(false)
                return
            }
            
            let resp = data?.withUnsafeBytes({(rawPtr: UnsafeRawBufferPointer) in
                return rawPtr.load(as: UInt8.self)
            })
            
            if resp == 0x10 {
                completion(true);
            }
        })
    }
    
    func reconnect(port: UInt16) {
        let rport = NWEndpoint.Port(rawValue: port)!
        self.connection.cancel()
        
        let tcp = NWProtocolTCP.Options.init()
        let params = NWParameters.init(tls: nil, tcp: tcp)
        tcp.noDelay = true
        
        self.connection = NWConnection(to: NWEndpoint.hostPort(host: self.host, port: rport), using: params)
        self.connection.stateUpdateHandler = self.stateChange(to:)
        self.connection.start(queue: self.dispatchQueue)
    }
    
    func send(data: String) {
        self.scriptWaiting = data
        ping(completion: { success in
            if !success {
                print("Ping Failed.")
                return
            }
            
            self.scriptWaiting = nil
            var send_data: raw_send = raw_send(type: 0, size: data.lengthOfBytes(using: .utf8) + 1);
            var raw_data = Data(bytes: &send_data, count: MemoryLayout.size(ofValue: send_data));
            raw_data.append(data.data(using: .utf8).unsafelyUnwrapped); raw_data.append(0);
            print(send_data.size);
            
            self.connection.send(content: raw_data, completion: .contentProcessed({ error in
                if error != nil {
                    self.connection.stateUpdateHandler = nil
                    self.connection.cancel()
                    
                    print("Connection Error. Restarting...")
                    let tcp = NWProtocolTCP.Options.init()
                    
                    let params = NWParameters.init(tls: nil, tcp: tcp)
                    tcp.noDelay = true
                    
                    self.connection = NWConnection(to: NWEndpoint.hostPort(host: self.host, port: self.port), using: params)
                    self.connection.stateUpdateHandler = self.stateChange(to:)
                    self.connection.start(queue: self.dispatchQueue)
                }
            }))
        })
    }
    
    func handle_setting(data: String) {
        let data = data.components(separatedBy: " ");
        if data.count < 2 { return; }
        
        let value: Bool = data[1] == "true" ? true : false;
        let key: String = data[0];
        
        if key == "autoExecute" {
            autoExecute = value;
        } else if key == "autoInject" {
            autoInject = value;
        } else if key == "multiInstance" {
            multiInstance = value;
        } else if key == "executeInstances" {
            executeInstances = value;
        } else if key == "allowTeleports" {
            allowTeleports = value;
        } else if key == "placeRestrictions" {
            placeRestrictions = value;
        } else if key == "dumpScripts" {
            dumpScripts = value;
        } else if key == "logHttp" {
            logHttp = value;
        } else if key == "workInk" {
            workInk = value;
        } else if key == "fileSystem" {
            fileSystem = value;
        } else if key == "debugLibrary" {
            debugLibrary = value;
        } else if key == "httpTraffic" {
            httpTraffic = value;
        } else if key == "settingsControl" {
            settingsControl = value;
        } else {
            print("Unhandled Setting!");
        }
    }
    
    func load_settings() {
        let fileManager = FileManager.default;
        let homePath = fileManager.homeDirectoryForCurrentUser;
        let documentsPath = homePath.appendingPathComponent("Downloads");
        let fileUrl = documentsPath.appendingPathComponent("ms-settings");
        var settingsData: String = "";
        
        if fileManager.fileExists(atPath: fileUrl.path) {
            do { settingsData = try String(contentsOfFile: fileUrl.path); } catch let err {
                print("Failed to Read: \(err)");
                return;
            }
        }
        
        let settings = settingsData.components(separatedBy: "\n");
        settings.forEach(handle_setting);
        print("Loaded Settings.")
    }
    
    func setting(key: String, value: Bool) {
        let data: String = "\(key) \(value)";
        print("Saving Setting...")
        
        let fileManager = FileManager.default;
        let homePath = fileManager.homeDirectoryForCurrentUser;
        let documentsPath = homePath.appendingPathComponent("Downloads");
        let fileUrl = documentsPath.appendingPathComponent("ms-settings");
        var settingsData: String = "";
        
        if fileManager.fileExists(atPath: fileUrl.path) {
            do { settingsData = try String(contentsOfFile: fileUrl.path); } catch let err {
                print("Failed to Read: \(err)");
                return;
            }
        }
        
        let currentSettings = settingsData.components(separatedBy: "\n");
        var replaced: Bool = false;
        
        currentSettings.forEach({ setting in
            if setting.starts(with: key) {
                settingsData = settingsData.replacingOccurrences(of: setting, with: data);
                print("Changed Setting Data.");
                replaced = true;
            }
        })
        
        if !replaced {
            settingsData.append("\(data)\n");
            print("Appended New Data.");
        }
        
        do {
            try settingsData.write(to: fileUrl, atomically: true, encoding: .utf8);
        } catch let err {
            print("Failed to Resave Data: \(err)");
            return;
        }
        
        print("Saved Setting Data. Performing Realtime Update...");
        
        ping(completion: { success in
            if !success {
                print("Ping Failed.")
                return
            }
            
            self.scriptWaiting = nil
            var send_data: raw_send = raw_send(type: 1, size: data.count + 1);
            var raw_data = Data(bytes: &send_data, count: MemoryLayout.size(ofValue: send_data));
            raw_data.append(data.data(using: .utf8).unsafelyUnwrapped); raw_data.append(0);
            
            self.connection.send(content: raw_data, completion: .contentProcessed({ error in
                if error != nil {
                    self.connection.stateUpdateHandler = nil
                    self.connection.cancel()
                    
                    print("Connection Error. Restarting...")
                    let tcp = NWProtocolTCP.Options.init()
                    
                    let params = NWParameters.init(tls: nil, tcp: tcp)
                    tcp.noDelay = true
                    
                    self.connection = NWConnection(to: NWEndpoint.hostPort(host: self.host, port: self.port), using: params)
                    self.connection.stateUpdateHandler = self.stateChange(to:)
                    self.connection.start(queue: self.dispatchQueue)
                }
            }))
            
            print("Successful Setting Save Event.");
        })
    }
}
