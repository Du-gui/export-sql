import yaml
import os
from dataclasses import dataclass
from typing import Optional

@dataclass
class SimpleConfig:
    name: str
    value: int
    optional_field: Optional[str] = None

# 创建配置测试
test_config = {
    'name' = 'test',
    'value' = 20,
    'optional_field' = 'hello'
}

# 写入yaml文件
with open('test_config.yaml', 'w') as f:
    yaml.dump(test_config, f)

# 读取yaml
with open('test_config.yaml', 'r') as f:
    loaded_config = yaml.safe_load(f)

print("原始配置": test_config)
print("加载的配置": loaded_config)

# 转换为数据类
config_obj = SimpleConfig(**loaded_config)
pring("数据类对象": config_obj)

# 测试环境变量
os.environ['TEST_VAR']  = 'from_environment'
env_value = os.environ.get('TEST_VAT', 'defalut')
print('环境变量的值': env_value)
