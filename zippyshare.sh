#!/bin/bash
# @Description: zippyshare.com file download script
# @Author: Live2x
# @URL: https://github.com/img2tab/zippyshare
# @Version: 201904200001
# @Date: 2019-04-20
# @Usage: ./zippyshare.sh url

if [ -z "${1}" ]
then
    echo "usage: ${0} url"
    echo "batch usage: ${0} url-list.txt"
    echo "url-list.txt is a file that contains one zippyshare.com url per line"
    exit
fi

function zippydownload()
{
    prefix="$( echo -n "${url}" | cut -c "11,12,31-38" | sed -e 's/[^a-zA-Z0-9]//g' )"
    cookiefile="${prefix}-cookie.tmp"
    infofile="${prefix}-info.tmp"

    # loop that makes sure the script actually finds a filename
    filename=""
    retry=0
    while [ -z "${filename}" -a ${retry} -lt 10 ]
    do
        let retry+=1
        rm -f "${cookiefile}" 2> /dev/null
        rm -f "${infofile}" 2> /dev/null
         wget -O "${infofile}" "${url}" \
        --cookies=on \
        --keep-session-cookies \
        --save-cookies="${cookiefile}" \
        --quiet
        filename="$( grep "getElementById..dlbutton...href" "${infofile}" | cut -d"/" -f5 | sed "s/\";//g" )"
    done

    if [ "${retry}" -ge 10 ]
    then
        echo "could not download file from ${url}"
        rm -f "${cookiefile}" 2> /dev/null
        rm -f "${infofile}" 2> /dev/null
        return 1
    fi

    # Get cookie
    if [ -f "${cookiefile}" ]
    then 
        jsessionid="$( cat "${cookiefile}" | grep "JSESSIONID" | cut -f7)"
    else
        echo "can't find cookie file for ${prefix}"
        exit 1
    fi

    if [ -f "${infofile}" ]
    then
        # Get url algorithm
        a="$( grep 'var a = ' "${infofile}" | tail -n 1 | cut -d' ' -f8 | cut -d';' -f1 )"
        a="$(( a / 3))"
        b="$( grep 'var b = ' "${infofile}" | tail -n 1 | cut -d' ' -f8 | cut -d';' -f1 )"
        dlbutton="$( grep 'document.getElementById..dlbutton' "${infofile}" | tail -n 1 | cut -d'=' -f2 | cut -d'(' -f2 | cut -d')' -f1 | grep -o "[0-9]*" )"
        result="$(( ${dlbutton} % ${b} + ${a} ))"
        if [ -z "${result}" ]; then
           echo "could not get zippyshare url algorithm"
           exit 1
        fi

        # Get ref, server, id
        ref="$( cat "${infofile}" | grep 'property="og:url"' | cut -d'"' -f4 | grep -o "[^ ]\+\(\+[^ ]\+\)*" )"

        server="$( echo "${ref}" | cut -d'/' -f3 )"

        id="$( echo "${ref}" | cut -d'/' -f5 )"
    else
        echo "can't find info file for ${prefix}"
        exit 1
    fi

    # Build download url
    dl="https://${server}/d/${id}/${result}/${filename}"

    # Set browser agent
    agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36"

    echo "${filename}"

    # Start download file
     wget -c -O "${filename}" "${dl}" \
    -q --show-progress \
    --referer="${ref}" \
    --cookies=off --header "Cookie: JSESSIONID=${jsessionid}" \
    --user-agent="${agent}"
    rm -f "${cookiefile}" 2> /dev/null
    rm -f "${infofile}" 2> /dev/null
}

if [ -f "${1}" ]
then
    for url in $( cat "${1}" | grep -i 'zippyshare.com' )
    do
        zippydownload "${url}"
    done
else
    url="${1}"
    zippydownload "${url}"
fi
