import sys

import grpc
from google.protobuf.empty_pb2 import Empty

import emulator_controller_pb2 as pb2
import emulator_controller_pb2_grpc as pb2_grpc


def main() -> int:
    channel = grpc.insecure_channel("127.0.0.1:8556")
    try:
        grpc.channel_ready_future(channel).result(timeout=5)
        state = pb2_grpc.EmulatorControllerStub(channel).getGps(Empty(), timeout=5)
        print(state)
        return 0
    except Exception as exc:  # Report the server/auth error without bypassing it.
        print(f"{type(exc).__name__}: {exc}")
        return 1
    finally:
        channel.close()


if __name__ == "__main__":
    sys.exit(main())
