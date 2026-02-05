#!/bin/bash

STATE_FILE="/tmp/waybar_weather_unit"
LOCATION_FILE="$HOME/.weather_location"

# Handle toggle
if [ "$1" = "toggle" ]; then
    if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "f" ]; then
        echo "c" > "$STATE_FILE"
    else
        echo "f" > "$STATE_FILE"
    fi
    pkill -RTMIN+8 waybar
    exit 0
fi

# Get unit, defaults to c (Celsius)
if [ -f "$STATE_FILE" ]; then
    unit=$(cat "$STATE_FILE")
else
    unit="c"
    echo "c" > "$STATE_FILE"
fi

# Coordinates for Sumy, Ukraine
# If location file doesn't exist or has invalid data, use Sumy coordinates
if [ ! -f "$LOCATION_FILE" ] || [ "$(cat "$LOCATION_FILE")" = "0.0,0.0" ]; then
    latitude="50.9077"
    longitude="34.7981"
    echo "$latitude,$longitude" > "$LOCATION_FILE"
else
    IFS=',' read -r latitude longitude <<< "$(cat "$LOCATION_FILE")"
fi

# Determine temperature unit for API
if [ "$unit" = "f" ]; then
    temp_unit="fahrenheit"
else
    temp_unit="celsius"
fi

# Fetch weather data from Open-Meteo API
weather_data=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true&temperature_unit=$temp_unit&windspeed_unit=mph&hourly=relativehumidity_2m,apparent_temperature,precipitation,surface_pressure&timezone=auto" 2>/dev/null)

# Parse JSON response using jq if available, otherwise use grep/sed
if command -v jq &> /dev/null; then
    temperature=$(echo "$weather_data" | jq -r '.current_weather.temperature')
    windspeed=$(echo "$weather_data" | jq -r '.current_weather.windspeed')
    weathercode=$(echo "$weather_data" | jq -r '.current_weather.weathercode')

    # Get current hour data for additional info
    current_hour=$(date +%H)
    humidity=$(echo "$weather_data" | jq -r ".hourly.relativehumidity_2m[$current_hour]")
    feels_like=$(echo "$weather_data" | jq -r ".hourly.apparent_temperature[$current_hour]")
    precipitation=$(echo "$weather_data" | jq -r ".hourly.precipitation[$current_hour]")
    pressure=$(echo "$weather_data" | jq -r ".hourly.surface_pressure[$current_hour]")

    # Extract units from API response
    windspeed_unit=$(echo "$weather_data" | jq -r '.current_weather_units.windspeed // "mph"')
    humidity_unit=$(echo "$weather_data" | jq -r '.hourly_units.relativehumidity_2m // "%"')
    precipitation_unit=$(echo "$weather_data" | jq -r '.hourly_units.precipitation // "mm"')
    pressure_unit=$(echo "$weather_data" | jq -r '.hourly_units.surface_pressure // "hPa"')
else
    # Fallback without jq
    temperature=$(echo "$weather_data" | grep -o '"temperature":[0-9.]*' | head -1 | cut -d':' -f2)
    windspeed=$(echo "$weather_data" | grep -o '"windspeed":[0-9.]*' | head -1 | cut -d':' -f2)
    weathercode=$(echo "$weather_data" | grep -o '"weathercode":[0-9]*' | head -1 | cut -d':' -f2)
    humidity="N/A"
    feels_like="N/A"
    precipitation="0"
    pressure="N/A"
    windspeed_unit="mph"
    humidity_unit="%"
    precipitation_unit="mm"
    pressure_unit="hPa"
fi

# Map WMO weather codes to icons and descriptions
case "$weathercode" in
    0) icon="󰖙"; condition="Clear" ;;
    1|2) icon="󰖕"; condition="Partly Cloudy" ;;
    3) icon="󰖐"; condition="Cloudy" ;;
    45|48) icon="󰖑"; condition="Foggy" ;;
    51|53|55) icon="󰖗"; condition="Drizzle" ;;
    61|63|65) icon="󰖖"; condition="Rain" ;;
    66|67) icon="󰙾"; condition="Freezing Rain" ;;
    71|73|75) icon="󰖘"; condition="Snow" ;;
    77) icon="󰼴"; condition="Snow Grains" ;;
    80|81|82) icon="󰼳"; condition="Rain Showers" ;;
    85|86) icon="󰼶"; condition="Snow Showers" ;;
    95) icon="󰙾"; condition="Thunderstorm" ;;
    96|99) icon="󰙾"; condition="Thunderstorm with Hail" ;;
    *) icon=""; condition="Unknown" ;;
esac

# Format temperature
if [ "$unit" = "f" ]; then
    temp_display="${temperature}°F"
    feels_display="${feels_like}°F"
else
    temp_display="${temperature}°C"
    feels_display="${feels_like}°C"
fi

tooltip="📍 Sumy, Ukraine\n"
tooltip+="Lat: $latitude, Lon: $longitude\n\n"
tooltip+=" Temp: ${temp_display}\n"
tooltip+=" Feels like: ${feels_display}\n"
tooltip+="$icon Weather: $condition\n"
tooltip+="󰖌 Humidity: ${humidity}${humidity_unit}\n"
tooltip+=" Wind: ${windspeed} ${windspeed_unit}\n"
tooltip+=" Precipitation: ${precipitation} ${precipitation_unit}\n"
tooltip+="󱤊 Pressure: ${pressure} ${pressure_unit}\n"
tooltip+="\n󰳽 Click to toggle °C/°F"

echo "{\"text\":\"$icon $temp_display\",\"tooltip\":\"<big>Weather - Sumy</big>\n$tooltip\"}"