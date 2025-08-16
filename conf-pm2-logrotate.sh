echo "==> 配置 pm2-logrotate 模块…"
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7
pm2 set pm2-logrotate:compress true
pm2 set pm2-logrotate:worker_interval 300

# 确认配置已更新（可选）
echo "==> 当前 pm2-logrotate 配置："
pm2 config pm2-logrotate
