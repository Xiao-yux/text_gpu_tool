import os
# import pynvml
import asyncio
# import aiofiles

class Utilt:
    
    
    def __init__(self):
        pass

    def run_command(self, command):
        # 返回命令执行结果
        return os.popen(command).read()

    def get_gpu_count(self):
        # 返回GPU数量
        return os.popen('nvidia-smi --query-gpu=count --format=csv,noheader,nounits | head -n 1').read()
    def get_gpu_info(self):
        return os.popen(f'bash {os.path.join(os.path.dirname(__file__), "../bash/nvidia_info.sh")}').read()
    def get_sys_info(self):
        # 返回系统信息
        return os.popen(f'bash {os.path.join(os.path.dirname(__file__), "../bash/sys_info.sh")}').read()
    def get_eth_info(self):
        # 网卡硬盘信息
        return os.popen(f'bash {os.path.join(os.path.dirname(__file__), "../bash/CX_DISK_INFO.sh")}').read()
    
    def get_pwd(self):
        # 返回用户当前目录
        return os.popen('pwd').read().split('\n')[0]
    def get_serial_number(self):
        # 返回主板序列号
        return os.popen('dmidecode -s system-serial-number').read()
    
    def get_tar_cont(self):
        #返回目录下所有的tar.gz文件 ["1.tat.gz","2.tar.gz"]
        return os.popen(f'ls {os.path.join(os.path.dirname(__file__), "../zip/")}|grep tar.gz' ).read().split('\n') 
    
    def untar(self, tar_path):
        # 解压tar.gz文件
        return os.popen(f'tar -xzf {tar_path} -C {os.path.dirname(__file__)}')
    
    async def is_script_path(self) -> bool:
        # 异步检查目录是否存在,如果压测文件不存在就解压到当前目录
        tasks = []
        
        paths = [
            ("/home/aisuan/fd", "../zip/fd.tar.gz"),
            ("/home/aisuan/nccl", "../zip/nccl.tar.gz"),
            ("/home/aisuan/gpu-burn", "../zip/gpu-burn.tar.gz")
        ]
        
        paths = [
            ("/home/aisuan/fd", "../zip/fd.tar.gz"),
            ("/home/aisuan/nccl", "../zip/nccl.tar.gz"),
            ("/home/aisuan/gpu-burn", "../zip/gpu-burn.tar.gz")
        ]
        
        for path, tar_path in paths:
            if not os.path.exists(path):
                print(f"{path} 文件夹不存在,正在解压{tar_path}")
            full_path = os.path.join(os.path.dirname(__file__), path)
            if os.path.exists(full_path):
                # 创建异步任务执行解压命令
                cmd = f'tar -xzf {os.path.join(self.get_pwd(), os.path.dirname(__file__), tar_path)} -C {self.get_pwd()}'
                process = await asyncio.create_subprocess_shell(
                    cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                await process.wait()
        
        return True

    def is_path(self)-> str:
        return os.path.join(os.path.dirname(__file__))
    
if __name__ == '__main__':
    utilt = Utilt()
    print(utilt.get_tar_cont())
