fetch() {
        local destfile=downloads/"$1"
        while [[ ! -f "$destfile" || `md5sum "$destfile"|cut -d\  -f1` != "$2" ]]; do
                rm "$destfile" 2>/dev/null
                wget -O "$destfile" "$3" || return $?
        done
}
