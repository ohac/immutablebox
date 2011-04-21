#!/bin/sh
rm -fr sandbox
mkdir sandbox
cd sandbox

../bin/ib init
echo 1 >1
echo 2 >2
echo 3 >3

../bin/ib st >.ib/actual
cat <<EOF >.ib/expected
? 1
? 2
? 3
EOF
diff -u .ib/expected .ib/actual

ACTUAL=`../bin/ib log | wc -l`
if [ $ACTUAL -ne 0 ]; then
  echo $ACTUAL
fi

../bin/ib ci

ACTUAL=`../bin/ib log | wc -l`
if [ $ACTUAL -ne 1 ]; then
  echo $ACTUAL
fi

../bin/ib ci

ACTUAL=`../bin/ib log | wc -l`
if [ $ACTUAL -ne 1 ]; then
  echo $ACTUAL
fi

ACTUAL=`../bin/ib st | wc -l`
if [ $ACTUAL -ne 0 ]; then
  echo $ACTUAL
fi

rm 2
../bin/ib st >.ib/actual
cat <<EOF >.ib/expected
M 2
EOF
diff -u .ib/expected .ib/actual

../bin/ib up
ACTUAL=`../bin/ib st | wc -l`
if [ $ACTUAL -ne 0 ]; then
  echo $ACTUAL
fi
