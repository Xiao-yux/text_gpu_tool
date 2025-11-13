from utilts.cli import cli
import argparse
import utilts.util

# pyinstaller -F --add-data "utilts:utilts" --add-data "zip:zip" --add-data "bash:bash" --name=aisuan main.py

def parse_arguments():
    """
    解析命令行参数。
    """
    parser = argparse.ArgumentParser(description='菜单v1.3\n\n\n邮箱: 1409109991@qq.com')
    
    # 添加参数
    parser.add_argument('--get_gpu_info', action='store_true', help='获取GPU信息')
    parser.add_argument('--get_sys_info', action='store_true', help='获取CPU和内存信息')
    parser.add_argument('--get_eth_info', action='store_true', help='获取网卡和硬盘信息')
    
    # 解析参数
    args = parser.parse_args()
    
    return args

def main():
    args = parse_arguments()
    ut = utilts.util.Utilt()
    if args:
        if args.get_gpu_info:
            print(ut.get_gpu_info())
            exit(0)
        elif args.get_sys_info:
            print(ut.get_sys_info())
            exit(0)
        elif args.get_eth_info:
            print(ut.get_eth_info())
            exit(0)
        else:
            cli()

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(f"取消操作")
    except KeyboardInterrupt:
        print(f"取消操作")