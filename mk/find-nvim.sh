#!/bin/sh

exec /bin/sh "${0%/*}/find-mise-tool.sh" nvim "$@"
