#!/bin/bash

if [ "$1" = "--full" ]; then FULL_TEST=1; shift; fi

[ -x "$1" ] && rhash="$(cd ${1%/*} && echo $PWD/${1##*/})" || rhash="../rhash";
cd $(dirname "$0") # chdir after getting absolute path of $1, but before checking for ../rhash
[ -x "$rhash" ] || rhash="`which rhash`"
if [ ! -x $rhash ]; then 
  echo "Fatal: $rhash not found"
  exit 1
fi
[ "$rhash" != "../rhash" ] && echo "Testing $rhash"

#version="`$rhash -V|sed 's/^.* v//'`"
HASHOPT="`$rhash --list-hashes|sed 's/ .*$//;s/-\([0-9R]\)/\1/'|tr A-Z a-z`"

test_num=1;
new_test() {
  printf "%2u. %s" $test_num "$1"
  test_num=$((test_num+1));
}

# verify obtained value $1 aginst the expected value $2
check() {
  if [ "$1" = "$2" ]; then 
    test "$3" = "." || echo "Ok"
  else 
    echo "Failed";
    echo "obtained: $1"
    echo "expected: $2"
    return 1; # error
  fi
  return 0;
}

# match obtained value $1 against given grep-regexp $2
match_line() {
  if echo "$1" | grep -vq "$2"; then
    printf "obtained: %s\n" "$1"
    echo "regexp:  /$2/"
    return 1;
  fi
  return 0;
}

# match obtained value $1 against given grep-regexp $2
match() {
  if echo "$1" | grep -vq "$2"; then
    echo Failed
    echo "obtained: $1"
    echo "regexp:  /$2/"
    return 1; # error
  else
    test "$3" = "." || echo "Ok"
  fi
  return 0;
}

new_test "test with text string:      "
TEST_STR="test_string1"
TEST_RESULT=$( echo -n "$TEST_STR" | $rhash -CHMETAGW --sfv - | tail -1 )
TEST_EXPECTED="(stdin) F0099E81 B78F440152DBAD00E77017074DC15417 EA8511AE2CA899D68DB423AD751B446C6F958507 R37TT7VDWGK26FUDTFANGUJBFKYDGAV4ARK3EEI 9EDCAE6F50EFE09F0837DA66A8B88C13 5KCRDLRMVCM5NDNUEOWXKG2ENRXZLBIH 01D00FBBA6A0903499385151BF678CDF4294986CF5B76A6A5660AC5834FA429E12861BC5174C7648CA4086B0FCE3F211F80423824E9A9589A20FC43A81D8B752 3D3E1DB92A2030B1287769AAD2190DD69EED5911644EC6E7BB7AEAB5FC701BE3"
check "$TEST_RESULT" "$TEST_EXPECTED"

new_test "test with 1Kb data file:    "
awk 'BEGIN{ for(i=0; i<256*4; i++) { printf("%c", i%256) } }' > test1K.data
TEST_RESULT=$( $rhash --printf "%f %C %M %H %E %G %T %A %W\n" test1K.data 2>/dev/null )
TEST_EXPECTED="test1K.data B70B4C26 B2EA9F7FCEA831A4A63B213F41A8855B 5B00669C480D5CFFBDFA8BDBA99561160F2D1B77 5AE257C47E9BE1243EE32AABE408FB6B 890BB3EE5DBE4DA22D6719A14EFD9109B220607E1086C1ABBB51EEAC2B044CBB 4OQY25UN2XHIDQPV5U6BXAZ47INUCYGIBK7LFNI LMAGNHCIBVOP7PP2RPN2TFLBCYHS2G3X D606B7F44BD288759F8869D880D9D4A2F159D739005E72D00F93B814E8C04E657F40C838E4D6F9030A8C9E0308A4E3B450246250243B2F09E09FA5A24761E26B"
check "$TEST_RESULT" "$TEST_EXPECTED" .
# test reversed GOST hashes and verification of them
TEST_RESULT=$( $rhash --simple --gost --gost-cryptopro --gost-reverse test1K.data )
TEST_EXPECTED="test1K.data  bb4c042bacee51bbabc186107e6020b20991fd4ea119672da24dbe5deeb30b89  06cc52d9a7fb5137d01667d1641683620060391722a56222bb4b14ab332ec9d9"
check "$TEST_RESULT" "$TEST_EXPECTED" .
TEST_RESULT=$( $rhash --simple --gost --gost-cryptopro --gost-reverse test1K.data | $rhash -vc - 2>/dev/null | grep test1K.data )
match "$TEST_RESULT" "^test1K.data *OK"

