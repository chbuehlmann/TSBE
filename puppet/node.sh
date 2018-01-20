#!/bin/bash
if [ "$1" = blade1.tsbe.local ]
then
  echo "environment: test"
elif [ "$1" = blade2.tsbe.local ]
then
  echo "environment: integration"
else 
  echo "environment: production"
fi