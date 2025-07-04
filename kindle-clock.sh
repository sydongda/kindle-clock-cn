#!/bin/sh

PWD=$(pwd)
LOGNULL="/dev/null"
LOG="/mnt/us/clock.log"
# LOG=${LOGNULL}
FBINK="/mnt/us/extensions/MRInstaller/bin/PW2/fbink -q"
FONT="regular=/usr/java/lib/fonts/Palatino-Regular.ttf"
CNFONT="regular=/usr/java/lib/fonts/STSongMedium.ttf"
CITY="ShangHai"
COND="---"
TEMP="---"
NTP_HOST="ntp1.aliyun.com"

#PW2
FBROTATE="echo -n 0 > /sys/devices/platform/imx_epdc_fb/graphics/fb0/rotate"
TURNOFF_BACKLIGHT="echo 0 > /sys/class/backlight/max77696-bl/brightness"

update_time() {
    echo "`date '+%Y-%m-%d_%H:%M:%S'`: Setting time..." >> $LOG
    ntpdate -s "${NTP_HOST}"
}

wait_for_wifi() {
  lipc-get-prop com.lab126.wifid cmState | grep -e "CONNECTED" | wc -l
}

disable_wifi() {
    ### Disable WIFI
    lipc-set-prop com.lab126.cmd wirelessEnable 0
}

### Updates weather info
fetch_weather() {
    local url=$1
    local TRIES=0
    local MAX_RETRIES=3
    local WEATHER=""

    while [ $TRIES -lt $MAX_RETRIES ]; do
        WEATHER=$(curl -s -f -m 5 "$url" 2>> $LOGNULL)
        if [ ! -z "$WEATHER" ]; then
            echo "$WEATHER"
            return 0
        fi
        TRIES=$((TRIES + 1))
        sleep 1  # 等待 1 秒后重试
    done

    echo "Failed to fetch weather ($url) after $MAX_RETRIES attempts." >> $LOG
    return 1
}
update_weather_wttr() {
    URL="https://zh.wttr.in/${CITY}?format=%C"
    COND=$(fetch_weather "$URL")
    if [ $? -ne 0 ]; then
        echo "Weather fetch failed." >> $LOG
    fi
    ### 英文的温度更准确，中文的温度感觉会滞后。
    URL="https://wttr.in/${CITY}?format=%t"
    TEMP=$(fetch_weather "$URL" | sed 's/+//g')
    if [ $? -ne 0 ]; then
        echo "Temperature fetch failed." >> $LOG
    fi
    echo "`date '+%Y-%m-%d_%H:%M:%S'`: Processed weather data. ($TEMP // $COND)" >> $LOG
}

update_weather_open_meteo() {
    URL="https://api.open-meteo.com/v1/forecast?latitude=31.2222&longitude=121.4581&hourly=temperature_2m&current=temperature_2m,weather_code&timezone=auto&forecast_days=1"
    WEATHER=$(curl "$URL" 2>> $LOG)
    if [ $? -ne 0 ]; then
        echo "Weather fetch failed." >> $LOG
    fi
    TEMP_V=$(echo "$WEATHER" | jq -r '.current.temperature_2m')
    TEMP_U=$(echo "$WEATHER" | jq -r '.hourly_units.temperature_2m')
    TEMP=$(echo "${TEMP_V}${TEMP_U}")
    COND_CODE=$(echo "$WEATHER" | jq -r '.current.weather_code')
    COND=$(python3 weather_map.py "$COND_CODE")
    echo "`date '+%Y-%m-%d_%H:%M:%S'`: Processed weather data. ($TEMP // $COND)" >> $LOG
}

update_weather() {
    update_weather_open_meteo
    # update_weather_wttr
}
clear_screen(){
    $FBINK -f -c
    $FBINK -f -c
}

### Prep Kindle...
echo "`date '+%Y-%m-%d_%H:%M:%S'`: ------------- Startup ------------" >> $LOG

### No way of running this if wifi is down.
if [ `lipc-get-prop com.lab126.wifid cmState` != "CONNECTED" ]; then
	exit 1
fi

$FBINK -w -c -f -m -t $FONT,size=20,top=410,bottom=0,left=0,right=0 "Starting Clock..." > /dev/null 2>&1

#PW2/3
stop lab126_gui
stop otaupd
stop phd
stop tmd
stop x
stop todo
# stop mcsd ###stop: Unknown instance:

sleep 2

### turn off 270 degree rotation of framebuffer device
eval $FBROTATE

### Set lowest cpu clock
echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
### Disable Screensaver
lipc-set-prop com.lab126.powerd preventScreenSaver 1

### set time/weather as we start up
update_time
update_weather
disable_wifi
### 星期显示中文
DATE=$(python3 cnday.py)
clear_screen

