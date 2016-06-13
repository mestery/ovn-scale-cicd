#!/bin/bash

# A combined script to run all the things

# Prepare the environment
./prepare.sh

# Run the testsuite
./scale-run.sh

# Clean things up
./scale-cleanup.sh
