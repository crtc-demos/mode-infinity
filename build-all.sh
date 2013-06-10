set -x

cd $(dirname "$0")

if [ -x "$(which pasta)" ]; then
  PASTA=$(which pasta)
else
  PASTA=/home/jules/code/pasta/pasta
fi

BBCIM=$(which bbcim)

if [ ! -x "$PASTA" ] || [ ! -x "$BBCIM" ]; then
  echo 'Missing pasta or bbcim! Whoops.'
  exit 1
fi

OUTPUTDISK=$(readlink -f tmpdisk)

mkdir -p "$OUTPUTDISK"
pushd "$OUTPUTDISK"
rm -f *
popd

export OUTPUTDISK

set -e

pushd copper
./compile.sh
popd

bbcim -new demodisk.ssd
pushd tmpdisk
bbcim -a ../demodisk.ssd *
popd
