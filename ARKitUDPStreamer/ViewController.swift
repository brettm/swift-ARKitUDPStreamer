//
//  ViewController.swift
//  ARKitUDPStreamer
//
//  Created by Brett Meader on 03/10/2025.
//

import UIKit
import ARKit
import SceneKit
import Network

//IP Address of the Receiver on the local network
let ip_host = "192.168.4.22"
let port = 12345

class ViewController: UIViewController, ARSCNViewDelegate {
    
    var arView: ARSCNView!
    var connection: NWConnection!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView = ARSCNView(frame: view.bounds)
        arView.delegate = self
        arView.automaticallyUpdatesLighting = true
        view.addSubview(arView)
        
        if ARBodyTrackingConfiguration.isSupported {
            let config = ARBodyTrackingConfiguration()
            arView.session.run(config)
        } else {
            print("ARBodyTrackingConfiguration not supported on this device")
        }
        
        setupUDPConnection()
    }

    override func viewDidLayoutSubviews() {
        self.arView.frame = self.view.bounds
    }
    
    func setupUDPConnection() {
        let host = NWEndpoint.Host(ip_host)
        let port = NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port))
        connection = NWConnection(host: host, port: port, using: .udp)
        connection.start(queue: .main)
    }
    
    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let bodyAnchor = anchor as? ARBodyAnchor {
            // Add a sphere for each joint
            for (index, _) in bodyAnchor.skeleton.jointModelTransforms.enumerated() {
                let sphere = SCNSphere(radius: 0.02)
                sphere.firstMaterial?.diffuse.contents = UIColor.red
                let jointNode = SCNNode(geometry: sphere)
                jointNode.name = "joint_\(index)"
                node.addChildNode(jointNode)
            }
        }
    }
        
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let bodyAnchor = anchor as? ARBodyAnchor {
            let transforms = bodyAnchor.skeleton.jointModelTransforms
            for (index, transform) in transforms.enumerated() {
                if let jointNode = node.childNode(withName: "joint_\(index)", recursively: false) {
                    jointNode.simdTransform = transform
                }
            }
            sendBodyData(bodyAnchor)
        }
    }
    
    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
            sendBodyData(bodyAnchor)
        }
    }
    
    func sendBodyData(_ bodyAnchor: ARBodyAnchor) {
        var jointDict: [String: [Float]] = [:]

        for (jointIndex, transform) in bodyAnchor.skeleton.jointModelTransforms.enumerated() {
            let name = ARSkeletonDefinition.defaultBody3D.jointNames[jointIndex]

            let position = SIMD3<Float>(transform.columns.3.x,
                                        transform.columns.3.y,
                                        transform.columns.3.z)

            let rotation = simd_quatf(transform)

            jointDict[name] = [
                position.x, position.y, position.z,
                rotation.vector.x, rotation.vector.y, rotation.vector.z, rotation.vector.w
            ]
        }

        // Wrap with timestamp
        let packet: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "joints": jointDict
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: packet) else { return }
        connection.send(content: jsonData, completion: .contentProcessed({ error in
            if let error = error {
                print("UDP send error:", error)
            }
        }))
    }
}