# Test the SFV format using test1K.data from the previous test
new_test "test default format:        "
$rhash test1K.data | (
  read l; match_line "$l" "^; Generated by RHash"
  read l; match_line "$l" "^; Written by"
  read l; match_line "$l" "^;\$"
  read l; match_line "$l" "^; *1024  [0-9:\.]\{8\} [0-9-]\{10\} test1K.data\$"
  read l; match_line "$l" "^test1K.data B70B4C26\$"
) > match_err.log
[ ! -s match_err.log ] && echo Ok || echo Failed && cat match_err.log
rm -f match_err.log

new_test "test %x, %b, %B modifiers:  "
TEST_RESULT=$( echo -n "a" | $rhash -p '%f %s %xC %bc %bM %Bh %bE %bg %xT %xa %bW\n' - )
TEST_EXPECTED="(stdin) 1 E8B7BE43 5c334qy BTAXLOOA6G3KQMODTHRGS5ZGME hvfkN/qlp/zhXR3cuerq6jd2Z7g= XXSSZMY54M7EMJC6AX55XVX3EQ 2qwfhhrwprtotsekqapwmsjutqqyog2ditdkk47yjh644yxtctoq 16614B1F68C5C25EAF6136286C9C12932F4F73E87E90A273 86f7e437faa5a7fce15d1ddcb9eaeaea377667b8 RLFCMATZFLWG6ENGOIDFGH5X27YN75MUCMKF42LTYRIADUAIPNBNCG6GIVATV37WHJBDSGRZCRNFSGUSEAGVMAMV4U5UPBME7WXCGGQ"
check "$TEST_RESULT" "$TEST_EXPECTED"

new_test "test special characters:    "
TEST_RESULT=$( echo | $rhash -p '\63\1\277\x0\x1\t\\ \x34\r\n' - )
TEST_EXPECTED=$( printf '\63\1\277\\x0\1\t\\ 4\r\n' )
check "$TEST_RESULT" "$TEST_EXPECTED"

new_test "test eDonkey link:          "
TEST_RESULT=$( echo -n "a" | $rhash -p '%f %L %l\n' - )
TEST_EXPECTED="(stdin) ed2k://|file|(stdin)|1|BDE52CB31DE33E46245E05FBDBD6FB24|h=Q336IN72UWT7ZYK5DXOLT2XK5I3XMZ5Y|/ ed2k://|file|(stdin)|1|bde52cb31de33e46245e05fbdbd6fb24|h=q336in72uwt7zyk5dxolt2xk5i3xmz5y|/"
check "$TEST_RESULT" "$TEST_EXPECTED" .
# here we should test checking of ed2k links but it is currently unsupported
TEST_RESULT=$( $rhash -L test1K.data | $rhash -vc - 2>/dev/null | grep test1K.data )
match "$TEST_RESULT" "^test1K.data *OK"

if [ "$FULL_TEST" = 1 ]; then
  new_test "test all hash options:      "
  errors=0
  for opt in $HASHOPT ; do
    TEST_RESULT=$( echo -n "a" | $rhash --$opt --simple - )
    match "$TEST_RESULT" "\b[0-9a-z]\{8,128\}\b" . || errors=$((errors+1))
#    TEST_RESULT=$( echo -n "a" | $rhash --$opt --sfv - | grep -v '^;' )
#    match "$TEST_RESULT" "\b[0-9a-zA-Z]\{8,128\}\b" . || errors=$((errors+1))
#    TEST_RESULT=$( echo -n "a" | $rhash --$opt --bsd - )
#    match "$TEST_RESULT" "\b[0-9a-z]\{8,128\}$" . || errors=$((errors+1))
  done
  check $errors 0
fi

new_test "test checking all hashes:   "
TEST_RESULT=$( $rhash --simple -a test1K.data | $rhash -vc - 2>/dev/null | grep test1K.data )
match "$TEST_RESULT" "^test1K.data *OK"

new_test "test checking magnet link:  "
TEST_RESULT=$( $rhash --magnet -a test1K.data | $rhash -vc - 2>&1 | grep -i '\(warn\|test1K.data\)' )
TEST_EXPECTED="^test1K.data *OK"
match "$TEST_RESULT" "$TEST_EXPECTED"

new_test "test bsd format checking:   "
TEST_RESULT=$( $rhash --bsd -a test1K.data | $rhash -vc - 2>&1 | grep -i '\(warn\|err\)' )
check "$TEST_RESULT" ""

