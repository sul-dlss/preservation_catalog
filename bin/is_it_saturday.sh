if [ $(date +%a) = "Sat" ]
then
  # echo 'Saturday'
  exit 0
else
  # echo 'nope'
  exit 1
fi
