#! /bin/sh
#
for i in ~/Mail/white/[0-9]*
do
	echo add $i to white table
	echo -n "befor : "; sf_check.sh -w $i
	sf_add.sh -w $i
	echo -n "after : "; sf_check.sh -w $i
done
#
for i in ~/Mail/black/[0-9]*
do
	echo add $i to black table
	echo -n "befor : "; sf_check.sh -b $i
	sf_add.sh -b $i
	echo -n "after : "; sf_check.sh -b $i
done
sleep 3s
#
#echo "vacuum;" | sqlite3 ~/.sf/sf.db