update_display() {
    BAT=$(gasgauge-info -s)
    TIME=$(date '+%H:%M')

    # Adjust coordinates according to display resolution. This is for PW2.
    $FBINK -b -c -m -t $FONT,size=150,top=10,bottom=0,left=0,right=0 "$TIME"
    $FBINK -b -m -t $CNFONT,size=30,top=410,bottom=0,left=0,right=0 "$DATE"
    $FBINK -b    -t $FONT,size=10,top=0,bottom=0,left=840,right=0 "BATTERY: $BAT"
    $FBINK -b -m -t $CNFONT,size=20,top=510,bottom=0,left=0,right=0 "$COND"
    $FBINK -b -m -t $FONT,size=30,top=600,bottom=0,left=0,right=0 "$TEMP"
    if [ "$NOWIFI" = "1" ]; then
        $FBINK -b -t $FONT,size=10,top=0,bottom=0,left=50,right=0 "No Wifi!"
    fi
    # Update framebuffer
    $FBINK -w -s

    echo "$(date '+%Y-%m-%d_%H:%M:%S'): Battery: $BAT" >> $LOG
}

while true; do
    echo "`date '+%Y-%m-%d_%H:%M:%S'`: Top of loop (awake!)." >> $LOG
    ### Backlight off
    eval ${TURNOFF_BACKLIGHT}

    ### Get weather data and set time via ntpdate every hour
    MINUTE=`date "+%M"`
    HOUR=`date "+%H"`
    if [ "$HOUR" = "00" ] && [ "$MINUTE" = "00" ]; then
        DATE=$(python3 cnday.py)
    fi

    if [ "$MINUTE" = "00" ]; then
        #为了避免整点的时候，延迟太多，在打开wifi之前，先更新时间信息
        update_display

        echo "`date '+%Y-%m-%d_%H:%M:%S'`: Enabling Wifi" >> $LOG
        ### Enable WIFI, disable wifi first in order to have a defined state
    	lipc-set-prop com.lab126.cmd wirelessEnable 1
        TRYCNT=0
        NOWIFI=0
        ### Wait for wifi to come up
        while true; do
            if [ $(wait_for_wifi) -gt 0 ]; then
                break
            fi
            if [ ${TRYCNT} -gt 30 ]; then
                ### waited long enough
                echo "`date '+%Y-%m-%d_%H:%M:%S'`: No Wifi... ($TRYCNT)" >> $LOG
                NOWIFI=1
                break
            fi
            WIFISTATE=$(lipc-get-prop com.lab126.wifid cmState)
            echo "`date '+%Y-%m-%d_%H:%M:%S'`: Waiting for Wifi... (try $TRYCNT: $WIFISTATE)" >> $LOG
            ### Are we stuck in READY state?
            if [ "$WIFISTATE" = "READY" ]; then
                ### we have to reconnect
                echo "`date '+%Y-%m-%d_%H:%M:%S'`: Reconnecting to Wifi..." >> $LOG
                /usr/bin/wpa_cli -i wlan0 reconnect

                ### Could also be that kindle forgot the wpa ssid/psk combo
                #if [ wpa_cli status | grep INACTIVE | wc -l ]; then...
            fi
            sleep 1
            TRYCNT=$((TRYCNT + 1))
        done
        echo "`date '+%Y-%m-%d_%H:%M:%S'`: wifi: `lipc-get-prop com.lab126.wifid cmState`" >> $LOG
        echo "`date '+%Y-%m-%d_%H:%M:%S'`: wifi: `wpa_cli status`" >> $LOG

        if [ `lipc-get-prop com.lab126.wifid cmState` = "CONNECTED" ]; then
            ### Finally, set time
            update_time
            update_weather
        fi

        clear_screen
    fi

    update_display
    
    disable_wifi
    hwclock --systohc >> $LOG 2>&1 # Set hardware clock from system time

    ### Set Wakeuptimer
	#echo 0 > /sys/class/rtc/rtc1/wakealarm
	#echo ${WAKEUP_TIME} > /sys/class/rtc/rtc1/wakealarm
    NOW=$(date +%s)
    let WAKEUP_TIME="((($NOW + 59)/60)*60)" # Hack to get next minute
    let SLEEP_SECS=$WAKEUP_TIME-$NOW

    ### Prevent SLEEP_SECS from being negative or just too small
    ### if we took too long
    if [ $SLEEP_SECS -lt 5 ]; then
        let SLEEP_SECS=$SLEEP_SECS+60
    fi
    echo "`date '+%Y-%m-%d_%H:%M:%S'`: Going to sleep for $SLEEP_SECS" >> $LOG
    rtcwake -d /dev/rtc1 -m mem -s $SLEEP_SECS
	### Go into Suspend to Memory (STR)
	# echo "mem" > /sys/power/state
#    exit
done
