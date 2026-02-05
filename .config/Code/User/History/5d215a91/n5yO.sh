#!/bin/bash
kitty &
sleep 0.1
kitty -e sh -c "while true; do cava; sleep 0.1; done" &
sleep 0.1
kitty -e sh -c "while true; do peaclock; sleep 0.1; done" &
sleep 0.1
kitty -e sh -c "while true; do pipes.rs; sleep 0.1; done" &
sleep 0.1
kitty -e sh -c "while true; do neo-matrix; sleep 0.1; done" &