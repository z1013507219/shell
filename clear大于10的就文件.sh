#!/bin/sh
#
for i in /web/backup/*
do
 if [ -d $i ]
 then 
   cd $i  
   value=`ls | wc -l`
   if [ $value -gt 10 ]
   then  
     x=$[$value-10] 
     for ((i=1;i<=x;i++))
     do      
       ls -rt | head -1 | xargs rm -rf
     done
   fi
  fi
done
