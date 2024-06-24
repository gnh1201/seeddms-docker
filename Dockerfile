FROM php:7.4-apache
LABEL maintainer="Namhyeon Go<gnh1201@gmail.com>, Niels Lippke<nlippke@gmx.de>"
ENV VER 6.0.28
ENV PAPERLESS_VER 1.1.0
ENV SEEDDMS_BASE=/var/www/seeddms \
    SEEDDMS_HOME=/var/www/seeddms/seeddms-${VER}
ENV PUBLIC_CERT=${SEEDDMS_BASE}/conf/cacert.pem \
    PUBLIC_CERT_SUBJ=/CN=localhost \
    PRIVATE_KEY=${SEEDDMS_BASE}/conf/cakey.pem \
    FORCE_SSL=0

# Update and install necessary packages
RUN apt-get update && apt-get install --no-install-recommends git gnumeric libpng-dev catdoc poppler-utils a2ps html2text \
    id3 docx2txt tesseract-ocr tesseract-ocr-deu ocrmypdf imagemagick vim parallel dos2unix cron rsync libzip-dev \
    libldb-dev libldap2-dev libxslt1-dev \
    libmagickwand-dev -y && rm -rf /var/lib/apt/lists/*
RUN printf "\n" | pecl install imagick
RUN docker-php-ext-enable imagick
RUN docker-php-ext-install gd mysqli pdo pdo_mysql zip ldap xsl intl && \
    pear channel-update pear.php.net && pear install Log

# Get seeddms
RUN curl -fsSL https://downloads.sourceforge.net/project/seeddms/seeddms-${VER}/seeddms-quickstart-${VER}.tar.gz | tar -xzC /var/www
RUN mv /var/www/seeddms60x $SEEDDMS_BASE

WORKDIR $SEEDDMS_BASE
RUN mkdir backup && mkdir -p import/admin && mkdir ext && touch conf/ENABLE_INSTALL_TOOL && \
    git clone https://codeberg.org/SeedDMS/paperless www/ext/paperless

# Copy settings-files
COPY sources/php.ini /usr/local/etc/php/
COPY sources/000-default.conf /etc/apache2/sites-available/
COPY sources/settings.xml $SEEDDMS_BASE/conf/settings.xml
COPY sources/seeddms-entrypoint /usr/local/bin
COPY sources/*.sh /usr/local/bin/
COPY sources/policy.xml /etc/ImageMagick-6/policy.xml

RUN chown -R www-data:www-data ./ && \
    dos2unix /usr/local/bin/*.sh && chmod a+rx /usr/local/bin/*.sh && \
    dos2unix /usr/local/bin/seeddms-entrypoint && chmod a+rx /usr/local/bin/seeddms-entrypoint && \
    a2enmod rewrite && \
    echo "export SEEDDMS_BASE=$SEEDDMS_BASE" >> /usr/local/bin/seeddms-settings.sh && \
    echo "export SEEDDMS_HOME=$SEEDDMS_HOME" >> /usr/local/bin/seeddms-settings.sh && \
    sed -ri -e 's!/var/www/html!${SEEDDMS_BASE}/www!g' /etc/apache2/sites-available/*.conf && \
    sed -ri -e 's!/var/www/!${SEEDDMS_BASE}/www!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

WORKDIR /etc/apache2/sites-enabled
RUN ln -s ../sites-available/default-ssl.conf default-ssl.conf
WORKDIR /etc/apache2/mods-enabled
RUN ln -s ../mods-available/ssl.conf ssl.conf && \
    ln -s ../mods-available/ssl.load ssl.load && \
    ln -s ../mods-available/socache_shmcb.load socache_shmcb.load

VOLUME ["/var/www/seeddms/data", "/var/www/seeddms/backup"]

ENTRYPOINT ["/usr/local/bin/seeddms-entrypoint"]
CMD ["apache2-foreground"]
