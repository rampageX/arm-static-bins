Source: [Nginx](https://www.nginx.com/)

results:

	file ./nginx
	./nginx: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped


```
./nginx -V
nginx version: nginx/1.19.4
built by gcc 9.2.0 (GCC)
built with OpenSSL 1.1.1h  22 Sep 2020
TLS SNI support enabled
configure arguments: --prefix=/opt --conf-path=/opt/etc/nginx.conf --error-log-path=/var/log/nginx.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --with-http_ssl_module --with-http_sub_module --with-http_gzip_static_module --with-http_realip_module --with-http_v2_module --with-http_realip_module --with-http_addition_module --with-http_gzip_static_module --with-threads --with-poll_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt='-static -static-libgcc' --with-ld-opt=-static --with-openssl=../openssl-1.1.1h
```

```
nginx version: nginx/1.27.0
built by gcc 13.2.1 20231014 (Alpine 13.2.1_git20231014)
built with OpenSSL 3.0.14 4 Jun 2024
TLS SNI support enabled
configure arguments: --prefix=/opt/etc/nginx --conf-path=/opt/etc/nginx/nginx.conf --error-log-path=/var/log/nginx_error.log --http-log-path=/var/log/nginx_access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --with-openssl-opt='linux-armv4 --cross-compile-prefix=arm-linux-musleabi-' --with-mail --with-mail_ssl_module --with-stream --with-stream_ssl_module --with-stream_realip_module --with-stream_ssl_preread_module --with-http_ssl_module --with-http_v2_module --with-http_v3_module --with-http_realip_module --with-http_addition_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_auth_request_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-pcre-jit --with-libatomic --with-compat --with-file-aio --with-threads --with-poll_module --with-select_module --with-cc-opt='--static -static -I/root/src/armv5te_dev/include' --with-ld-opt='--static -static -Wl,--no-as-needed -L/root/src/armv5te_dev/lib -lpthread -pthread' --with-openssl=/root/src/openssl-3.0.14 --add-module=../ngx_brotli_armv5te --add-module=../nginx-dav-ext-module --add-module=../headers-more-nginx-module
```