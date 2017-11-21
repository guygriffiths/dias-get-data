# Adapted from https://gist.github.com/dodok1/4134605

# Usage: cas-post.sh {url} {params} {username} {password} {outfile} # If you have any errors try removing the redirects to get more information
DEST=$1
REQUEST_STRING=$2

# Example parameter values for DIAS download.  Combine to get the request string
region=GCM&
experiment=HPB&
ensemble=m001,m002,m003&
category=sfc_max_day&
variables=WIND&
from=195101&
to=201101&
west=0&
east=10&
south=45&
north=55

ENCODED_DEST=`echo "$DEST" | perl -p -e 's/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg' | sed 's/%2E/./g' | sed 's/%0A//g'`

#IP Addresses or hostnames are fine here
CAS_HOSTNAME=dias-dss.tkl.iis.u-tokyo.ac.jp

#Authentication details. This script only supports username/password login, but curl can handle certificate login if required
USERNAME=$3
PASSWORD=$4
OUTFILE=$5

#Temporary files used by curl to store cookies and http headers
COOKIE_JAR=.cookieJar
HEADER_DUMP_DEST=.headers
rm $COOKIE_JAR
rm $HEADER_DUMP_DEST

#The script itself is below

#Visit CAS and get a login form. This includes a unique ID for the form, which we will store in CAS_ID and attach to our form submission. jsessionid cookie will be set here
CAS_ID=`curl -s -k -c $COOKIE_JAR https://$CAS_HOSTNAME/cas/login?service=$ENCODED_DEST | grep name=.lt | sed 's/.*value..//' | sed 's/\".*//'`

echo "Got CAS ID: $CAS_ID"
echo

#Submit the login form, using the cookies saved in the cookie jar and the form submission ID just extracted. We keep the headers from this request as the return value should be a 302 including a "ticket" param which we'll need in the next request
curl -s -k --data "username=$USERNAME&password=$PASSWORD&lt=$CAS_ID&_eventId=submit&submit=LOGIN&execution=e1s1" -i -b $COOKIE_JAR -c $COOKIE_JAR https://$CAS_HOSTNAME/cas/login?service=$ENCODED_DEST -D $HEADER_DUMP_DEST -o /dev/null

# Response from the previous call has retrieving windows-style linebreaks in OSX, so remove them
dos2unix $HEADER_DUMP_DEST > /dev/null

#Visit the URL with the ticket param to finally set the casprivacy and, more importantly, MOD_AUTH_CAS cookie. Now we've got a MOD_AUTH_CAS cookie, anything we do in this session will pass straight through CAS
CURL_DEST=`grep Location $HEADER_DUMP_DEST | sed 's/Location: //'`
echo "Getting MOD_AUTH_CAS cookie from $CURL_DEST"
echo
curl -s -k -b $COOKIE_JAR -c $COOKIE_JAR "$CURL_DEST"

#If our destination is not a GET we'll need to do a GET to, say, the user dashboard here

#Visit the place we actually wanted to go to
echo "Visiting actual destination"
echo
curl -s -k -b $COOKIE_JAR --data "$REQUEST_STRING" $DEST > $OUTFILE
