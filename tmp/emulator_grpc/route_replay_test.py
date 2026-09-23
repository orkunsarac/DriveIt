import time

import grpc
from google.protobuf.empty_pb2 import Empty

import emulator_controller_pb2 as pb2
import emulator_controller_pb2_grpc as pb2_grpc


HOST = "127.0.0.1:8556"
LATITUDE = 40.7128
START_LONGITUDE = 29.9270
POINT_COUNT = 20
LONGITUDE_STEP = 0.00010


def main() -> None:
    channel = grpc.insecure_channel(HOST)
    try:
        grpc.channel_ready_future(channel).result(timeout=5)
        stub = pb2_grpc.EmulatorControllerStub(channel)
        before = stub.getGps(Empty(), timeout=5)
        print(f"before={before}", flush=True)
        started = time.monotonic()
        for index in range(POINT_COUNT):
            request = pb2.GpsState(
                passiveUpdate=False,
                latitude=LATITUDE,
                longitude=START_LONGITUDE + index * LONGITUDE_STEP,
                altitude=50.0,
                speed=8.0,
                bearing=90.0,
                satellites=8,
            )
            stub.setGps(request, timeout=5)
            print(f"sent={index + 1} longitude={request.longitude:.5f}", flush=True)
            if index + 1 < POINT_COUNT:
                time.sleep(1)
        elapsed = time.monotonic() - started
        after = stub.getGps(Empty(), timeout=5)
        print(f"elapsedSeconds={elapsed:.3f}", flush=True)
        print(f"after={after}", flush=True)
    finally:
        channel.close()


if __name__ == "__main__":
    main()
