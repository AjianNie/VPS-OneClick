cd /root/uptime-kuma

cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
    {
      name: 'uptime-kuma',
      script: 'server/server.js',
      env: {
        PORT: 30001
      }
    }
  ]
}
EOF

pm2 start ecosystem.config.js
pm2 save
