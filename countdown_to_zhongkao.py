# -*- coding: utf-8 -*-
import locale
from datetime import datetime

# 尝试设置中文 locale，失败则使用默认英文
try:
    locale.setlocale(locale.LC_TIME, "zh_CN.UTF-8")
except locale.Error:
    pass  # 保持默认


def countdown_to_zhongkao():
    target_date = datetime(2027, 6, 20)
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    days_left = (target_date - today).days

    if days_left > 0:
        # 使用 .format() 代替 f-string
        print(
            "距离中考还有 {} 天，加油复习！".format(
                days_left,
            )
        )
    elif days_left == 0:
        print("今天是中考！祝考试顺利，金榜题名！")
    else:
        print("中考已过去 {} 天。".format(-days_left))


if __name__ == "__main__":
    countdown_to_zhongkao()
