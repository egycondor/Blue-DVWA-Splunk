FROM vulnerables/web-dvwa

# Update sources.list to use Debian archive repositories
RUN echo "deb http://archive.debian.org/debian/ stretch main contrib non-free" > /etc/apt/sources.list && \
    echo "deb-src http://archive.debian.org/debian/ stretch main contrib non-free" >> /etc/apt/sources.list && \
    echo "Acquire::Check-Valid-Until false;" > /etc/apt/apt.conf

# Environment variables
ENV SPLUNK_FORWARDER_URL=https://download.splunk.com/products/universalforwarder/releases/8.2.2.1/linux/splunkforwarder-8.2.2.1-ae6821b7c64b-linux-2.6-amd64.deb
ENV SPLUNK_SERVER=splunk
ENV SPLUNK_SERVER_PORT=9997
ENV SPLUNK_USER=admin
ENV SPLUNK_PASS=changeme

# Download and Install Splunk Universal Forwarder
RUN apt-get update && apt-get install -y wget curl && \
    wget -O splunkforwarder.deb $SPLUNK_FORWARDER_URL && \
    dpkg -i splunkforwarder.deb && \
    rm splunkforwarder.deb && \
    /opt/splunkforwarder/bin/splunk start --accept-license --answer-yes --no-prompt --username $SPLUNK_USER --password $SPLUNK_PASS && \
    /opt/splunkforwarder/bin/splunk add forward-server ${SPLUNK_SERVER}:${SPLUNK_SERVER_PORT} && \
    /opt/splunkforwarder/bin/splunk add monitor /var/log/apache2/access.log && \
    /opt/splunkforwarder/bin/splunk add monitor /var/log/apache2/error.log && \
    /opt/splunkforwarder/bin/splunk restart && \
    apt-get clean

# Configure Splunk
COPY splunk-configs/inputs.conf /opt/splunkforwarder/etc/system/local/
COPY splunk-configs/props.conf /opt/splunkforwarder/etc/system/local/
COPY splunk-configs/transforms.conf /opt/splunkforwarder/etc/system/local/




# Enable mod_dumpio and configure Apache to log request and response bodies
RUN a2enmod dump_io && \
    echo "DumpIOInput On" >> /etc/apache2/apache2.conf && \
    echo "DumpIOOutput On" >> /etc/apache2/apache2.conf && \
    echo "LogLevel dumpio:trace7" >> /etc/apache2/apache2.conf

RUN /opt/splunkforwarder/bin/splunk start --accept-license


# Restart Splunk Forwarder
RUN /opt/splunkforwarder/bin/splunk restart

CMD ["/bin/bash", "-c", "/etc/init.d/apache2 start && tail -f /var/log/apache2/*", "/opt/splunkforwarder/bin/splunk start --accept-license"]