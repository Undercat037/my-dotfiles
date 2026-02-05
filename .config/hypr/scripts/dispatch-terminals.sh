#!/bin/bash
kitty &
sleep 0.1
kitty -e sh -c "while true; do btop; sleep 0.1; done" &
sleep 0.1
kitty -e sh -c "while true; do yazi; sleep 0.1; done" &

