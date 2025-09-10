# base
FROM lockhost-runtime

# pip
COPY apk/repositories.serve /etc/apk/repositories
RUN apk add --no-cache py3-pip=23.1.2-r0

# py packages
WORKDIR /app
COPY python/requirements.txt .
RUN pip install -r requirements.txt

# py sources
COPY python python
RUN mv python/* .
RUN chmod +x app.sh

# rm trash
RUN rm -rf /root/.cache
RUN rm -f /lib/apk/db/scripts.tar
RUN rm -rf /var/cache

# nitro needs this
RUN find /usr/lib/python3.11/site-packages/ -name "*.pyc" -delete
RUN find /usr/lib/python3.11/site-packages/ -type d -name "__pycache__" -exec rm -r {} +

# nitro needs this
ARG PROD=true
ENV PROD=${PROD}
RUN if [ "$PROD" = "true" ]; then \
      chmod -R ug+w,o-rw /runtime /app && \
      chmod ug+w,o-rw /etc/apk/repositories && \
      find / -exec touch -t 197001010000.00 {} + || true && \
      find / -exec touch -h -t 197001010000.00 {} + || true; \
    fi

# nitro needs this
RUN cd /app

ENTRYPOINT ["/app/app.sh"]
