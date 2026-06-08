{
  "common": {
    "idle_timeout": 15,
    "upload_mode": 0,
    "temp_path": "/var/lib/sftpgo/tmp"
  },
  "httpd": {
    "bindings": [
      {
        "address": "127.0.0.1",
        "port": 8080,
        "enable_web_admin": true,
        "enable_web_client": false,
        "hide_login_url": 0
      }
    ]
  },
  "sftpd": {
    "bindings": [
      {
        "address": "0.0.0.0",
        "port": ${sftp_port},
        "apply_proxy_config": true
      }
    ]
  },
  "data_provider": {
    "driver": "sqlite",
    "name": "/var/lib/sftpgo/sftpgo.db",
    "create_default_admin": true
  },
  "telemetry": {
    "bind_port": 0
  }
}