new_test "test checking w/o filename: "
$rhash -p '%c\n%m\n%e\n%h\n%g\n%t\n%a\n' test1K.data > test1K.data.hash
TEST_RESULT=$( $rhash -vc test1K.data.hash 2>&1 | grep -i '\(warn\|err\)' )
TEST_EXPECTED=""
check "$TEST_RESULT" "$TEST_EXPECTED"

new_test "test checking embedded crc: "
echo -n 'A' > 'test_[D3D99E8B].data' && echo -n 'A' > 'test_[D3D99E8C].data'
# first verify checking an existing crc32 while '--embed-crc' option is set
TEST_RESULT=$( $rhash -C --simple 'test_[D3D99E8B].data' | $rhash -vc --embed-crc - 2>/dev/null | grep data )
match "$TEST_RESULT" "^test_.*OK" .
TEST_RESULT=$( $rhash -C --simple 'test_[D3D99E8C].data' | $rhash -vc --embed-crc - 2>/dev/null | grep data )
match "$TEST_RESULT" "^test_.*ERROR, embedded CRC32 should be" .
# second verify --check-embedded option
TEST_RESULT=$( $rhash --check-embedded 'test_[D3D99E8B].data' 2>/dev/null | grep data )
match "$TEST_RESULT" "test_.*OK" .
TEST_RESULT=$( $rhash --check-embedded 'test_[D3D99E8C].data' 2>/dev/null | grep data )
match "$TEST_RESULT" "test_.*ERR" .
mv 'test_[D3D99E8B].data' 'test.data'
# at last test --embed-crc with --embed-crc-delimiter options
TEST_RESULT=$( $rhash --simple --embed-crc --embed-crc-delimiter=_ 'test.data' 2>/dev/null )
check "$TEST_RESULT" "d3d99e8b  test_[D3D99E8B].data"
rm 'test_[D3D99E8B].data' 'test_[D3D99E8C].data'

new_test "test wrong sums detection:  "
echo -n WRONG | $rhash -p '%c\n%m\n%e\n%h\n%g\n%t\n%a\n%w\n' - > test1K.data.hash
TEST_RESULT=$( $rhash -vc test1K.data.hash 2>&1 | grep 'OK' )
check "$TEST_RESULT" ""
rm test1K.data.hash

new_test "test *accept options:       "
rm -rf test_dir/
mkdir test_dir 2>/dev/null && touch test_dir/file.txt test_dir/file.bin
if [ -n "$MSYSTEM" ]; then SLASH=//; else SLASH="/"; fi # correctly handle MSYS posix path conversion
TEST_RESULT=$( $rhash -rC --simple --accept=.bin --path-separator=$SLASH test_dir )
check "$TEST_RESULT" "00000000  test_dir/file.bin" .
TEST_RESULT=$( $rhash -rC --simple --accept=.txt --path-separator=\\ test_dir )
check "$TEST_RESULT" "00000000  test_dir\\file.txt" .
# test --crc-accept and also --path-separator options
# note: path-separator doesn't affect the following '( Verifying <filepath> )' message
TEST_RESULT=$( $rhash -rc --crc-accept=.bin test_dir 2>/dev/null | sed -n '/Verifying/s/-//gp' )
match "$TEST_RESULT" "( Verifying test_dir.file\\.bin )"
rm -rf test_dir/

new_test "test creating torrent file: "
TEST_RESULT=$( $rhash --btih --torrent --bt-private --bt-piece-length=512 --bt-announce=http://tracker.org/ 'test1K.data' 2>/dev/null )
check "$TEST_RESULT" "29f7e9ef0f41954225990c513cac954058721dd2  test1K.data"
rm test1K.data.torrent

# Big file test
new_test "test with 512 KiB of data:  "
TEST_512K_RESULT=$( awk 'BEGIN{ for(i=256*2048-1; i>=0; i--) { printf("%c", i%256); } }' | $rhash --simple -CHMETAGW - )
TEST_512K_EXPECTED="(stdin)  f26e5571  56591858ed59c3122cdeaeb5d32d3592  f629b470578236e1b0edb96028eb9af728cc27fc  vkg7atf26rt5at4jry63lhxmjn5dotww4xedslq  56fd3c004775bc0c667f3f5e23a092f9  6gnw6lf6ve5hdxxytdhhfjiyhm3m66w7  e8843c19609f0b72cb25e4c5b1a1ddfe7078972d89ab78f980b3f6c711f9cabfcbf3ac5e66661d9638a82d96ed5b51dc34e27d402c35cbb296d01cb31976af5d  2cdbbbd51999052cc783637bd28d52e20ced0fb75a908401e696a5fd085157ec"
check "$TEST_512K_RESULT" "$TEST_512K_EXPECTED"
rm -f test1K.data
