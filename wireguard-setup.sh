#!/bin/bash

if [ ${WIREGUARD} == "yes" ]
  then
    ufw allow 51194/udp # Wireguard port (connection between nodes)
    ufw allow in on wg0 to any port 22/tcp # SSH port
    ufw allow in on wg0 to any port 12798/tcp # Prometheus Node Exporter port (for Grafana)
    ufw allow in on wg0 to any port 9100/tcp # Prometheus Node Exporter port (for Grafana)
    ufw allow in on wg0 to any port 9080/tcp # Promtail port (for Grafana/Loki)
  else
    ufw allow 22/tcp # SSH port
    ufw allow 12798/tcp # Prometheus Node Exporter port (for Grafana)
    ufw allow 9100/tcp # Prometheus Node Exporter port (for Grafana)
    ufw allow 9080/tcp # Promtail port (for Grafana/Loki)
fi