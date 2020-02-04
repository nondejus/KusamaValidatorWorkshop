#!/usr/bin/env bash

# Generates an ssh key in the .ssh folder in the root directory of the project

mkdir -p /../.ssh
ssh-keygen -t rsa -f /../.ssh/id_rsa -C $USER