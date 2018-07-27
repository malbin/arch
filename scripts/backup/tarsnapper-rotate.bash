#!/bin/bash

# script requires tarsnapper...
LOC=$(which tarsnapper)
if [ $? -ne 0 ]; then
    echo "Error: Tarsnapper not found... is it installed?"
    exit 1
fi

echo "removing expired root snapshots..."
tarsnapper --target "x1-snap01.\$date.img" --deltas 1d 7d 14d 60d 180d - expire
tarsnapper --target "/x1c6/root/snap01-\$date.img" --deltas 1d 7d 14d 60d 180d - expire

echo "removing expired home snapshots..."
tarsnapper --target "x1-home-\$date" --deltas 1d 7d 14d 60d 180d - expire
tarsnapper --target "/x1c6/home/jaryd-\$date" --deltas 1d 7d 14d 60d 180d - expire
