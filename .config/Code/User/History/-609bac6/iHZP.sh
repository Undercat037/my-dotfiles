#!/bin/bash
kitty &
sleep 0.1
kitty -e sh -c "while true; do su; sleep 0.1; done" &
sleep 0.1
kitty -e sh -c "while true; do su; sleep 0.1; done" &

