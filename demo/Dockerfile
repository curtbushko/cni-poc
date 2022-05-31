FROM alpine:3.15 

COPY consul-cni /bin
RUN chmod +x /bin/consul-cni
COPY installer.sh /bin
RUN chmod +x /bin/installer.sh 
COPY 10-kindnet.conflist /bin

CMD /bin/installer.sh


