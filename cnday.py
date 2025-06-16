import locale
from datetime import datetime

# 设置中文环境（需系统支持）
locale.setlocale(locale.LC_TIME, 'zh_CN.UTF-8')  # 简体中文

now = datetime.now()
print(now.strftime("%Y年%m月%d日 %A")) 