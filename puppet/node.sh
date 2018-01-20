#!/bin/bash
if [ "$1" = blade1.tsbe.local ]
then
  echo "environment: test"
elif [ "$1" = blade2.tsbe.local ]
then
  echo "environment: integration"
  elif [ "$1" = blade3.tsbe.local ]
then
  echo "environment: test"
else 
  echo "environment: production"
fi