import subprocess
import os
class Pack:
    def __init__(self):
        self.paths = [
            ("/home/aisuan/fd", "../zip/fd.tar.gz"),
            ("/home/aisuan/nccl", "../zip/nccl.tar.gz"),
            ("/home/aisuan/gpu-burn", "../zip/gpu-burn.tar.gz")
        ]
    def anypack(self):
        self.data={"gpu_burn":False,"fd":False,"nccl":False}
        a = self.is_gpu_burn()
        b = self.is_fd()
        c = self.is_nccl()
        self.data["gpu_burn"] = a
        self.data["fd"] = b
        self.data["nccl"] = c
        return self.data
    def unzip(self):
        for path in self.paths:
            print(path[0])
            if not os.path.exists(f"{path[0]}"):
                subprocess.Popen(f"tar -zxvf {os.path.join(os.path.dirname(__file__))}/{path[1]} -C /home/aisuan/", shell=True)
                print(f"pack {path[0]} to {path[1]}")
        return True
    def is_gpu_burn(self)-> bool:
        a =os.path.exists("/home/aisuan/gpu-burn")
        return a
    def is_fd(self)-> bool:
        a =os.path.exists("/home/aisuan/fd")
        return a
    def is_nccl(self)-> bool:
        a =os.path.exists("/home/aisuan/nccl")
        return a
if __name__ == "__main__":
    pack = Pack()
    print(pack.unzip())