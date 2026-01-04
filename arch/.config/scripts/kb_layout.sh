#!/bin/bash

layout=$(xkb-switch)

case "$layout" in
    us)
        echo "🇺🇸  "
        ;;
    br*|*abnt2*)
        echo "🇧🇷  "
        ;;
    *)
        echo "$layout"
        ;;
esac
