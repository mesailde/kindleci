for f in build/koreader/spec/front/unit/*.lua; do
	sed -i 's,sample\.pdf,2col.pdf,g' $f || exit $?
done
