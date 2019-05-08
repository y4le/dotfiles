#/bin/bash

# use like `benchmark.sh -n 50 ./testscript.sh`

# parse arguments
cmd=
N=10

while [ "$1" != "" ]; do
  case $1 in
    -n)
      shift
      N=$1
      ;;
    *)
      cmd=$1
  esac
  shift
done

# validate params
if [ -z cmd ]; then
  echo "Must provide command to benchmark"
  return 1
fi

echo "N: $N  cmd: $cmd"

# run benchmark
tmpfile=`mktemp`
pstr="[==================================================]"
for i in `seq 1 $N`; do
  command time -ao $tmpfile -f "%e" $cmd 1>/dev/null
  pd=$(( $i * 50 / $N ))
  printf "\r%3d.%1d%% %.${pd}s" $(( $i * 100 / $N )) $(( ($i * 1000 / $N) % 10 )) $pstr
done
printf "]\n"

# parse result
awk 'NR == 1 {min = $0} $0 > max {max = $0} {total += $0} END {print "total:", total, "avg:", total/NR, "min:", min, "max:", max}' $tmpfile

# clean up
rm $tmpfile
