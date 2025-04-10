#!/bin/bash

# Define the function to run when the spacebar key is pressed
run_function() {
    echo "Spacebar key was pressed!"
}

# Loop to continuously check for key presses
while true; do
    # Read a single character (including special keys)
    IFS= read -rsn1 key

    # Check if the pressed key is the spacebar
    if [[ "$key" == $'\x20' ]]; then  # $'\x20' is the hexadecimal representation of a space
        run_function
    fi
done