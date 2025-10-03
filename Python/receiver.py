import socket, json, time

UDP_IP = "0.0.0.0"
UDP_PORT = 12345

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((UDP_IP, UDP_PORT))

print(f"Listening on UDP {UDP_PORT}...")

last_ts = None

while True:
    data, _ = sock.recvfrom(65535)
    try:
        msg = json.loads(data.decode('utf-8'))
        ts = msg["timestamp"]
        joints = msg["joints"]

        # Compute delta from last packet
        if last_ts is not None:
            dt = ts - last_ts
            print(f"\nFrame Δt = {dt:.3f} sec ({1/dt:.1f} fps approx)")
        last_ts = ts

        # Print first few joints
        for joint, values in list(joints.items())[:3]:
            pos = values[0:3]
            rot = values[3:7]
            print(f"{joint}: pos={pos}, rot={rot}")

    except Exception as e:
        print("Decode error:", e)
