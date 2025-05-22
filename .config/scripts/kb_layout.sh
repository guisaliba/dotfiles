#!/bin/bash

layout=$(xkb-switch)

case "$layout" in
    us)
        echo "🇺🇸 us    "
        ;;
    br*|*abnt2*)
        echo "🇧🇷 br    "
        ;;
    *)
        echo "$layout"
        ;;
esac
