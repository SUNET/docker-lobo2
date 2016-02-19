#!/bin/sh -x

if [ "x$SP_HOSTNAME" = "x" ]; then
   SP_HOSTNAME="datasets.sunet.se"
fi

if [ "x$SP_CONTACT" = "x" ]; then
   SP_CONTACT="noc@sunet.se"
fi

if [ "x$SP_ABOUT" = "x" ]; then
   SP_ABOUT="/about"
fi

export REDIS_PORTNUMBER="6379"
export REDIS_HOSTNAME="localhost"
if [ "x${REDIS_PORT}" != "x" ]; then
   REDIS_HOSTNAME=`echo "${REDIS_PORT}" | sed 's%/%%g' | awk -F: '{ print $2 }'`
   REDIS_PORTNUMBER=`echo "${REDIS_PORT}" | sed 's%/%%g' | awk -F: '{ print $3 }'`
fi

cat>/var/run/lobo2/config.py<<EOF
REDIS_HOST = "$REDIS_HOSTNAME"
REDIS_PORT = $REDIS_PORTNUMBER
BASE_URL = "https://${SP_HOSTNAME}"
UPLOAD_FOLDER = "/tmp"
LOCALE = "sv_SE"
EOF

KEYDIR=/etc/ssl
mkdir -p $KEYDIR
export KEYDIR
if [ ! -f "$KEYDIR/private/shibsp.key" -o ! -f "$KEYDIR/certs/shibsp.crt" ]; then
   shib-keygen -o /tmp -h $SP_HOSTNAME 2>/dev/null
   mv /tmp/sp-key.pem "$KEYDIR/private/shibsp.key"
   mv /tmp/sp-cert.pem "$KEYDIR/certs/shibsp.crt"
fi

if [ ! -f "$KEYDIR/private/${SP_HOSTNAME}.key" -o ! -f "$KEYDIR/certs/${SP_HOSTNAME}.crt" ]; then
   make-ssl-cert generate-default-snakeoil --force-overwrite
   cp /etc/ssl/private/ssl-cert-snakeoil.key "$KEYDIR/private/${SP_HOSTNAME}.key"
   cp /etc/ssl/certs/ssl-cert-snakeoil.pem "$KEYDIR/certs/${SP_HOSTNAME}.crt"
fi

