#! /bin/sh
#
# spam filter programs by m-ito@myh.no-ip.org
#
#----------------------------------------------------------------------
#
# functions
#
function show_help () {
	echo "Usage : $0 [-w|--white|-b|--black] [-v|--vacuum] [file ...]"
	echo "Add data to database."
	echo "  -w, --white  add data to white database."
	echo "  -b, --black  add data to black database."
	echo "  -v, --vacuum vacuum after add."
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
maxlength=50; export maxlength
tab=`echo -n -e '\t'`
zsp=`echo -n -e '\241\241'`
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
echo "begin;" >/tmp/sf_add.1.$$.tmp
#
for i in `cat ${file} |\
	nkf -e -X |\
	kakasi -w -ieuc -oeuc |\
	sed -e "s/${zsp}/ /g;s/${tab}/ /g" |\
	awk '{gsub(/ /,"\n");print}' |\
	awk 'BEGIN{\
		maxlength = ENVIRON["maxlength"];\
	}\
	{\
		if (length($0) <= maxlength){\
			print;\
		}\
	}' |\
	tr -d '"\000-\011\013-\037\177' |\
	sort |\
	uniq -c |\
	sed -e "s/^ *//;s/[ ${tab}][ ${tab}]*/,/"`
do
	count=`echo $i | cut -d, -f1`
	term=`echo $i | cut -d, -f2-`
	if [ "X${term}" = "X" ]
	then
		: # do nothing
	else
		result=`echo "select term from ${table} where term=\"${term}\";" |\
			sqlite3 ${SFDB_PATH}`
		if [ "X${result}" = "X" ]
		then
			echo "insert into ${table} values (\"${term}\",${count});" >>/tmp/sf_add.1.$$.tmp
		else
			echo "update ${table} set count=count+${count} where term=\"${term}\"; " >>/tmp/sf_add.1.$$.tmp
		fi
	fi
done
#
echo "end;" >>/tmp/sf_add.1.$$.tmp
cat /tmp/sf_add.1.$$.tmp |\
sqlite3 ${SFDB_PATH}
#
result=`echo "select sum(count) from ${table};" |\
	sqlite3 ${SFDB_PATH}`
echo "update t_total set count=${result} where tablenm=\"${table}\";" |\
sqlite3 ${SFDB_PATH}
#
echo ${vacuum} |\
sqlite3 ${SFDB_PATH}
#
rm /tmp/sf_add.*.$$.tmp
#
exit 0
