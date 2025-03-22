#!/bin/bash

source .env
locust -f load_test.py --users $USERS --spawn-rate $SPAWN_RATE --run-time ${1:-$RUN_TIME} --headless --only-summary