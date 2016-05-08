#! /bin/sh
trap "rm /tmp/sf_check.*.$$.tmp; exit 1" INT TERM
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
maxlength=20; export maxlength
tab=`echo -n -e '\t'`
##zsp=`echo -n -e '\241\241'`
#
table=""; export table
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
echo ".separator \"\t\"" >/tmp/sf_check.1.$$.tmp
echo "begin;" >>/tmp/sf_check.1.$$.tmp
echo "select tablenm,count from t_total where tablenm=\"t_white\";" >>/tmp/sf_check.1.$$.tmp
echo "select tablenm,count from t_total where tablenm=\"t_black\";" >>/tmp/sf_check.1.$$.tmp
echo "end;" >>/tmp/sf_check.1.$$.tmp
#
echo ".separator \"\t\"" >/tmp/sf_check.2.$$.tmp
echo "begin;" >>/tmp/sf_check.2.$$.tmp
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
#
	if [ "X${term}" = "X" ]
	then
		: # do nothing
	else
		echo "select t_white.term,t_white.count*${count},t_black.count*${count} from t_white left join t_black on t_white.term = t_black.term where t_white.term=\"${term}\";" >>/tmp/sf_check.2.$$.tmp
		echo "select t_black.term,t_white.count*${count},t_black.count*${count} from t_black left join t_white on t_white.term = t_black.term where t_black.term=\"${term}\" and t_white.term is NULL;" >>/tmp/sf_check.2.$$.tmp
	fi
done
#
echo "end;" >>/tmp/sf_check.2.$$.tmp
#
(
	cat /tmp/sf_check.1.$$.tmp |\
	sqlite3 ${SFDB_PATH}
#
	cat /tmp/sf_check.2.$$.tmp |\
	sqlite3 ${SFDB_PATH} |\
	sort |\
	uniq
) |\
awk 'BEGIN{
	FS = "\t";
	w_total = 0; \
	b_total = 0; \
	total_score = 0.0;
	table = ENVIRON["table"]; \
}
{
	if (NR < 3){
		if ($1 == "t_white"){
			w_total = $2;
		}
		if ($1 == "t_black"){
			b_total = $2;
		}
	}
#
	if ($2 == ""){
		w_count = 0;
	}else{
		w_count = $2;
	}
#
	if ($3 == ""){
		b_count = 0;
	}else{
		b_count = $3;
	}
#
	if (w_total == 0 || b_total == 0 || (w_count == 0 && b_count == 0)){
		# do nothing 
	}else{
		total_score += (((w_count / w_total) / ((b_count / b_total) + (w_count / w_total))) - 0.5);
	}
}
END{
	print total_score;
	if (table == "t_white"){
		if (total_score < 0.0){
			stat = 1;
		}else{
			stat = 0;
		}
	}else{
		if (total_score < 0.0){
			stat = 0;
		}else{
			stat = 1;
		}
	}
	exit stat;
}'
stat=$?
#
rm /tmp/sf_check.*.$$.tmp
#
exit ${stat}
