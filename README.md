# Docker_Image_FlaskAPI_with_Redis
建立一個環境具備 Redis、uwsgi、Nginx 環境的 Python Flask API

# 環境說明
本 Image 參考 bitnami/redis 與 tiangolo/uwsgi-nginx-flask 而設計<br>
關於 Redis 的密碼，可在 docker-compose 檔案內，加入一環境變數 "REDIS_PASSWORD"，該變數內容設定為 Redis 密碼即可
