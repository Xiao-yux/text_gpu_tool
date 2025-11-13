
import toml
import os

class Config:
    """ 创建配置文件"""
    def __init__(self):
        if not os.path.exists(os.path.join(os.path.dirname(__file__), 'config.toml')):
            os.popen(f' echo "{cfg}" > {os.path.join(os.path.dirname(__file__), "config.toml")}')
        
        config = toml.load(os.path.join(os.path.dirname(__file__), 'config.toml'))
        self.__config = config


    def get_config_value(self, key: str) -> dict | None:
        """ 获取配置文件中的值"""

        return self.__config.get(key) or {}
if __name__ == '__main__':
    config = Config()
    print (config)
    a= config.get_config_value("MENU")
    print(a)
    
    
    
    # b=a['args'].items()
    # print(b)
    # for key , value in b:
    #     print(key,value)










cfg = """
[OPTION]
home = "/home/aisuan"


[LOG]
log_path = "/home/aisuan/log"    #在log/$time目录下存储日志
log_level = "DEBUG"  #大写
console_output = true  #控制台输出日志
log_file = "log.log"  #存储脚本执行的日志   日志级别-时间-选了什么
sys_info = "sys_info.log"  #存储系统信息
fd_file = "fd.log"    #存储Fd输出的日志
gpu_burn_file = "gpu_burn.log"  #存储gpu_burn输出的日志
nccl_file = "nccl.log"  #存储nccl输出的日志
nvidia_file = "nvidia.log"  #存储nvidia-smi -q 输出的日志

[MENU]
meu = ["GPU_BURN","FD_COMMAND","NCCL_COMMAND","OPTION"]


[MENU.OPTION]
title = "设置"  #1级菜单名称
command = "bash"  #执行命令
home = ""  
default_args =""
args = {"退出脚本"= "","重启"= "reboot","关机"= "poweroff"}

[MENU.GPU_BURN]
title = "GPU压力测试"  #1级菜单名称
command = "gpu_burn"  #执行命令
home = "/home/aisuan/gpu_burn"  #脚本所在目录，需要在目录下执行
default_args =""
# 2级菜单显示名称: 执行参数
args = {"15分钟"= 900,"30分钟"= 1800,"1小时"= 3600,"2小时"= 7200,"4小时"= 14400,"8小时"= 28800,"12小时"= 43200,"24小时"= 86400,"48小时"= 172800}

[MENU.FD_COMMAND]
title = "FD测试(fieldiag)"
command = "fieldiag.sh"   #执行的脚本
home = "/home/aisuan/fd"  #脚本所在目录
default_args = "--no_bmc" # 默认追加参数
args = {"运行level1测试"='--level1',"运行level2测试"='--level2'}

[MENU.NCCL_COMMAND]
title = "NCCL测试"
command = "all_reduce_perf"
home = "/home/aisuan/nccl"
default_args =""
args = {"运行nccl测试"='-b 256M -e 20G -f 2 -g $GPU_COUNT'}
"""