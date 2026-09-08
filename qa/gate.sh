#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
export PATH="$HOME/.elan/bin:$PATH"
python -m robot --outputdir qa/robot/output qa/robot/gate.robot
