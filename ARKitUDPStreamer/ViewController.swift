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
import OSCKitCore
import Foundation
import simd

// Local IP of the machine running OSC server here
//
let ip_host = "192.168.4.22"
//
// Ensure the OSC server is setup to listen on the correct port
//
let port: UInt16 = 12345
//
// Mirrors the transforms -X -> +X
//
let mirrored: Bool = false

struct JointTransform {
    var position: SIMD3<Float>
    var rotation: simd_quatf
    func display() {
        print("Rot - \(rotation.vector)\nPos - \(position)\n")
    }
}

struct BodyData {
    var joints: [String: JointTransform]
}

protocol OSCAddressComposer {
    func oscAddress(mirrored: Bool) -> String
}

enum Joint: String, CaseIterable, OSCAddressComposer {
    case leftHand = "left_hand_joint"
    case rightHand = "right_hand_joint"
    case leftElbow = "left_forearm_joint"
    case rightElbow = "right_forearm_joint"
    case leftShoulder = "left_shoulder_joint"
    case rightShoulder = "right_shoulder_joint"
    var mirrored: Joint {
        switch(self) {
        case .leftHand: .rightHand
        case .rightHand: .leftHand
        case .leftElbow: .rightElbow
        case .rightElbow: .leftElbow
        case .leftShoulder: .rightShoulder
        case .rightShoulder: .leftShoulder
        }
    }
    func mirrored(_ mirrored: Bool) -> Joint {
        return mirrored ? self.mirrored : self
    }
    static func joint(from name: String) -> Joint? {
        for jointName in Self.allCases {
            if name == jointName.rawValue { return jointName }
        }
        return nil
    }
    func oscAddress(mirrored: Bool) -> String {
        let prefix = "/joint/"
        let suffix = mirrored ? self.mirrored.rawValue : self.rawValue
        return prefix + suffix
    }
}

class ViewController: UIViewController, ARSCNViewDelegate {
    
    var arView: ARSCNView!
    var connection: NWConnection!
    
    var timer: Timer?
    var time: Float = 0.0
    
    var restPose: ARSkeleton3D?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        arView = ARSCNView(frame: view.bounds)
        arView.delegate = self
        arView.automaticallyUpdatesLighting = true
        view.addSubview(arView)
        
        updateSkeletonRestInfo()
        setupUDPConnection()
        
        if ARBodyTrackingConfiguration.isSupported {
            let config = ARBodyTrackingConfiguration()
            arView.session.run(config)
            sendMessage(OSCMessage("/arkit/status", values: ["Starting OSC server"]))
        } else {
            print("ARBodyTrackingConfiguration not supported on this device")
        }
    }
    
    private func updateSkeletonRestInfo() {
        restPose = ARSkeletonDefinition.defaultBody3D.neutralBodySkeleton3D!
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
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
    
    func sendBodyData(_ bodyAnchor: ARBodyAnchor) {

        for (jointIndex, modelTransform) in bodyAnchor.skeleton.jointModelTransforms.enumerated() {
        
            let name = ARSkeletonDefinition.defaultBody3D.jointNames[jointIndex]
            guard let jointName = Joint.joint(from: name) else { continue }
            
            let restTransform = restPose!.jointModelTransforms[jointIndex]

            let deltaRotationTransform = modelTransform * restTransform.inverse
            let rotation = simd_quatf(deltaRotationTransform)
            
            let deltaPositionTransform = modelTransform - restTransform
            let xPosition = mirrored ? -deltaPositionTransform.columns.3.x : deltaPositionTransform.columns.3.x
            let position = SIMD3<Float>(xPosition,
                                        deltaPositionTransform.columns.3.y,
                                        deltaPositionTransform.columns.3.z)
            
            let body = JointTransform(position: position, rotation: rotation)
            sendMessage(jointName.oscAddress(mirrored: mirrored), transform: body)
        }
    }
    
    func sendMessage(_ address: String, transform: JointTransform) {
        let values = [
            transform.position.x, transform.position.y, transform.position.z,
            transform.rotation.vector.x, transform.rotation.vector.y, transform.rotation.vector.z, transform.rotation.vector.w
        ]
        sendMessage(OSCMessage(address, values: values))
    }
    
    func sendMessage(_ message: OSCMessage) {
        try! connection.send(content: message.rawData(), completion: .contentProcessed({ error in
            if let error = error { print("UDP send error:", error) }
        }))
    }
}

