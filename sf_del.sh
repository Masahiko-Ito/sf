#! /bin/sh
trap "rm /tmp/sf_del.*.$$.tmp; exit 1" INT TERM
#
# spam filter programs by m-ito@myh.no-ip.org
#
#----------------------------------------------------------------------
#
# functions
#
function show_help () {
	echo "Usage : $0 [-w|--white|-b|--black] [-v|--vacuum] [file ...]"
	echo "Delete data from database."
	echo "  -w, --white  delete data from white database."
	echo "  -b, --black  delete data from black database."
	echo "  -v, --vacuum vacuum after delete."
}
#----------------------------------------------------------------------
#
# main routin
#
if [ "X$1" = "X-h" -o "X$1" = "X--help" ]
then
	show_help
	exit 0
fi
#
if [ "X${SFDIR}" = "X" ]
then
	SFDIR=${HOME}/.sf
fi
#
if [ "X${SFDB}" = "X" ]
then
	SFDB=sf.db
fi
#
SFDB_PATH=${SFDIR}/${SFDB}
#
maxlength=20; export maxlength
tab=`echo -n -e '\t'`
##zsp=`echo -n -e '\241\241'`
#
table=""
file=""
vacuum=""
#
while [ $# != 0 ]
do
	case $1 in
	-w|--white )
        	table="t_white"
		;;
	-b|--black )
        	table="t_black"
		;;
	-v|--vacuum )
        	vacuum="vacuum;"
		;;
	* )
		file="${file} $1"
		;;
	esac
	shift
done
#
if [ "X${table}" = "X" ]
then
	show_help
	exit 0
fi
#
echo "begin;" >/tmp/sf_del.1.$$.tmp
#
for i in `cat ${file} |\
	nkf -e -X -Z0 -Z1 |\
	tr '[:cntrl:]' "\n" |\
	nkf -I |\
	sed -e '/Content-Transfer-Encoding: *base64/,$d' |\
        kakasi -w -ieuc -oeuc |\
        tr -s ' ' |\
        tr " " "\n" |\
        tr -d '";' |\
        tr -d "'" |\
        awk 'BEGIN{ \
                maxlength = ENVIRON["maxlength"]; \
        } \
        { \
                if (length($0) > 0 && length($0) <= maxlength){ \
                        print; \
                } \
        }' |\
	tr '[:cntrl:]' "\n" |\
	nkf -I |\
        sort |\
        uniq -c |\
        sed -e "s/^[ ${tab}]*//;s/[ ${tab}][ ${tab}]*/,/"`
do
	count=`echo $i | cut -d, -f1`
	term=`echo $i | cut -d, -f2- | nkf -E -w`
	if [ "X${term}" = "X" ]
	then
		: # do nothing
	else
		result=`echo "select count from ${table} where term=\"${term}\";" |\
			sqlite3 ${SFDB_PATH}`
		if [ "X${result}" = "X" ]
		then
			: # do nothing
		else
			if [ ${result} -le ${count} ]
			then
				echo "delete from ${table} where term=\"${term}\";" >>/tmp/sf_del.1.$$.tmp
			else
				echo "update ${table} set count=count-${count} where term=\"${term}\";" >>/tmp/sf_del.1.$$.tmp
			fi
		fi
	fi
done
#
echo "end;" >>/tmp/sf_del.1.$$.tmp
cat /tmp/sf_del.1.$$.tmp |\
sqlite3 ${SFDB_PATH}
#
result=`echo "select sum(count) from ${table};" |\
	sqlite3 ${SFDB_PATH}`
if [ "X${result}" = "X" ]
then
	result=0
fi
echo "update t_total set count=${result} where tablenm=\"${table}\";" |\
	sqlite3 ${SFDB_PATH}
#
echo ${vacuum} |\
sqlite3 ${SFDB_PATH}
#
rm /tmp/sf_del.*.$$.tmp
#
exit 0
