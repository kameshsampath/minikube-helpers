#!/bin/bash

set -eu

set -o pipefail 

minikube start --memory=4096 --cups=4 