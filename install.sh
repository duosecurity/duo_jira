#!/bin/sh

# default JIRA install directory
JIRA=/opt/atlassian/jira
AKEY=`python -c "import hashlib, os;  print hashlib.sha1(os.urandom(32)).hexdigest()"`

# duo file variables
DUO_WEB_FILENAME=DuoWeb-1.1-SNAPSHOT.jar
DUO_CLIENT_FILENAME=duo-client-0.2.1.jar
DUO_FILTER_FILENAME=duo-filter-1.3.5-SNAPSHOT.jar
DUO_PLUGIN_FILENAME=duo-twofactor-1.4.0-SNAPSHOT.jar

usage () {
    printf >&2 "Usage: $0 [-d JIRA directory] -i ikey -s skey -h host\n"
    printf >&2 "ikey, skey, and host can be found in Duo account's administration panel at admin.duosecurity.com\n"
}

while getopts d:i:s:h: o
do  
    case "$o" in
        d)  JIRA="$OPTARG";;
        i)  IKEY="$OPTARG";;
        s)  SKEY="$OPTARG";;
        h)  HOST="$OPTARG";;
        [?]) usage
            exit 1;;
    esac
done

if [ -z $IKEY ]; then echo "Missing -i (Duo integration key)"; usage; exit 1; fi
if [ -z $SKEY ]; then echo "Missing -s (Duo secret key)"; usage; exit 1; fi
if [ -z $HOST ]; then echo "Missing -h (Duo API hostname)"; usage; exit 1; fi

echo "Installing Duo integration to $JIRA..."

CONFLUENCE_ERROR="The directory ($JIRA) does not look like a JIRA installation. Use the -d option to specify where JIRA is installed."

if [ ! -d $JIRA ]; then
    echo "$JIRA_ERROR"
    exit 1
fi
if [ ! -e $JIRA/atlassian-jira/WEB-INF/lib ]; then
    echo "$JIRA_ERROR"
    exit 1
fi

# make sure we haven't already installed
if [ -e "${JIRA}"/atlassian-jira/WEB-INF/lib/"${DUO_WEB_FILENAME}" ]; then
    echo "${DUO_WEB_FILENAME} already exists in ${JIRA}/atlassian-jira/WEB-INF/lib.  Move or remove this jar to continue."
    echo "exiting"
    exit 1
fi

# make sure we haven't already installed
if [ -e "${JIRA}"/atlassian-jira/WEB-INF/lib/"${DUO_CLIENT_FILENAME}" ]; then
    echo "${DUO_CLIENT_FILENAME} already exists in ${JIRA}/atlassian-jira/WEB-INF/lib.  Move or remove this jar to continue."
    echo "exiting"
    exit 1
fi

# make sure we haven't already installed
if [ -e "${JIRA}"/atlassian-jira/WEB-INF/lib/"${DUO_FILTER_FILENAME}" ]; then
    echo "${DUO_FILTER_FILENAME} already exists in ${JIRA}/atlassian-jira/WEB-INF/lib.  Move or remove this jar to continue."
    echo "exiting"
    exit 1
fi

# we don't actually write to web.xml, so just warn if it's already there
grep '<filter-name>duoauth</filter-name>' $JIRA/atlassian-jira/WEB-INF/web.xml >/dev/null
if [ $? -eq 0 ]; then
    echo "Warning: It looks like the Duo authenticator has already been added to JIRA's web.xml."
fi

echo "Copying in Duo integration files..."

# install the duo web jar
cp etc/"${DUO_WEB_FILENAME}" $JIRA/atlassian-jira/WEB-INF/lib
if [ $? -ne 0 ]; then
    echo "Could not copy ${DUO_WEB_FILENAME}, please contact support@duosecurity.com"
    echo "exiting"
    exit 1
fi

# install the duo client jar
cp etc/"${DUO_CLIENT_FILENAME}" $JIRA/atlassian-jira/WEB-INF/lib
if [ $? -ne 0 ]; then
    echo "Could not copy ${DUO_CLIENT_FILENAME}, please contact support@duosecurity.com"
    echo "exiting"
    exit 1
fi

# install the seraph filter jar
cp etc/"${DUO_FILTER_FILENAME}" $JIRA/atlassian-jira/WEB-INF/lib
if [ $? -ne 0 ]; then
    echo "Could not copy ${DUO_FILTER_FILENAME}, please contact support@duosecurity.com"
    echo "exiting"
    exit 1
fi

echo "duo_jira jars have been installed. Next steps, in order:"
echo "- Upload and install the plugin in etc/${DUO_PLUGIN_FILENAME} "
echo "  using the JIRA web UI."
echo "- Edit web.xml, located at $JIRA/atlassian-jira/WEB-INF/web.xml."
echo "- Locate the filter:"
echo "    <filter>"
echo "        <filter-name>security</filter-name>"
echo "        <filter-class>com.atlassian.jira.security.JiraSecurityFilter</filter-class>"
echo "    </filter>"
echo "- Add the following directly after the filter listed above:"
echo "    <filter>"
echo "        <filter-name>duoauth</filter-name>"
echo "        <filter-class>com.duosecurity.seraph.filter.DuoAuthFilter</filter-class>"
echo "        <init-param>"
echo "            <param-name>ikey</param-name>"
echo "            <param-value>$IKEY</param-value>"
echo "        </init-param>"
echo "        <init-param>"
echo "            <param-name>skey</param-name>"
echo "            <param-value>$SKEY</param-value>"
echo "        </init-param>"
echo "        <init-param>"
echo "            <param-name>akey</param-name>"
echo "            <param-value>$AKEY</param-value>"
echo "        </init-param>"
echo "        <init-param>"
echo "            <param-name>host</param-name>"
echo "            <param-value>$HOST</param-value>"
echo "        </init-param>"
echo "    </filter>"
echo "- Locate the filter-mapping:"
echo "    <filter-mapping>"
echo "        <filter-name>security</filter-name>"
echo "        <url-pattern>/*</url-pattern>"
echo "        <dispatcher>REQUEST</dispatcher>"
echo "        <dispatcher>FORWARD</dispatcher> <!-- we want security to be applied after urlrewrites, for example -->"
echo "    </filter-mapping>"
echo "- Add the following directly after the filter-mapping listed above:"
echo "    <filter-mapping>"
echo "        <filter-name>duoauth</filter-name>"
echo "        <url-pattern>/*</url-pattern>"
echo "        <dispatcher>FORWARD</dispatcher>"
echo "        <dispatcher>REQUEST</dispatcher>"
echo "    </filter-mapping>"
echo "- Restart Jira."
