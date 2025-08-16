# Automatic Loki Logging Setup with Grafana Alloy

## How It Works

**Grafana Alloy** automatically collects logs from Docker containers using the official Docker socket approach with label-based discovery. Here's what happens:

### 1. **Label-Based Discovery**
- Apps using the `homelab-app` role get a `monitoring.logs.enabled=true` label
- Alloy discovers containers via Docker socket (`/var/run/docker.sock`)
- Only containers with the monitoring label get their logs collected
- Automatic metadata extraction (container names, labels, etc.)

### 2. **What Gets Logged**
- Docker container logs (stdout/stderr) - only from labeled containers
- Structured JSON logs with proper timestamps
- Container metadata (name, labels, service_name, etc.)
- System logs from `/var/log`

### 3. **Selective Monitoring**
The monitoring is controlled by the `homelab_app_monitoring_enabled` variable:
```yaml
# Enable monitoring (default: true)
homelab_app_monitoring_enabled: true

# Disable monitoring for specific apps
homelab_app_monitoring_enabled: false
```

## Why Grafana Alloy?

- ✅ **Future-proof**: Grafana's recommended replacement for Promtail
- ✅ **Unified agent**: Handles both metrics and logs efficiently
- ✅ **Better performance**: More efficient resource usage
- ✅ **Active development**: Regular updates and long-term support
- ✅ **EOL protection**: Promtail EOL is scheduled for 2026
- ✅ **Official approach**: Based on [official Docker monitoring documentation](https://grafana.com/docs/alloy/latest/monitor/monitor-docker-containers/)
- ✅ **Secure**: Label-based filtering for selective monitoring
- ✅ **Robust**: Proper container lifecycle handling via Docker socket

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Alloy App     │    │  Grafana App    │    │   Your Apps     │
│                 │    │                 │    │                 │
│ • Docker Socket │    │ • Visualization │    │ • qbittorrent   │
│ • Container     │    │ • Dashboards    │    │ • jellyfin      │
│   Discovery     │    │ • Port 3000     │    │ • etc...        │
│ • Alloy UI      │    │                 │    │                 │
│ • Port 12345    │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │     Docker Socket         │
                    │                           │
                    │ /var/run/docker.sock      │
                    │ (Container Discovery)     │
                    └───────────────────────────┘
```

## Access Points

### **Alloy UI**
- **URL**: `http://alloy.yourdomain.com`
- **Port**: 12345
- **Features**: Configuration management, pipeline visualization, health monitoring

### **Grafana**
- **URL**: `http://grafana.yourdomain.com`
- **Port**: 3000
- **Features**: Log visualization, dashboards, alerting

## Viewing Logs in Grafana

1. **Access Grafana**: `http://grafana.yourdomain.com`
2. **Go to Explore**: Click the compass icon in the sidebar
3. **Select Loki**: Choose the Loki datasource
4. **Query Logs**: Use LogQL queries like:
   - `{job="alloy"}` - All logs collected by Alloy
   - `{service_name="qbittorrent"}` - Specific app logs
   - `{job="alloy"} |= "error"` - Error logs only

## Example Queries

```logql
# All logs from qbittorrent
{service_name="qbittorrent"}

# Error logs from all apps
{job="alloy"} |= "error"

# Recent logs from the last hour
{job="alloy"} | json | line_format "{{.log}}"

# Logs containing specific text
{job="alloy"} |= "download"

# System logs
{job="alloy", platform="system"}

# Docker container logs only
{job="alloy", platform="docker"}
```

## Disabling for Specific Apps

If you want to disable monitoring for a specific app, add this to your playbook:

```yaml
- name: "Deploy My App"
  hosts: servarr
  roles:
    - homelab-app
  vars:
    homelab_app_name: myapp
    homelab_app_monitoring_enabled: false  # Disable monitoring
    # ... other vars
```

## How Log Collection Works

Alloy automatically collects logs from Docker containers by:

1. **Container discovery**: Uses `discovery.docker` to find containers via Docker socket
2. **Label filtering**: Uses `discovery.relabel` to filter containers with `monitoring.logs.enabled=true`
3. **Log collection**: Uses `loki.source.docker` to collect logs from filtered containers
4. **Metadata extraction**: Automatically extracts container names, labels, and other metadata
5. **Sending to Loki**: Forwards processed logs to Loki for storage

**Only containers with the monitoring label get logged** - giving you full control over what gets monitored!

## Alloy Configuration

The Alloy configuration uses the official `.alloy` file format and is located at:
- **Config file**: `config/alloy-config.alloy`
- **Docker image**: `grafana/alloy:v1.10.1`
- **Port**: 12345 (accessible via Traefik)
- **UI**: Available at `http://alloy.yourdomain.com` for debugging

The configuration follows the [official Docker monitoring documentation](https://grafana.com/docs/alloy/latest/monitor/monitor-docker-containers/) and includes:
- **Container discovery**: `discovery.docker` for finding containers
- **Label filtering**: `discovery.relabel` for selective monitoring
- **Log collection**: `loki.source.docker` for collecting container logs
- **System logs**: `loki.source.file` for host system logs
- **Log writing**: `loki.write` component to send to Loki

## Reloading Configuration

To reload the Alloy configuration without restarting the container:

```bash
curl -X POST http://alloy.yourdomain.com/-/reload
```

This allows you to update the configuration without downtime.

## Deployment

Deploy both apps separately:

```bash
# Deploy Grafana + Loki
ansible-playbook -i inventories/prod playbooks/grafana.yaml

# Deploy Alloy
ansible-playbook -i inventories/prod playbooks/alloy.yaml
```

## Benefits of This Approach

✅ **Selective monitoring**: Only containers with the label get monitored  
✅ **Security**: Fine-grained control over what gets logged  
✅ **Performance**: Only processes logs from containers you care about  
✅ **Robust**: Proper container lifecycle handling via Docker socket  
✅ **Official**: Based on Grafana's recommended approach  
✅ **Metadata**: Automatic extraction of container names and labels  
✅ **Maintainability**: Easy to enable/disable per app  
