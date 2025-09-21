#!/bin/bash

# Create color asset directories and JSON files for LeafTimer

COLORS_DIR="app/LeafTimer/Assets.xcassets/Colors"

# Create color sets with their JSON definitions
create_color_set() {
    local name=$1
    local light_r=$2
    local light_g=$3
    local light_b=$4
    local dark_r=$5
    local dark_g=$6
    local dark_b=$7

    mkdir -p "$COLORS_DIR/$name.colorset"

    cat > "$COLORS_DIR/$name.colorset/Contents.json" <<EOF
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "$light_b",
          "green" : "$light_g",
          "red" : "$light_r"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "$dark_b",
          "green" : "$dark_g",
          "red" : "$dark_r"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
    echo "Created $name.colorset"
}

# Background colors
create_color_set "BackgroundSecondary" "0.950" "0.950" "0.950" "0.180" "0.180" "0.180"

# Text colors
create_color_set "TextPrimary" "0.000" "0.000" "0.000" "1.000" "1.000" "1.000"
create_color_set "TextSecondary" "0.400" "0.400" "0.400" "0.700" "0.700" "0.700"

# Semantic colors
create_color_set "ErrorRed" "0.863" "0.196" "0.184" "1.000" "0.400" "0.400"
create_color_set "WarningOrange" "1.000" "0.596" "0.000" "1.000" "0.700" "0.200"
create_color_set "SuccessGreen" "0.298" "0.686" "0.314" "0.400" "0.800" "0.400"

# Timer specific colors
create_color_set "TimerActive" "0.200" "0.733" "0.400" "0.300" "0.800" "0.500"
create_color_set "TimerPaused" "0.600" "0.600" "0.600" "0.500" "0.500" "0.500"
create_color_set "BreakMode" "0.400" "0.700" "1.000" "0.500" "0.750" "1.000"
create_color_set "WorkMode" "1.000" "0.500" "0.300" "1.000" "0.600" "0.400"

echo "All color assets created successfully!"