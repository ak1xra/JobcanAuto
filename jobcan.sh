#!/bin/sh

PROGNAME=$(basename $0)
VERSION="1.0"
HELP_MSG="You can see help by './$PROGNAME -h'."

# Help message
usage() {
    echo "Usage: $PROGNAME -a arg [-b arg] param"
    echo
    echo "options:"
    echo "  -h, --help"
    echo "      --version"
    echo "  -m, --mail <ARG>     <required> mail address"
    echo "  -p, --password <string>  <required> password"
    echo "  -t, --type <string>  <required> (start|end)"
    echo
    exit 1
}

# Search options
for OPT in "$@"
do
    case "$OPT" in
	# Help
	'-h'|'--help' )
	    usage
	    exit 1
	    ;;
	# Version
	'--version' )
	    echo $VERSION
	    exit 1
	    ;;
	# Mail address
	'-m'|'--mail' )
	    FLG_M=1
	    # No argument
	    if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
		echo "$PROGNAME:「$1」Argument is required" 1>&2
		exit 1
	    fi
	    ARG_M="$2"
	    shift 2
	    ;;
	# Password
	'-p'|'--password' )
	    FLG_P=1
	    # No argument
	    if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
		echo "$PROGNAME:「$1」Argument is required" 1>&2
		exit 1
	    fi
	    ARG_P="$2"
	    shift 2
	    ;;
	# Type
	'-t'|'--type' )
	    FLG_T=1
	    # No argument
	    if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
		echo "$PROGNAME:「$1」Argument is required" 1>&2
		exit 1
	    fi
	    # Invalid argument
	    if test "$2" != "start" && test "$2" != "end"; then
		echo "$PROGNAME:「$1」invalid argment. Only (start|end) is valid for this option's argment" 1>&2
		exit 1
	    fi
	    
	    ARG_T="$2"
	    shift 2
	    ;;
	'--'|'-' )
	    # Only "-" or "--"
	    shift 1
	    param+=( "$@" )
	    break
	    ;;
	-*)
	    echo "$PROGNAME: 「$(echo $1 | sed 's/^-*//')」No that option. See help by './$PROGNAME -h'" 1>&2
	    exit 1
	    ;;
    esac
done

# No "-m" option
if [ -z $FLG_M ]; then
    echo "$PROGNAME:'-m' option is required." 1>&2
    echo $HELP_MSG 1>&2
    exit 1
fi

# No "-p" option
if [ -z $FLG_P ]; then
    echo "$PROGNAME:'-p' option is required." 1>&2
    echo $HELP_MSG 1>&2
    exit 1
fi

# No "-t" option
if [ -z $FLG_T ]; then
    echo "$PROGNAME:'-t' option is required." 1>&2
    echo $HELP_MSG 1>&2
    exit 1
fi

# Preparation
rm -r .tmp
mkdir .tmp

# Login
encodedMailAddress=`ruby -r cgi -e "puts CGI.escape(\""$ARG_M"\")"`

curl -c ./.tmp/cookie.txt -X POST -d "client_id=smartdrive1001&email=$encodedMailAddress&password=$ARG_P&save_login_info=0&url=https%3A%2F%2Fssl.jobcan.jp%2Femployee%2F&login_type=1: undefined" "https://ssl.jobcan.jp/login/pc-employee"
curl -b ./.tmp/cookie.txt "https://ssl.jobcan.jp/employee/" > ./.tmp/login.html

# Search token
cat ./.tmp/login.html | grep "token" > ./.tmp/token.txt

## ex. <input type="hidden" class="token" name="token" value="0047f40392be20d56e7e70533cfed055">
sed -i '' -e "s/^.*value=\"\(.*\)\"\>$/\1/g" ./.tmp/token.txt
token=`cat ./.tmp/token.txt`

# Search group_id
cat ./.tmp/login.html | grep "<option value=" > ./.tmp/group_id.txt

## ex. <option value="9" >エンジニアリング-&gt;アプリ</option>
sed -i '' -e "s/^.*value=\"\(.*\)\".*$/\1/g" ./.tmp/group_id.txt
group_id=`head -n 1 ./.tmp/group_id.txt`

# Create parameters
if test $FLG_T = "start"; then
    aditItem="work_start"
elif test $FLG_T = "end"; then
    aditItem="work_end"
fi

param="\"is_yakin=0&adit_item=$aditItem&notice=&token=$token&adit_group_id=$group_id\""
echo $param

# POST
statusCode=`eval curl -X POST -b -d $param cookie.txt "https://ssl.jobcan.jp/employee/index/adit" -I -o /dev/null -w '%{http_code}' -s`

if test $statusCode -eq 200; then
    echo "Succeeded!"
else
    echo "Failed... Jobcan status code: $statusCode"
fi

# Clean up
rm -r .tmp