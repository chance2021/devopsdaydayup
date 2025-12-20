# Lab 1 — ELK Monitoring with Metricbeat

Deploy an Elasticsearch/Logstash/Kibana (ELK) stack with Docker Compose and collect host metrics using Metricbeat, visualizing them in Kibana dashboards.

## Prerequisites

- Ubuntu 20.04 host with sudo access
- Docker and Docker Compose installed
- Ability to expose ports 9200/5601 locally

## Architecture

- Docker Compose brings up Elasticsearch, Logstash, Kibana with TLS enabled.
- Metricbeat runs on the monitored host, ships metrics to Elasticsearch, and Kibana dashboards display the data.

## Setup

1) Clone and start the ELK stack

```bash
git clone https://github.com/chance2021/devopsdaydayup.git
cd devopsdaydayup/001-ELKMonitoring
sudo sysctl -w vm.max_map_count=262144

# Update credentials in .env before starting (do not commit real passwords)
sudo docker-compose up -d
```

2) Trust the Elasticsearch CA on the monitored host

- Copy the CA cert from an Elasticsearch container:
  ```bash
  docker exec -it <elasticsearch-01-container> \
    openssl x509 -fingerprint -sha256 -in /usr/share/elasticsearch/config/certs/ca/ca.crt
  ```
- Install the CA on the monitored host:
  ```bash
  sudo apt-get install -y ca-certificates
  cd /usr/local/share/ca-certificates/
  sudo vi elasticsearch-ca.crt   # paste the CA content
  sudo update-ca-certificates
  ```

3) Install and configure Metricbeat on the monitored host

```bash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
sudo apt update
sudo apt install metricbeat
sudo vi /etc/metricbeat/metricbeat.yml
```

Ensure the following settings point to your ELK stack (adjust host/IP as needed):
```yaml
setup.kibana:
  host: "127.0.0.1:5601"
output.elasticsearch:
  hosts: ["127.0.0.1:9200"]
  protocol: "https"
  username: "elastic"
  password: "changeme"   # replace with the value you set in .env
```

Apply configuration and start Metricbeat:
```bash
sudo metricbeat setup -e
sudo systemctl start metricbeat
sudo systemctl status metricbeat
```

## Validation

- Open Kibana at `http://127.0.0.1:5601` and log in with the credentials from `.env`.
- Navigate to **Dashboard** and open **[Metricbeat System] Host overview ECS**; host metrics should appear.
- On the host, verify Metricbeat is healthy: `sudo systemctl status metricbeat`.

## Cleanup

```bash
docker-compose down -v
sudo systemctl stop metricbeat
sudo systemctl disable metricbeat
sudo apt remove metricbeat
```

## Troubleshooting

- Metricbeat fails to connect: confirm CA is installed and `hosts`/`protocol` values in `metricbeat.yml` match your ELK endpoints.
- Kibana not reachable: check Docker containers `docker ps` and view logs `docker-compose logs kibana`.
- Authentication errors: verify the credentials set in `.env` and Metricbeat output settings.

## References

- https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
- https://kifarunix.com/monitor-linux-system-metrics-with-elk-stack/
- https://github.com/elastic/beats/issues/29175
- https://www.elastic.co/training/free
