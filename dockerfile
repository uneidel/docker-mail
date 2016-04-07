# docker-mail no postgres
FROM      ubuntu:latest
MAINTAINER uneidel <uneidel@octonion.de>

ENV DEBIAN_FRONTEND noninteractive

# create file to see if this is the firstrun when started
RUN touch /firstrun

RUN apt-get update && apt-get dist-upgrade -y 
RUN apt-get install -y wget supervisor
RUN apt-get install -y nginx php5-fpm php5-pgsql postfix postfix-pgsql fetchmail amavisd-new \
                       libnet-dns-perl libmail-spf-perl  dovecot-imapd dovecot-lmtpd dovecot-pgsql dovecot-sieve dovecot-managesieved \
					   spamassassin razor pwgen     


#dovecot and postfix config files
ADD install.sh /
ADD create_user.sh /usr/local/bin/
ADD configs/dovecot /etc/dovecot/
ADD configs/postfix /etc/postfix/

# users
#RUN groupadd -g 5000 vmail && \
#    useradd -g vmail -u 5000 vmail -d /home/vmail -m && \
#    chgrp postfix /etc/postfix/pgsql-*.cf && \
#    chgrp vmail /etc/dovecot/dovecot.conf && \
#    chmod g+r /etc/dovecot/dovecot.conf

WORKDIR /var/www
#roundcube / postfixadmin
RUN wget http://downloads.sourceforge.net/project/roundcubemail/roundcubemail/1.1.4/roundcubemail-1.1.4.tar.gz -O - | tar xz ; \
    mv /var/www/roundcubemail-1.1.4 /var/www/rc; \
    rm -fr /var/www/rc/installer ; \
    wget http://downloads.sourceforge.net/project/postfixadmin/postfixadmin/postfixadmin-2.3.8/postfixadmin-2.3.8.tar.gz -O - | tar xz ; \
    mv /var/www/postfixadmin-2.3.8 /var/www/postfixadmin; \
    chown -R www-data:www-data /var/www;

COPY configs/postfixadmin/config.inc.php /var/www/postfixadmin/config.inc.php


ADD configs/nginx/default /etc/nginx/sites-enabled/
RUN echo "\ndaemon off;" >> /etc/nginx/nginx.conf

ADD index.php /var/www/

#Fixing php-fpm for supervisord and tweak
RUN sed -i 's/;daemonize = yes/daemonize = no/g' /etc/php5/fpm/php-fpm.conf
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php5/fpm/php.ini && \
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf && \
sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php5/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php5/fpm/pool.d/www.conf

# fix ownership of sock file for php-fpm
#RUN sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php5/fpm/pool.d/www.conf && \
#find /etc/php5/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;


# Cleanup
RUN rm /etc/nginx/sites-available/default
RUN apt-get clean

EXPOSE 25 143 993 465 80 443 
#VOLUME ["/var/mail","/home"]
#ENTRYPOINT [ "/startup.sh" ]
#CMD /install.sh;
ADD ./supervisord.conf /etc/supervisor/supervisord.conf
CMD ["/usr/bin/supervisord","-c","/etc/supervisor/supervisord.conf"]


