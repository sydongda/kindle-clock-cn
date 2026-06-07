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
        sleep 1 
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
    ### 
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
# if [ `lipc-get-prop com.lab126.wifid cmState` != "CONNECTED" ]; then
# 	exit 1
# fi

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
DATE=$(python3 cnday.py)
clear_screen

update_display() {
    # BAT=$(gasgauge-info -s)
    BAT=$(lipc-get-prop com.lab126.powerd battLevel)
    TIME=$(date '+%H:%M')

    # Adjust coordinates according to display resolution. This is for PW2.
    $FBINK -b -c -m -t $FONT,size=150,top=10,bottom=0,left=0,right=0 "$TIME"
    $FBINK -b -m -t $CNFONT,size=30,top=410,bottom=0,left=0,right=0 "$DATE"
    $FBINK -b    -t $FONT,size=10,top=0,bottom=0,left=840,right=0 "BATTERY: $BAT"
    $FBINK -b -m -t $CNFONT,size=20,top=510,bottom=0,left=0,right=0 "$COND / $TEMP"
    $FBINK -b -m -t $CNFONT,size=20,top=600,bottom=0,left=0,right=0 "${higth_exam_days}"
    if [ "$NOWIFI" = "1" ]; then
        $FBINK -b -t $FONT,size=10,top=0,bottom=0,left=50,right=0 "No Wifi(${nowifi_cnt})!"
    fi
    # Update framebuffer
    $FBINK -w -s

    echo "$(date '+%Y-%m-%d_%H:%M:%S'): Battery: $BAT" >> $LOG
}
nowifi_cnt=0
higth_exam_days=$(python3 countdown_to_zhongkao.py)
while true; do
    echo "`date '+%Y-%m-%d_%H:%M:%S'`: Top of loop (awake!)." >> $LOG
    ### Backlight off
    eval ${TURNOFF_BACKLIGHT}
    MAX_RETRIES=30
    ### Get weather data and set time via ntpdate every hour
    MINUTE=`date "+%M"`
    HOUR=`date "+%H"`
    if [ "$HOUR" = "00" ] && [ "$MINUTE" = "00" ]; then
        DATE=$(python3 cnday.py)
    fi

    if [ "$MINUTE" = "00" ]; then
        higth_exam_days=$(python3 countdown_to_zhongkao.py)
        update_display

        lipc-set-prop com.lab126.powerd refreshBattery
        
        echo "`date '+%Y-%m-%d_%H:%M:%S'`: Enabling Wifi" >> $LOG
        ### Enable WIFI, disable wifi first in order to have a defined state
    	lipc-set-prop com.lab126.cmd wirelessEnable 1
        TRYCNT=0
        NOWIFI=0
        ### Wait for wifi to come up
        while true; do
            /usr/bin/wpa_cli scan
            sleep 2
            /usr/bin/wpa_cli -i wlan0 reconnect
            sleep 5
            if [ $(wait_for_wifi) -gt 0 ]; then
                nowifi_cnt=0
                break
            fi
            if [ ${TRYCNT} -gt $((MAX_RETRIES + 10 * nowifi_cnt)) ]; then
                ### waited long enough
                echo "`date '+%Y-%m-%d_%H:%M:%S'`: No Wifi... ($TRYCNT)" >> $LOG
                NOWIFI=1
                nowifi_cnt=$((nowifi_cnt + 1))
                break
            fi
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
done
