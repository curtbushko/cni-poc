FROM alpine:3.15 

COPY ./bin/consul-cni /bin
COPY ./bin/consul-k8s /bin
RUN chmod +x /bin/consul-cni
RUN chmod +x /bin/consul-k8s

CMD /bin/consul-k8s install-cni


