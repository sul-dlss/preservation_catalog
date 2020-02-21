#!/bin/bash
set -ev

result=$(openapi-enforcer validate openapi.yml)
[[ $result =~ "Document is valid" ]] && {
    echo "Validation good"
    exit 0
} || {
    echo $result
    exit 1
}
