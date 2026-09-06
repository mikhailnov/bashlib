#!/bin/sh
#
# run_tests.sh -- self-contained test suite for bashlib functions.
#
# bashlib parses QUERY_STRING, HTTP_COOKIE and stdin at source time, so
# every case sources the library in a pristine environment (env -i) with
# a controlled CGI environment.  stdout of each case is compared
# byte-for-byte with the expected output (trailing newline included).
#
# Usage: tests/run_tests.sh   (or: make check from the top directory)

PASS=0
FAIL=0
TOTAL=0

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 1
LIB=$here/bashlib

if [ ! -f "$LIB" ]; then
	echo "bashlib not found at $LIB -- run ./configure first" >&2
	exit 1
fi

BASH_PROG=$(command -v "${BASH:-bash}" 2>/dev/null) || BASH_PROG=
if [ -z "$BASH_PROG" ] || [ ! -x "$BASH_PROG" ]; then
	echo "bash interpreter not found" >&2
	exit 1
fi

TMP=${TMPDIR:-/tmp}/bashlib-tests.$$
(umask 077 && mkdir "$TMP") || { echo "cannot create $TMP" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT
trap 'rm -rf "$TMP"; exit 1' INT TERM

# make_case <code> -- write a snippet that sources bashlib then runs <code>
make_case() {
	printf '. "%s"\n%s\n' "$LIB" "$1" > "$TMP/case.sh"
}

# bl <code> [ENV=VAL ...] -- run a case with empty stdin (plain GET request)
bl() {
	code=$1; shift
	make_case "$code"
	env -i "$@" "$BASH_PROG" --norc "$TMP/case.sh" >"$TMP/got" 2>"$TMP/err" </dev/null
}

# bl_post <data> <code> [ENV=VAL ...] -- run a case with <data> on stdin (POST)
bl_post() {
	data=$1; code=$2; shift 2
	make_case "$code"
	printf '%s' "$data" | env -i "$@" "$BASH_PROG" --norc "$TMP/case.sh" >"$TMP/got" 2>"$TMP/err"
}

# show <file> -- render file bytes with visible line ends
show() {
	awk '{ printf "%s\\n", $0 } END { if (NR == 0) print "(empty)" }' "$1"
}

# ok <description> <expected> -- compare stdout of the last bl*() run with
# <expected>, a printf %b string ("line1\nline2\n").
ok() {
	desc=$1; exp=$2
	TOTAL=$((TOTAL + 1))
	printf '%b' "$exp" > "$TMP/want"
	if cmp -s "$TMP/want" "$TMP/got"; then
		PASS=$((PASS + 1))
		printf 'ok %2d - %s\n' "$TOTAL" "$desc"
	else
		FAIL=$((FAIL + 1))
		printf 'not ok %2d - %s\n' "$TOTAL" "$desc"
		printf '      expected: %s\n' "$(show "$TMP/want")"
		printf '      actual:   %s\n' "$(show "$TMP/got")"
		if [ -s "$TMP/err" ]; then
			printf '      stderr:\n'
			sed 's/^/        /' "$TMP/err"
		fi
	fi
}

echo "bashlib test suite"
echo "  library: $LIB"
echo

# --- version ------------------------------------------------------------

bl 'version'
ok 'version prints name and release' 'bashlib, version 2\n'

bl 'version_html'
ok 'version_html prints html link and version' \
   '<a href="http://sevenroot.org/dlc/2000/12/bashlib">bashlib</a>,version 2\n'

# --- GET parameter parsing ----------------------------------------------

bl 'param name' 'QUERY_STRING=name=value'
ok 'GET: single name=value parameter' 'value\n'

bl 'param a; param b; param c' 'QUERY_STRING=a=1&b=2;c=3'
ok 'GET: parameters separated by & and ;' '1\n2\n3\n'

bl 'param q' 'QUERY_STRING=q=hello+world'
ok 'GET: + decodes to space' 'hello world\n'

bl 'param q' 'QUERY_STRING=q=one+two+three+four'
ok 'GET: every + decodes to space, not only the first one' 'one two three four\n'

bl 'param q' 'QUERY_STRING=q=a++b'
ok 'GET: consecutive + decode to consecutive spaces' 'a  b\n'

bl 'param w' 'QUERY_STRING=w=hello%20world'
ok 'GET: %XX hex escapes decode' 'hello world\n'

bl 'param p' 'QUERY_STRING=p=b%2Bc%2Bd'
ok 'GET: every encoded %2B is returned as space' 'b c d\n'

bl 'param s' 'QUERY_STRING=s=%D0%BF%D1%80%D0%B8%D0%B2%D0%B5%D1%82'
ok 'GET: multi-byte utf-8 %XX sequences decode' 'привет\n'

bl 'param org' 'QUERY_STRING=org=%D0%90%D0%9E+%D0%90%D0%BB%D1%8C%D1%84%D0%B0-%D0%91%D0%B0%D0%BD%D0%BA+%D0%A1%D1%83%D0%BF%D0%B5%D1%80'
ok 'GET: literal - before %XX does not break decoding' 'АО Альфа-Банк Супер\n'

bl 'param q' 'QUERY_STRING=q=-%D0%B0y'
ok 'GET: %-escape glued after a literal - decodes fully' '-аy\n'

bl 'param q' 'QUERY_STRING=q=-start'
ok 'GET: value starting with - is not eaten' '-start\n'

bl 'param x' 'QUERY_STRING=x=50%25+off'
ok 'GET: decoded % char survives round trip' '50% off\n'

bl 'param usernamex' 'QUERY_STRING=user.name-x=1'
ok 'GET: dots and dashes are stripped from names' '1\n'

bl 'param a' 'QUERY_STRING=a='
ok 'GET: empty value yields empty string' '\n'

bl 'param | grep -c .'
ok 'no CGI input: param lists nothing' '0\n'

# --- param() ------------------------------------------------------------

bl 'param | sort' 'QUERY_STRING=b=2&a=1&c=3'
ok 'param: no arguments lists parameter names' 'a\nb\nc\n'

bl 'param FORM_a' 'QUERY_STRING=a=1'
ok 'param: FORM_ prefix is stripped from the argument' '1\n'

bl 'param foo bar baz >/dev/null
param foo'
ok 'param: set value and read it back' 'bar baz\n'

# --- safe_param() -------------------------------------------------------

bl 'safe_param s' 'QUERY_STRING=s=%24%60%3C%3E%22%25%3B%29%28%26%2B'
ok 'safe_param: shell/html metacharacters are removed' ' \n'

bl 'safe_param x' 'QUERY_STRING=x=%3Cscript%3Ealert%281%29%3C%2Fscript%3E'
ok 'safe_param: XSS payload is neutralised' 'scriptalert1/script\n'

bl 'safe_param msg' 'QUERY_STRING=msg=hello+world'
ok 'safe_param: benign text and spaces survive' 'hello world\n'

bl 'safe_param msg' 'QUERY_STRING=msg=hello+world+123'
ok 'safe_param: spaces are not lost after the first +' \
   'hello world 123\n'

# --- keywords() ---------------------------------------------------------

bl 'keywords' 'QUERY_STRING=alpha+beta+gamma'
ok 'keywords: isindex-style query becomes a keyword list' 'alpha beta gamma\n'

# --- POST via stdin -----------------------------------------------------

bl_post 'a=1&b=2' 'param a; param b'
ok 'POST: stdin is parsed as form data' '1\n2\n'

bl_post 'a=1' 'param a; param b' 'QUERY_STRING=b=2'
ok 'POST: stdin params are merged with QUERY_STRING' '1\n2\n'

# --- cookie() -----------------------------------------------------------

bl 'cookie session; cookie theme' 'HTTP_COOKIE=session=abc123; theme=dark'
ok 'cookies: HTTP_COOKIE is parsed' 'abc123\ndark\n'

bl 'cookie' 'HTTP_COOKIE=session=abc123; theme=dark'
ok 'cookie: no arguments lists cookie names (space-separated, unlike param)' \
   'session theme\n'

bl 'cookie foo bar qux >/dev/null
cookie foo'
ok 'cookie: set value and read it back' 'bar qux\n'

bl 'cookie org' 'HTTP_COOKIE=org=%D0%90%D0%BB%D1%8C%D1%84%D0%B0-%D0%91%D0%B0%D0%BD%D0%BA'
ok 'cookies: literal - before %XX does not break decoding' 'Альфа-Банк\n'

# --- set_cookie() -------------------------------------------------------

bl 'set_cookie theme light >/dev/null
set_cookie lang en >/dev/null
echo "[$bashlib_cookies]"
cookie theme
cookie lang'
ok 'set_cookie: accumulates pairs and exports them (leading space is current behaviour)' \
   '[ theme=light; lang=en]\nlight\nen\n'

# --- send_redirect() ----------------------------------------------------

bl 'send_redirect http://example.org/x'
ok 'send_redirect: emits Location header and a blank line' \
   'Location: http://example.org/x\n\n'

bl 'send_redirect' 'SERVER_NAME=www.example.org' 'SCRIPT_NAME=cgi-bin/app.cgi'
ok 'send_redirect: defaults to http://$SERVER_NAME/$SCRIPT_NAME' \
   'Location: http://www.example.org/cgi-bin/app.cgi\n\n'

# --- summary ------------------------------------------------------------

echo
echo "$PASS of $TOTAL tests passed"
if [ "$FAIL" -ne 0 ]; then
	echo "$FAIL test(s) failed" >&2
	exit 1
fi
