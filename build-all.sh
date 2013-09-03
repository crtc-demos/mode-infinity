set -x

cd $(dirname "$0")

rm -rf demodisk.ssd

if [ -x "$(which pasta)" ]; then
  PASTA=$(which pasta)
else
  PASTA=/home/jules/code/pasta/pasta
fi

if [ -x "$(which bbcim)" ]; then
  BBCIM=$(which bbcim)
else
  if ! [ -x bbcim/bbcim ]; then
    pushd bbcim
    ./mkbbcim
    popd
  fi
  BBCIM=$(readlink -f bbcim/bbcim)
fi

if [ ! -x "$PASTA" ] || [ ! -x "$BBCIM" ]; then
  echo 'Missing pasta or bbcim! Whoops.'
  exit 1
fi

export PASTA
export BBCIM

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

pushd font
./compile.sh
popd

pushd parallax
./compile.sh
popd

pushd vgmproc
./compile.sh
popd

pushd finalpic
./compile.sh
popd

$BBCIM -new demodisk.ssd
pushd tmpdisk
$BBCIM -a ../demodisk.ssd *
popd
