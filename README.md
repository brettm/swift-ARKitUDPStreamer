# ARKitUDPStreamer

iOS/iPadOS application that captures ARKit body tracking data and transmits it via OSC/UDP for real-time virtual puppetry.

## Overview

ARKitUDPStreamer uses ARKit's body tracking capabilities to capture skeletal joint data and streams it over UDP using the OSC protocol. The app handles coordinate system conversion from ARKit to Unreal Engine format, enabling real-time puppeteering of virtual creatures.

## Requirements

- iOS/iPadOS device with A12 Bionic chip or newer
- Device must support ARKit body tracking
- Swift/ARKit/OSCKit

## Installation

1. Clone the repository
2. Open the project in Xcode
3. Add OSCKit dependency via Swift Package Manager:
   - In Xcode: File → Add Package Dependencies
   - Enter OSCKit repository URL
   - Add to project
4. Build and run on supported device

## Configuration

- **Default Target IP**: 192.168.4.22
- **Default Port**: 123456
- **Protocol**: OSC over UDP

**Important**: You need to change the IP address in the app to match your machine running Unreal Engine.

## Current Features

- ARKit body tracking capture
- Coordinate system conversion (ARKit → Unreal)
- Real-time OSC message transmission
- Low-latency UDP streaming
- Skeletal joint transform data

## Future Plans

- Configurable IP address and port in UI
- Adjustable joint selection and filtering
- Network connection status indicator
- Recording and playback capabilities

## Usage

1. Ensure your iOS device and Unreal machine are on the same network
2. Update the target IP address to your machine's IP
3. Launch the app
4. Position yourself in view of the camera with full body visible
5. Body tracking data will automatically stream to Unreal Engine

## Companion Project

This app works in conjunction with the **Puppetry** Unreal Engine project for visualisation and the planned separate MIDI server for musical output.

