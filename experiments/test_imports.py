# 实验一下导入
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

try:
    from sql_exporter import __version__
    print(f"成功导入版本：{__version__}")
except ImportError as  e:
    print(f"导入失败： {e}")

print("当前搜索路径为:")
for path in sys.path:
    print(f"  {path}")
