#!/bin/bash
api="https://api.revanced.app/v2/patches/latest"

req() {
    wget --header="User-Agent: Mozilla/5.0 (Android 13; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0" \
         --header="Content-Type: application/octet-stream" \
         --header="Accept-Language: en-US,en;q=0.9" \
         --header="Connection: keep-alive" \
         --header="Upgrade-Insecure-Requests: 1" \
         --header="Cache-Control: max-age=0" \
         --header="Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" \
         --keep-session-cookies --timeout=30 -nv -O "$@"
}

get_latest_version() {
    grep -Evi 'alpha|beta' | grep -oPi '\b\d+(\.\d+)+(?:\-\w+)?(?:\.\d+)?(?:\.\w+)?\b' | sort -ur | awk 'NR==1'
}

get_supported_version() {
    jq -r --arg pkg_name "$1" '.. | objects | select(.name == "\($pkg_name)" and .versions != null) | .versions[-1]' | uniq
}

get_apkmirror_version() {
    grep 'fontBlack' | sed -n 's/.*>\(.*\)<\/a> <\/h5>.*/\1/p' | sed 20q
}

# Best but sometimes not work because APKmirror protection 
apkmirror() {
    org="$1" name="$2" package="$3" arch="$4" 
    local regexp='.*APK\(.*\)'$arch'\(.*\)nodpi<\/div>[^@]*@\([^<]*\)'
    version=$(req - 2>/dev/null $api | get_supported_version "$package")
    url="https://www.apkmirror.com/uploads/?appcategory=$name"
    version="${version:-$(req - $url | get_apkmirror_version | get_latest_version)}"
    url="https://www.apkmirror.com/apk/$org/$name/$name-${version//./-}-release"
    url="https://www.apkmirror.com$(req - $url | tr '\n' ' ' | sed -n 's#.*href="\(.*apk/[^"]*\)"'$regexp'.*#\1#p')"
    url="https://www.apkmirror.com$(req - $url | tr '\n' ' ' | sed -n 's#.*href="\(.*key=[^"]*\)">.*#\1#p')"
    url="https://www.apkmirror.com$(req - $url | tr '\n' ' ' | sed -n 's#.*href="\(.*key=[^"]*\)">.*#\1#g;s#amp;##g;p')"
    req $name-v$version.apk $url
}

apkmirror() {
    org="$1" name="$2" package="$3" arch="$4" 
    version=$(req - 2>/dev/null $api | get_supported_version "$package")
    url="https://www.apkmirror.com/uploads/?appcategory=$name"
    version="${version:-$(req - $url | get_apkmirror_version | get_latest_version )}"
    url="https://www.apkmirror.com/apk/$org/$name/$name-${version//./-}-release"
    url="https://www.apkmirror.com$(req - $url | grep '>nodpi<' -B15 | grep '>'$arch'<' -B13 | grep '>APK<' -B5 \
                                               | perl -ne 'print "$1\n" if /.*href="([^"]*download\/)".*/ && ++$i == 1;')"
    url="https://www.apkmirror.com$(req - $url | perl -ne 'print "$1\n" if /.*href="([^"]*key=[^"]*)".*/')"
    url="https://www.apkmirror.com$(req - $url | perl -ne 's/amp;//g; print "$1\n" if /.*href="([^"]*key=[^"]*)".*/')"
    req $name-v$version.apk $url
}

apkmirror() {
    org="$1" name="$2" package="$3" arch="$4"
    version=$(req - 2>/dev/null $api | get_supported_version "$package")
    url="https://www.apkmirror.com/uploads/?appcategory=$name"
    version="${version:-$(req - $url | pup 'div.widget_appmanager_recentpostswidget h5 a.fontBlack text{}' | get_latest_version)}"
    url="https://www.apkmirror.com/apk/$org/$name/$name-${version//./-}-release"
    url="https://www.apkmirror.com$( req - $url | pup -p --charset utf-8 ':parent-of(:parent-of(span:contains("APK")))' \
                                                | pup -p --charset utf-8 ':parent-of(div:contains("'$arch'"))' \
                                                | pup -p --charset utf-8 ':parent-of(div:contains("nodpi")) a.accent_color attr{href}' \
                                                | sed 1q )"
    url="https://www.apkmirror.com$( req - $url | pup -p --charset utf-8 'a.downloadButton attr{href}')"
    url="https://www.apkmirror.com$( req - $url | pup -p --charset utf-8 'a[data-google-vignette="false"][rel="nofollow"] attr{href}')"
    req $name-v$version.apk $url
}

# X not work (maybe more)
uptodown() {
    name=$1 package=$2
    version=$(req - 2>/dev/null $api | get_supported_version "$package")
    url="https://$name.en.uptodown.com/android/versions"
    version="${version:-$(req - 2>/dev/null "$url" | sed -n 's/.*class="version">\([^<]*\)<.*/\1/p' | get_latest_version)}"
    url=$(req - $url | tr '\n' ' ' \
                     | sed -n 's/.*data-url="\([^"]*\)".*'$version'<\/span>[^@]*@\([^<]*\).*/\1/p' \
                     | sed 's#/download/#/post-download/#g')
    url="https://dw.uptodown.com/dwn/$(req - $url | sed -n 's/.*class="post-download".*data-url="\([^"]*\)".*/\1/p')"
    req $name-v$version.apk $url
}

uptodown() {
    name=$1 package=$2
    version=$(req - 2>/dev/null $api | get_supported_version "$package")
    url="https://$name.en.uptodown.com/android/versions"
    version="${version:-$(req - 2>/dev/null $url | grep -oP 'class="version">\K[^<]+' | get_latest_version)}"
    url=$(req - $url | grep -B3 '"version">'$version'<' \
                     | perl -ne 's/\/download\//\/post-download\//g ; print "$1\n" if /.*data-url="([^"]*)".*/ && ++$i == 1;')
    url="https://dw.uptodown.com/dwn/$(req - $url | perl -ne ' print "$1\n" if /.*"post-download" data-url="([^"]*)".*/')"
    req $name-v$version.apk $url
}

uptodown() {
    name="$1" package="$2"
    version=$(req - 2>/dev/null $api | get_supported_version "$package")
    url="https://$name.en.uptodown.com/android/versions"
    version="${version:-$(req - 2>/dev/null $url | pup 'div#versions-items-list > div span.version text{}' | get_latest_version)}"
    url=$(req - $url | pup -p --charset utf-8 ':parent-of(span:contains("'$version'"))' \
                     | pup -p --charset utf-8 'div[data-url]' attr{data-url} \
                     | sed 's#/download/#/post-download/#g;q')
    url="https://dw.uptodown.com/dwn/$(req - "$url" | pup -p --charset utf-8 'div[class="post-download"]' attr{data-url})"
    req $name-v$version.apk $url
}

# Tiktok not work because not available version supported 
apkpure() {
    name=$1 package=$2
    version=$(req - 2>/dev/null $api | get_supported_version "$package")
    url="https://apkpure.net/$name/$package/versions"
    version="${version:-$(req - $url | sed -n 's/.*data-dt-version="\([^"]*\)".*/\1/p' | sed 10q | get_latest_version)}"
    url="https://apkpure.net/$name/$package/download/$version"
    url=$(req - $url | sed -n 's/.*href="\(.*\/APK\/'$package'[^"]*\).*/\1/p' | uniq)
    req $name-v$version.apk $url
}

apkpure() {
    name=$1 package=$2
    url="https://apkpure.net/$name/$package/versions"
    version=$(req - 2>/dev/null $api | get_supported_version "$package")
    version="${version:-$(req - $url | grep -oP 'data-dt-version="\K[^"]*' | sed 10q | get_latest_version)}"
    url="https://apkpure.net/$name/$package/download/$version"
    url=$(req - $url | perl -ne 'print "$1\n" if /.*href="([^"]*\/APK\/'$package'[^"]*)".*/ && ++$i == 1;')
    req $name-v$version.apk $url
}

apkpure() {
    name="$1" package="$2"
    version=$(req - 2>/dev/null $api | get_supported_version "$package")
    url="https://apkpure.net/$name/$package/versions"
    version="${version:-$(req - $url | pup 'div.ver-item > div.ver-item-n text{}' | get_latest_version)}"
    url="https://apkpure.net/$name/$package/download/$version"
    url=$(req - $url | pup -p --charset utf-8 'a[href*="APK/'$package'"] attr{href}' | sed 1q)
    req $name-v$version.apk $url
}

# Usage examples
apkmirror "google-inc" \
          "youtube-music" \
          "com.google.android.apps.youtube.music" \
          "arm64-v8a"

uptodown "youtube-music" \
         "com.google.android.apps.youtube.music"

apkpure "youtube-music" \
        "com.google.android.apps.youtube.music"
