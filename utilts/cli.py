import os
import utilts.log as loge
import utilts.config as config
from noneprompt import CancelledError, ListPrompt, Choice, InputPrompt
import time
import subprocess
import utilts.util as util
class CLI:
    """
    CLI 菜单类
    """
    def __init__(self):
        self.log = loge.Log()
        self.utitl = util.Utilt()
        self.config = config.Config()
        self.log.msg("初始化 CLI 菜单")
        #收集信息基本信息
        # self.run_command("bash",f"../bash/report.bash '{self.log.get_log_file()}'"," ","")

    def run_menu(self):
        """
        运行菜单
        """
        cfg = self.config.get_config_value("MENU")
        
        if cfg is None:
            self.log.msg("配置文件不存在")
            return None
        # 获取GPU数量
        gpu_count = str(self.utitl.get_gpu_count())
        if len(gpu_count) != 1:
            gpu_count = "0" 
        if "NCCL_COMMAND" in cfg:
            nccl_args = cfg["NCCL_COMMAND"]["args"]
            for key, value in nccl_args.items():
                if isinstance(value, str) and "$GPU_COUNT" in value:
                    nccl_args[key] = value.replace("$GPU_COUNT", str(gpu_count))
        
        self.log.msg(f"初始化GPU数量 :{self.utitl.get_gpu_count()}")
        self.log.msg("运行菜单")
        self.log.msg(cfg, "DEBUG")
        choices: list[Choice] = []
        for i in cfg["meu"]:
            self.log.msg("向菜单添加"+i)
            choices.append(Choice(cfg[f"{i}"]["title"], cfg[f"{i}"]))
        result = ListPrompt("请选择菜单项", choices).prompt()
        self.log.msg(result.data, "DEBUG")
        self.run_menu2(result.data)
    def run_menu2(self,result):
        """
        运行2级菜单
        """
        self.log.msg(result,"DEBUG")
        if "args" in result and "T" in result["args"]:
            del result["args"]["T"]
        
        choices: list[Choice] = []
        for k,j in result["args"].items():
            self.log.msg(f"{k} {j}","DEBUG")
            choices.append(Choice(k, j))
        result["args"]["T"] = "test"
        choices.append(Choice("自定义参数","T"))
        self.log.msg(result,"DEBUG")
        result1 = ListPrompt("请选择测试项",choices=choices).prompt()
        self.log.msg(f"选择的:{result1} data: {result1.data}")
        # self.log.msg(f"")
        self.run_command(result["command"],result1.data,result["default_args"],result["home"])
        
    def run_command(self, command : str,arg: str,defarg: str,homepath):
        """
        运行命令
        """
        
        self.log.msg(f"运行命令: {command} {arg} {defarg} , 执行目录: {self.utitl.get_pwd()}/{homepath}")
        # homepath = f"{self.utitl.get_pwd()}/{homepath}"
        if arg == "T":
            try:
                arg = InputPrompt("请输入参数").prompt()
            except KeyboardInterrupt:
                self.log.msg("用户取消输入")
                print("用户取消输入")
        else:
            pass
        
        # if homepath == "":
            
        #     homepath = None
        if arg =="exit":
            exit()
            
        if command == "bash":
            cmd = f'{arg} {homepath}'
            homepath = os.path.join(os.path.dirname(__file__))
        else:
            cmd = f'./{command} {arg} {defarg}'
        self.log.msg(f"准备执行的命令: {cmd}")
        logname = command.split(".")[0] + ".log"
        log2 = self.log.create_log_file(logname)
        print(f"准备执行的命令: {cmd}")
        # print(f"工作目录: {homepath}")
        try:
            print("执行开始")
            process = subprocess.Popen(
                cmd,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,  # 将错误输出合并到标准输出
                text=True,
                cwd=homepath,
                bufsize=1,  # 行缓冲
                universal_newlines=True
            )
            if process.stdout is None:
                raise subprocess.SubprocessError("无法创建进程或获取输出流")
            while True:
                output = process.stdout.readline()
                if output == '' and process.poll() is not None:
                    break
                if output:
                    print(output.strip())
                    self.log.msg(output.strip(),logger_name=log2)  # 同时记录到日志
            return_code = process.poll()
            self.log.msg(f"命令执行结束, 返回码: {return_code}")
            print("执行结束")
            print(f"日志路径: {self.log.get_log_file()}/{logname}")
            # 按下回车继续
            input("按下回车继续")
            self.run_menu()
        except subprocess.SubprocessError as e:
            self.log.msg(f"子进程错误: {e}")
            print(f"执行失败: {e}")
            return None
        except Exception as e:
            self.log.msg(f"运行命令失败: {e}")
            # print(f"执行失败: {e}")
            return None
def cli():
    cli = CLI()

    cli.run_menu()

        