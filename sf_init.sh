#! /bin/sh
#
# spam filter programs by m-ito@myh.no-ip.org
#
#----------------------------------------------------------------------
#
# functions
#
function show_help () {
	echo "Usage : $0"
	echo "Initialize database."
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
rm -f ${SFDB_PATH}
#
sqlite3 ${SFDB_PATH} <<__EOF__
create table t_white (
  term    text primary key,
  count   integer
);
create table t_black (
  term    text primary key,
  count   integer
);
create table t_total (
  tablenm text primary key,
  count   integer
);
insert into t_total values("t_white",0);
insert into t_total values("t_black",0);
__EOF__
#
exit 0
