#!/bin/bash 
#
# BGP to Static route v 0.4
# Updated last on 24 Sep 2012 
#
# Ken Cope - Juniper Networks 
# 
# This converts the output of a "show ip bgp" command on a IOS or Quagga device into a ton of static routes complete with the AS path, useful for creating a fake Internet.
#
#  
# 
TEMPFILE=/tmp/bgp2static.tmp
TEMPFILE2=/tmp/bgp2static.tmp2
CIDR=/tmp/bgp2static.cidr.tmp
CLASSFUL=/tmp/bgp2static.classful.tmp
CLASSA=/tmp/bgp2static.class-a.tmp
CLASSB=/tmp/bgp2static.class-b.tmp
CLASSC=/tmp/bgp2static.class-c.tmp
COMMUNITY="UNDEFINED"
COMMTRANS="6969.6969"

# show program usage
show_usage() {
echo
echo "Usage: ${0##/} [OPTION]... "
echo "Convert output of a \"show ip bgp\" command from a IOS/Quagga device to Junos static routes in set format"
echo 
echo "Mandatory arguments:"
echo "   -f		File containing output from \"show ip bgp\""
echo 
echo "Optional arguments:"
echo 
echo "   -c             Add community in x:y notation."
echo "   -h 		Display help"
echo "   -v		Be verbose"
exit 
}

# Check no of arguments
if (($# == 0)); then
   show_usage
fi

while getopts "hvf:c:" opt; do
   case $opt in
     h)
        show_usage
        ;;
     v)
        VERBOSE="YES"
	;;
     f)
        BGPFILE=$OPTARG
        if [ ! -f $BGPFILE ]; then
               echo "File $BGPFILE does not exist!"
               exit 1
        fi
	JUNOS="$BGPFILE.set.junos"
        ;;
     c)
        COMMUNITY=$OPTARG
	;;
     \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
   esac
done
        

# Clean up any tempfiles tha may still be around
rm -f $TEMPFILE $TEMPFILE2 $CIDR $CLASSFUL $CLASSA $CLASSC $JUNOS > /dev/null 2>&1

# Start conversion
# 
# Remove any stray DOSlike characters
if [ $VERBOSE ]; then 
   echo "Converting $BGPFILE"
   echo " - Removing carriage returns \^M"
fi
cat $BGPFILE | tr -d "\015"  > $TEMPFILE

# Search for start of Prefixes
#STARTLINE=`grep -w -n -m 1 Network $TEMPFILE | grep -w Metric | grep -w Path | awk -F: '{print $1}'`
#if [ $VERBOSE ]; then 
#   echo " - Found start of network prefixes at line $STARTLINE"
#fi

# Strip out lines that contain a valid IP address (including CIDR notation) and strip out any trailing spaces
if [ $VERBOSE ]; then 
   echo " - Parsing for lines that contain a valid IP prefix and are a valid route and stripping out valid route indicators"
fi
egrep  '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}' $TEMPFILE | grep ^"\*>\ " | sed -e s/^"\*>\ "/""/ -e s/\ *$// > $TEMPFILE2

# Removing as-set, as-sequence indicators from the as path (Junos can attach these attributes to a static route att)
if [ $VERBOSE ]; then 
   echo " - Removing AS-SET and AS-SEQUENCE indicators from AS-PATHs"
fi
cat $TEMPFILE2 | sed -e 's/R\{2,\}//' -e s/\{/R/ -e s/\}/R/ -e s/\,/\ /g  > $TEMPFILE
 

# Separate out classful routes so we can convert them to cidr notation
# CIDR prefixes
if [ $VERBOSE ]; then 
   echo " - Separating out routes using CIDR notation"
fi
grep \/ $TEMPFILE > $CIDR
if [ $VERBOSE ]; then 
   ROUTES=`wc -l $CIDR | awk '{print $1}'`
   echo " - Found $ROUTES prefixes using CIDR notation"
fi

# Clasful prefixes
if [ $VERBOSE ]; then 
   echo " - Separating out routes using classfull prefixes"
fi
grep -v \/ $TEMPFILE > $CLASSFUL
if [ $VERBOSE ]; then 
   ROUTES=`wc -l $CLASSFUL | awk '{print $1}'`
   echo " - Found $ROUTES classful prefixes"
fi

#Class A routes
if [ $VERBOSE ]; then 
   echo " - Separating out Class A prefixes"
