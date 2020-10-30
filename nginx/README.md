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