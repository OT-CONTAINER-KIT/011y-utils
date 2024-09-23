# POC of Logs visualization of kafka.

## Flow Diagram 

![image](https://github.com/user-attachments/assets/f7c9f57c-9fdb-45f7-9155-95ae8ffefb1d)

## Docker compose file for Kafka Setup.

<details>
<summary> docker-compose.yaml </summary>

  ```shell
  
# This docker-compose is only to get started with Conduktor.
# It is starting Conduktor, a Redpanda cluster (Kafka), and a fake app to generate traffic.
# Go to http://localhost:8080 when started
####################################################################################################
# DO NOT USE IT IN PRODUCTION
#
# For production, please check: https://docs.conduktor.io/platform/category/deployment-options/
#   to deploy on Kubernetes via Helm, or AWS using Cloudformation.
####################################################################################################
services:  
  # Conduktor Console, the enterprise UI.
  # It depends on PostgreSQL. Here, we depend on Redpanda only for our get-started.
  # https://docs.conduktor.io/platform/get-started/configuration/introduction/
  conduktor-console:
    image: conduktor/conduktor-console:1.26.0
    depends_on:
      - postgresql
      - redpanda-0
    ports:
      - "8080:8080"
    volumes:
      - conduktor_data:/var/conduktor
    environment:
      CDK_DATABASE_URL: "postgresql://conduktor:change_me@postgresql:5432/conduktor-console"
      CDK_CLUSTERS_0_ID: "local-kafka"
      CDK_CLUSTERS_0_NAME: "local-kafka"
      CDK_CLUSTERS_0_BOOTSTRAPSERVERS: "redpanda-0:9092"
      CDK_CLUSTERS_0_SCHEMAREGISTRY_URL: "http://redpanda-0:18081"
      CDK_CLUSTERS_0_COLOR: "#6A57C8"
      CDK_CLUSTERS_0_ICON: "kafka"
      CDK_CLUSTERS_1_ID: "cdk-gateway"
      CDK_CLUSTERS_1_NAME: "cdk-gateway"
      CDK_CLUSTERS_1_BOOTSTRAPSERVERS: "conduktor-gateway:6969"
      CDK_CLUSTERS_1_SCHEMAREGISTRY_URL: "http://redpanda-0:18081"
      CDK_CLUSTERS_1_KAFKAFLAVOR_URL: "http://conduktor-gateway:8888"
      CDK_CLUSTERS_1_KAFKAFLAVOR_USER: "admin"
      CDK_CLUSTERS_1_KAFKAFLAVOR_PASSWORD: "conduktor"
      CDK_CLUSTERS_1_KAFKAFLAVOR_VIRTUALCLUSTER: "passthrough"
      CDK_CLUSTERS_1_KAFKAFLAVOR_TYPE: "Gateway"
      CDK_CLUSTERS_1_COLOR: "#6A57C8"
      CDK_CLUSTERS_1_ICON: "dog"
      CDK_MONITORING_CORTEX-URL: http://conduktor-monitoring:9009/
      CDK_MONITORING_ALERT-MANAGER-URL: http://conduktor-monitoring:9010/
      CDK_MONITORING_CALLBACK-URL: http://conduktor-console:8080/monitoring/api/
      CDK_MONITORING_NOTIFICATIONS-CALLBACK-URL: http://localhost:8080
      
  # Conduktor stores its metadata in PostgreSQL.
  # Consider using an external managed database for production usage.
  # https://docs.conduktor.io/platform/get-started/configuration/database/
  postgresql:
    image: postgres:14
    hostname: postgresql
    volumes:
      - pg_data:/var/lib/postgresql/data
    environment:
      PGDATA: "/var/lib/postgresql/data"
      POSTGRES_DB: "conduktor-console"
      POSTGRES_USER: "conduktor"
      POSTGRES_PASSWORD: "change_me"
      POSTGRES_HOST_AUTH_METHOD: "scram-sha-256"
  # Conduktor uses Cortex to store Kafka and applications metrics as well as alerting.
  # It is optional. 
  # https://docs.conduktor.io/platform/get-started/configuration/cortex/
  conduktor-monitoring:
    image: conduktor/conduktor-console-cortex:1.26.0
    environment:
      CDK_CONSOLE-URL: "http://conduktor-console:8080"
  # We use Redpanda to get started with Kafka as it's small and efficient.
  # This is an example here. For production, connect Conduktor to your own Kafka clusters.
  redpanda-0:
    command:
      - redpanda
      - start
      - --kafka-addr internal://0.0.0.0:9092,external://0.0.0.0:19092
      - --advertise-kafka-addr internal://redpanda-0:9092,external://localhost:19092
      - --pandaproxy-addr internal://0.0.0.0:8082,external://0.0.0.0:18082
      # Address the broker advertises to clients that connect to the HTTP Proxy.
      - --advertise-pandaproxy-addr internal://redpanda-0:8082,external://localhost:18082
      - --schema-registry-addr internal://0.0.0.0:8081,external://0.0.0.0:18081
      # Redpanda brokers use the RPC API to communicate with eachother internally.
      - --rpc-addr redpanda-0:33145
      - --advertise-rpc-addr redpanda-0:33145
      - --smp 1
      - --memory 1G
      - --mode dev-container
      - --default-log-level=info
    image: docker.redpanda.com/redpandadata/redpanda:v24.1.6
    container_name: redpanda-0
    volumes:
      - redpanda-0:/var/lib/redpanda/data
    ports:
      - 18081:18081
      - 18082:18082
      - 19092:19092
      - 19644:9644
    healthcheck:
      test: ["CMD-SHELL", "rpk cluster health | grep -E 'Healthy:.+true' || exit 1"]
      interval: 15s
      timeout: 3s
      retries: 5
      start_period: 5s
  kafka-connect:
    image: confluentinc/cp-kafka-connect:7.3.2
    hostname: kafka-connect
    container_name: kafka-connect
    ports:
      - "8083:8083"
    environment:
      CONNECT_BOOTSTRAP_SERVERS: "redpanda-0:19092"
      CONNECT_REST_PORT: 8083
      CONNECT_GROUP_ID: compose-connect-group
      CONNECT_CONFIG_STORAGE_TOPIC: docker-connect-configs
      CONNECT_OFFSET_STORAGE_TOPIC: docker-connect-offsets
      CONNECT_STATUS_STORAGE_TOPIC: docker-connect-status
      CONNECT_KEY_CONVERTER: io.confluent.connect.avro.AvroConverter
      CONNECT_KEY_CONVERTER_SCHEMA_REGISTRY_URL: 'http://redpanda-0:8081'
      CONNECT_VALUE_CONVERTER: io.confluent.connect.avro.AvroConverter
      CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL: 'http://redpanda-0:8081'
      CONNECT_INTERNAL_KEY_CONVERTER: "org.apache.kafka.connect.json.JsonConverter"
      CONNECT_INTERNAL_VALUE_CONVERTER: "org.apache.kafka.connect.json.JsonConverter"
      CONNECT_REST_ADVERTISED_HOST_NAME: "kafka-connect"
      CONNECT_LOG4J_ROOT_LOGLEVEL: "INFO"
      CONNECT_LOG4J_LOGGERS: "org.apache.kafka.connect.runtime.rest=WARN,org.reflections=ERROR"
      CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR: "1"
      CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR: "1"
      CONNECT_STATUS_STORAGE_REPLICATION_FACTOR: "1"
      CONNECT_PLUGIN_PATH: '/usr/share/java,/etc/kafka-connect/jars,/usr/share/confluent-hub-components'
    volumes:
      - ./connectors:/etc/kafka-connect/jars/
    depends_on:
      redpanda-0:
        condition: service_healthy
      conduktor-gateway:
        condition: service_healthy
    command:
      - bash
      - -c
      - |
        confluent-hub install --no-prompt debezium/debezium-connector-mysql:latest
        confluent-hub install --no-prompt confluentinc/kafka-connect-datagen:0.4.0
        /etc/confluent/docker/run
      
  # Conduktor comes with its Gateway, a Kafka proxy bringing many security and governance features.
  # In this get started, Gateway uses Redpanda as its backend Kafka cluster.
  # https://docs.conduktor.io/gateway/
  conduktor-gateway:
    image: conduktor/conduktor-gateway:3.2.0
    hostname: conduktor-gateway
    container_name: conduktor-gateway
    environment:
      KAFKA_BOOTSTRAP_SERVERS: redpanda-0:9092
    ports:
      - "8888:8888"
    healthcheck:
      test: curl localhost:8888/health
      interval: 5s
      retries: 25
    depends_on:
      redpanda-0:
        condition: service_healthy
  # As this is a get started, we want to bring some life to the cluster to demonstrate the value of Conduktor.
  # This is totally optional and only used for this purpose. Do not use it in production.
  conduktor-data-generator:
    image: conduktor/conduktor-data-generator:0.5
    container_name: conduktor-data-generator
    environment:
      KAFKA_BOOTSTRAP_SERVERS: conduktor-gateway:6969
      KAFKA_SCHEMA_REGISTRY_URL: http://redpanda-0:8081
      GATEWAY_ADMIN_API: http://conduktor-gateway:8888
    restart: on-failure
    depends_on:
      redpanda-0:
        condition: service_healthy
      conduktor-gateway:
        condition: service_healthy
volumes:
  pg_data: {}
  conduktor_data: {}
  redpanda-0: {}
```

</details>

## Bash script for promtail setup 

<details>
<summary> promtail.sh </summary>

  ```shell
# Change localhost to Loki server IP
#!/bin/bash

sudo apt-get update
sudo apt install unzip -y
curl -s https://api.github.com/repos/grafana/loki/releases/latest | grep browser_download_url |  cut -d '"' -f 4 | grep promtail-linux-amd64.zip | wget -i -

unzip promtail-linux-amd64.zip

sudo mv promtail-linux-amd64 /usr/local/bin/promtail

promtail --version

sudo tee /etc/promtail-local-config.yaml << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://52.91.219.126:3100/loki/api/v1/push

scrape_configs:
- job_name: system
  static_configs:
  - targets:
      - localhost
    labels:
      job: kafkalogs
      __path__: /var/lib/docker/containers/d6d232b2312f594dcc6b191089ac8f3740897b252e7fd2b04be6a1234d7bbf83/d6d232b2312f594dcc6b191089ac8f3740897b252e7fd2b04be6a1234d7bbf83-json.log
EOF

sudo tee /etc/systemd/system/promtail.service <<EOF
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail --config.file=/etc/promtail-local-config.yaml

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize the new service, start and enable Promtail service
sudo systemctl daemon-reload
sudo systemctl start promtail.service
sudo systemctl enable promtail.service

echo "Promtail installation and service setup completed."

```

</details>

## Bash script for Grafana setup 

<details> 
<summary> grafana.sh </summary>

```shell
#!/bin/bash


sudo apt-get update

sudo apt-get install -y apt-transport-https
sudo apt-get install -y software-properties-common wget
sudo wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

sudo apt-get update
sudo apt-get install grafana -y
sudo /bin/systemctl enable grafana-server
sudo /bin/systemctl restart grafana-server
sudo /bin/systemctl status grafana-server
echo "Grafana installation completed"

```
</details>

## Bash script for loki 

<details> 
<summary> loki.sh </summary>

```shell
#!/bin/bash

# Update package lists
sudo apt-get update

# Fetch the latest Loki version
LOKI_VERSION=$(curl -s "https://api.github.com/repos/grafana/loki/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')

# Create Loki directory
sudo mkdir -p /opt/loki

# Download Loki and the configuration file
sudo wget -qO /opt/loki/loki.gz "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip"
sudo gunzip /opt/loki/loki.gz
sudo chmod a+x /opt/loki/loki

# Create a symlink to /usr/local/bin for easier execution
sudo ln -s /opt/loki/loki /usr/local/bin/loki

# Download Loki's local config file
sudo wget -qO /opt/loki/loki-local-config.yaml "https://raw.githubusercontent.com/grafana/loki/v${LOKI_VERSION}/cmd/loki/loki-local-config.yaml"

# Create a systemd service for Loki
sudo tee /etc/systemd/system/loki.service > /dev/null <<EOF
[Unit]
Description=Loki log aggregation system
After=network.target

[Service]
ExecStart=/opt/loki/loki -config.file=/opt/loki/loki-local-config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon to recognize the new service
sudo systemctl daemon-reload

# Enable Loki service to start on boot
sudo systemctl enable loki.service

# Start Loki service
sudo systemctl start loki.service

# Check the status of Loki service
sudo systemctl status loki.service
```
</details>

## Visualizing the kafka logs 

For visualizing the logs of kafka on grafana you need to make some configuration changes in the ```promtail.sh``` file. 

In clients attribute mention the URL for loki server. 

``` 
clients:
  - url: <public_ip_address_of loki_server:port>/loki/api/v1/push
```

In scrape_configs mention the job name and path of your kafka container logs.

```
scrape_configs:
- job_name: system
  static_configs:
  - targets:
      - localhost
    labels:
      job: <job_name>
      __path__: <path_of_kafka_containers_logs>
EOF
```

- Run the scripts. 

![image](https://github.com/user-attachments/assets/4c781c67-746c-4d04-b97d-c9dafd357178)


- Once all the services are up login to your Grafana UI. 
- In Datasource add Loki as datasource and mention the URL of Loki server, in my case its on the same server as the grafana so I have mentione ``` http://localhost:3100 ```.
- After adding the datasource Save and Test the configurations. 
- Once its tested, Create a Dashboard and add the datasource you just configured. 
- In Dashboard configure the Job Name. 
- For logs choose Table as the visualization and now you can see the kafka container logs on the Dashboard. 