fi
grep ^[0-9]\\. $CLASSFUL > $CLASSA
grep ^[0-9].\\. $CLASSFUL >> $CLASSA
grep ^1[0-2][0-6]\\. $CLASSFUL >> $CLASSA
if [ $VERBOSE ]; then 
   UROUTES=`wc -l $CLASSA | awk '{print $1}'`
   echo " - Found $ROUTES Class A prefixes"
fi


#Class-B routes
if [ $VERBOSE ]; then 
   echo " - Separating out Class B prefixes"
fi
grep ^128\\. $CLASSFUL > $CLASSB
grep ^129\\. $CLASSFUL >> $CLASSB
grep ^1[3-8][0-9]\\. $CLASSFUL >> $CLASSB
grep ^190\\. $CLASSFUL >> $CLASSB
grep ^191\\. $CLASSFUL >> $CLASSB
if [ $VERBOSE ]; then 
   ROUTES=`wc -l $CLASSB | awk '{print $1}'`
   echo " - Found $ROUTES Class B prefixes"
fi

#Class-C routes
if [ $VERBOSE ]; then 
   echo " - Separating out Class C prefixes"
fi
grep ^19[2-9]\\. $CLASSFUL > $CLASSC
grep ^2[0-9][0-9]\\. $CLASSFUL > $CLASSC
if [ $VERBOSE ]; then 
   ROUTES=`wc -l $CLASSC | awk '{print $1}'`
   echo " - Found $ROUTES Class C prefixes"
fi


#Adding CIDR notation to Classful Routes
if [ $VERBOSE ]; then 
   echo " - Adding CIDR notation to classfull prefixes"
fi
cat $CLASSA | sed s/\\:/\\/8\\:/ >> $CIDR
cat $CLASSB | sed s/\\:/\\/16\\:/ >> $CIDR
cat $CLASSC | sed s/\\:/\\/24\\:/ >> $CIDR
if [ $VERBOSE ]; then 
   ROUTES=`wc -l $CIDR | awk '{print $1}'`
   echo " - We have $ROUTES prefixes"
fi

#Reformating CIDR file for easier parsing later on
if [ $VERBOSE ]; then 
   echo " - Reformating for parsing."
fi
cat $CIDR | sed -e 's/[ ][ ]*/,/g' > $TEMPFILE

# Translating AS 23456 into a bogus 32 bit AS
cat $TEMPFILE |  sed s/23456/6969\.6969/g  > $CIDR
if [ $VERBOSE ]; then 
   ROUTES=`grep 6969.6969 $CIDR | wc -l | awk '{print $1}'`
   echo " - Found $ROUTES occurances of 32 bit ASNs translated into 16 bit ASNs"
fi


#Creating JunOS set commands for static routes
if [ $VERBOSE ]; then 
   echo " - Creating Junos set commands"
   echo "   - creating static routes to discard interface"
fi

ROUTES=0

#Parsing each prefix line
for PREFIXINFO in `cat $CIDR`; do
   PREFIX=`echo $PREFIXINFO | awk -F, '{print $1}'`
   METRIC=`echo $PREFIXINFO | awk -F, '{print $3}'`
   ORIGINTMP=`echo $PREFIXINFO | awk '{print substr($0,length,1)}'`
   ASPATH=`echo $PREFIXINFO | cut -d, -f 5- | sed -e s/..$// -e s/,/\ /g `

   case $ORIGINTMP in
     i)
        ORIGIN="igp"
        ;;
     e)
        ORIGIN="egp"
        ;;
     \?)
        ORIGIN="incomplete"
        ;;
   esac

   # add the static route to the discard interface
   echo "set routing-options static route $PREFIX discard" >> $JUNOS
   
   
   # Add as-path if not null
   if [ "$ASPATH" != "i" ]; then
      echo "set routing-options static route $PREFIX as-path path \"$ASPATH\"" >> $JUNOS
   fi

   # add the origin code
   echo "set routing-options static route $PREFIX origin $ORIGIN" >> $JUNOS

   # Add community if defined
   if [ "$COMMUNITY" != "UNDEFINED" ]; then 
      echo "set routing-options static route $PREFIX community $COMMUNITY" >> $JUNOS
   fi

   # Add MED if present
   if [ "$METRIC" != "0" ]; then 
      echo "set routing-options static route $PREFIX metric2 $METRIC" >> $JUNOS
   fi
   
   # Display number of routes written 
   if [ $VERBOSE ]; then 
      ROUTES=$[$ROUTES+1]
      echo -ne "   - $ROUTES\r"
   fi
done

echo 
echo "Wrote output to $JUNOS"
