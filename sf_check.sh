#! /bin/sh
#
# spam filter programs by m-ito@myh.no-ip.org
#
#----------------------------------------------------------------------
#
# functions
#
function show_help () {
	echo "Usage : $0 [-w|--white|-b|--black] [file ...]"
	echo "Check file."
	echo "  -w, --white  check white?"
	echo "  -b, --black  check black?"
	echo "return 0 when check is true."
	echo "return 1 when check is false."
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
w_total=`echo "select count from t_total where tablenm=\"t_white\";" |\
		sqlite3 ${SFDB_PATH}`
b_total=`echo "select count from t_total where tablenm=\"t_black\";" |\
		sqlite3 ${SFDB_PATH}`
total_score=0.0
#
for i in `cat ${file} |\
	nkf -e -X |\
	kakasi -w -ieuc -oeuc |\
	sed -e "s/${zsp}/ /g;s/${tab}/ /g" |\
	awk '{gsub(/ /,"\n");print}' |\
	awk 'BEGIN{ \
		maxlength = ENVIRON["maxlength"]; \
	} \
	{ \
		if (length($0) <= maxlength){ \
			print; \
		} \
	}' |\
	tr -d '"'`
do
	echo -n $i | tr -d '[:cntrl:]'
	echo ""
done >/tmp/sf_check.1.$$.tmp
#
for i in `cat /tmp/sf_check.1.$$.tmp |\
	sort |\
	uniq -c |\
	sed -e "s/^ *//;s/${tab}/,/"`
do
	count=`echo $i | cut -d, -f1`
	term=`echo $i | cut -d, -f2-`
#
	if [ "X${term}" = "X" ]
	then
		: # do nothing
	else
		w_count=`echo "select count*${count} from t_white where term=\"${term}\";" |\
			sqlite3 ${SFDB_PATH}`
		if [ "X${w_count}" = "X" ]
		then
			w_count=0
		fi
#
		b_count=`echo "select count*${count} from t_black where term=\"${term}\";" |\
			sqlite3 ${SFDB_PATH}`
		if [ "X${b_count}" = "X" ]
		then
			b_count=0
		fi
#
		if [ ${w_count} = "0" -a ${b_count} = "0" ]
		then
			: # do nothing
		else
			score=`echo "scale=10;((${w_count}/${w_total}) / ((${b_count} / ${b_total}) + (${w_count} / ${w_total}))) - 0.5" | bc`
			total_score=`echo "scale=10;${total_score} + ${score}" | bc`
		fi
	fi
done
#
rm /tmp/sf_check.*.$$.tmp
#
echo ${total_score}
#
if [ ${table} = "t_white" ]
then
	echo ${total_score} |\
	awk '{
		if ($0 >= 0){
			exit 0;
		}else{
			exit 1;
		}
	}'
else
	echo ${total_score} |\
	awk '{
		if ($0 >= 0){
			exit 1;
		}else{
			exit 0;
		}
	}'
fi
#
exit $?
