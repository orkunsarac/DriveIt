import grpc
from google.protobuf.empty_pb2 import Empty

import emulator_controller_pb2 as pb2
import emulator_controller_pb2_grpc as pb2_grpc


channel = grpc.insecure_channel("127.0.0.1:8556")
try:
    grpc.channel_ready_future(channel).result(timeout=5)
    stub = pb2_grpc.EmulatorControllerStub(channel)
    request = pb2.GpsState(
        passiveUpdate=False,
        latitude=40.7128,
        longitude=29.9270,
        altitude=50.0,
        speed=0.0,
        bearing=0.0,
        satellites=8,
    )
    stub.setGps(request, timeout=5)
    print("setGps OK")
    print(stub.getGps(Empty(), timeout=5))
finally:
    channel.close()
