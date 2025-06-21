import sys

WEATHER_MAP = {
    0: {"name": "晴天", "icon": "☀️", "description": "无云"},
    1: {"name": "晴间多云", "icon": "🌤️", "description": "云量 ≤ 20%"},
    2: {"name": "局部多云", "icon": "⛅", "description": "云量 21%-50%"},
    3: {"name": "阴天", "icon": "☁️", "description": "云量 > 50%"},
    45: {"name": "雾", "icon": "🌫️", "description": "能见度 < 1km"},
    48: {"name": "冻雾", "icon": "❄️🌫️", "description": "雾+冰晶凝结"},
    51: {"name": "小雨(毛毛雨)", "icon": "🌦️", "description": "强度：轻微"},
    53: {"name": "中雨(毛毛雨)", "icon": "🌧️", "description": "强度：中等"},
    55: {"name": "大雨(毛毛雨)", "icon": "🌧️🌧️", "description": "强度：强"},
    56: {"name": "轻冻毛毛雨", "icon": "🌧️❄️", "description": "温度 ≤ 0°C"},
    57: {"name": "强冻毛毛雨", "icon": "🌧️❄️", "description": "温度 ≤ 0°C"},
    61: {"name": "小雨", "icon": "🌧️", "description": "普通降雨"},
    63: {"name": "中雨", "icon": "🌧️🌧️", "description": "普通降雨"},
    65: {"name": "大雨", "icon": "🌧️🌧️🌧️", "description": "普通降雨"},
    66: {"name": "轻冻雨", "icon": "🌧️❄️", "description": "雨落地结冰"},
    67: {"name": "强冻雨", "icon": "🌧️❄️", "description": "雨落地结冰"},
    71: {"name": "小雪", "icon": "❄️", "description": "雪花飘落"},
    73: {"name": "中雪", "icon": "❄️❄️", "description": "积雪可能"},
    75: {"name": "大雪", "icon": "❄️❄️❄️", "description": "积雪显著"},
    77: {"name": "米雪", "icon": "❄️✨", "description": "细小冰粒"},
    80: {"name": "小阵雨", "icon": "🌦️", "description": "短暂降雨"},
    81: {"name": "中阵雨", "icon": "🌧️", "description": "较强短暂降雨"},
    82: {"name": "大暴雨(阵性)", "icon": "🌧️⛈️", "description": "短时强降水"},
    85: {"name": "小阵雪", "icon": "❄️🌨️", "description": "短暂降雪"},
    86: {"name": "大阵雪", "icon": "❄️❄️🌨️", "description": "强短暂降雪"},
    95: {"name": "雷阵雨", "icon": "⛈️", "description": "伴随雷电"},
    96: {"name": "雷阵雨+小冰雹", "icon": "⛈️🧊", "description": "冰雹直径 < 5mm"},
    99: {"name": "雷阵雨+大冰雹", "icon": "⛈️🧊🧊", "description": "冰雹直径 ≥ 5mm"}
}

def get_weather_info(code):
    """获取特定天气代码的详细信息"""
    code = int(code)
    weather = WEATHER_MAP.get(code, {"name": f"未知天气代码:{code}"})
    return f"{weather['name']}"

print(get_weather_info(sys.argv[1]))