CHAINSPEC=""
export CHAINSPEC
if [ -f "$KEYDIR/certs/${SP_HOSTNAME}.chain" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${SP_HOSTNAME}.chain"
elif [ -f "$KEYDIR/certs/${SP_HOSTNAME}-chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${SP_HOSTNAME}-chain.crt"
elif [ -f "$KEYDIR/certs/${SP_HOSTNAME}.chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${SP_HOSTNAME}.chain.crt"
elif [ -f "$KEYDIR/certs/chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/chain.crt"
elif [ -f "$KEYDIR/certs/chain.pem" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/chain.pem"
fi

cat>/etc/shibboleth/shibboleth2.xml<<EOF
<SPConfig xmlns="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:conf="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
    xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"    
    xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
    clockSkew="180">

    <ApplicationDefaults entityID="https://${SP_HOSTNAME}/shibboleth"
                         REMOTE_USER="eppn persistent-id targeted-id">

        <Sessions lifetime="28800" timeout="3600" relayState="ss:mem"
                  checkAddress="false" handlerSSL="true" cookieProps="https">
            <SSO discoveryProtocol="SAMLDS" discoveryURL="https://md.nordu.net/role/idp.ds">
               SAML2 SAML1
            </SSO>
            <Logout>SAML2 Local</Logout>
            <Handler type="MetadataGenerator" Location="/Metadata" signing="false"/>
            <Handler type="Status" Location="/Status" acl="127.0.0.1 ::1"/>
            <Handler type="Session" Location="/Session" showAttributeValues="false"/>
            <Handler type="DiscoveryFeed" Location="/DiscoFeed"/>
        </Sessions>

        <Errors supportContact="${SP_CONTACT}"
            helpLocation="${SP_ABOUT}"
            styleSheet="/shibboleth-sp/main.css"/>
        <MetadataProvider type="XML" uri="http://md.swamid.se/md/swamid-idp-transitive.xml" backingFilePath="metadata.xml" reloadInterval="7200">
        </MetadataProvider>
        <AttributeExtractor type="XML" validate="true" reloadChanges="false" path="attribute-map.xml"/>
        <AttributeResolver type="Query" subjectMatch="true"/>
        <AttributeFilter type="XML" validate="true" path="attribute-policy.xml"/>
        <CredentialResolver type="File" key="$KEYDIR/private/shibsp.key" certificate="$KEYDIR/certs/shibsp.crt"/>
    </ApplicationDefaults>
    <SecurityPolicyProvider type="XML" validate="true" path="security-policy.xml"/>
    <ProtocolProvider type="XML" validate="true" reloadChanges="false" path="protocols.xml"/>
</SPConfig>
EOF

cat>/etc/apache2/sites-available/default.conf<<EOF
<VirtualHost *:80>
       ServerAdmin ${SP_CONTACT}
       ServerName ${SP_HOSTNAME}
       DocumentRoot /var/www/

       RewriteEngine On
       RewriteCond %{HTTPS} off
       RewriteRule !_lvs.txt$ https://%{HTTP_HOST}%{REQUEST_URI}
</VirtualHost>
EOF

cat>/var/www/lobo2.wsgi<<EOF
from lobo2.app import app as application
import sys
sys.stdout = sys.stderr
EOF

chmod a+rx /var/www/lobo2.wsgi
adduser -- _shibd ssl-cert
chown www-data:www-data /var/www/lobo2.wsgi

cat>/etc/apache2/conf-available/lobo2.conf<<EOF
WSGIDaemonProcess lobo2 user=www-data group=www-data threads=5
WSGIScriptAlias / /var/www/lobo2.wsgi
WSGIPythonHome /usr/lobo2
WSGIPassAuthorization On
EOF

a2enconf lobo2

cat>/etc/apache2/sites-available/default-ssl.conf<<EOF
<VirtualHost *:443>
        ServerName ${SP_HOSTNAME}
        SSLProtocol TLSv1 
        SSLEngine On
        SSLCertificateFile $KEYDIR/certs/${SP_HOSTNAME}.crt
        ${CHAINSPEC}
        SSLCertificateKeyFile $KEYDIR/private/${SP_HOSTNAME}.key

        <Location />
           Order deny,allow
           Allow from all
        </Location>

        <Directory /usr/lobo2>
           WSGIProcessGroup lobo2 
           WSGIApplicationGroup %{GLOBAL}
           Order deny,allow
           Allow from all
        </Directory>

        <Location "/Shibboleth.sso">
           SetHandler default-handler 
        </Location>
 
        <Location "/login">
           AuthType shibboleth
           ShibRequireSession On
           require valid-user
        </Location>

        Alias /shibboleth-sp/ /usr/share/shibboleth/

        ServerName ${SP_HOSTNAME}
        ServerAdmin noc@nordu.net

        AddDefaultCharset utf-8

        ErrorLog /var/log/apache2/error.log
        LogLevel warn
        CustomLog /var/log/apache2/access.log combined
</VirtualHost>
EOF

echo "----"
cat /etc/shibboleth/shibboleth2.xml
echo "----"
cat /etc/apache2/sites-available/default.conf
cat /etc/apache2/sites-available/default-ssl.conf

mkdir -p /var/log/apache2
mkdir -p /var/log/shibboleth
a2ensite default
a2ensite default-ssl

service shibd start
rm -f /var/run/apache2/apache2.pid

env APACHE_LOCK_DIR=/var/lock/apache2 APACHE_RUN_DIR=/var/run/apache2 APACHE_PID_FILE=/var/run/apache2/apache2.pid APACHE_RUN_USER=www-data APACHE_RUN_GROUP=www-data APACHE_LOG_DIR=/var/log/apache2 apache2 -DFOREGROUND
