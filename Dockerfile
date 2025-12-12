# ---- Stage 1: builder ----
FROM python:3.11-slim AS builder
WORKDIR /app

# Install build deps for some Python wheels (kept minimal)
RUN apt-get update && apt-get install -y --no-install-recommends build-essential ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Copy requirements and install into a local vendor directory to copy into runtime
COPY requirements.txt .
RUN python -m pip install --upgrade pip setuptools wheel \
  && python -m pip install --no-cache-dir --target /app/vendor -r requirements.txt

# Copy application code and scripts
COPY app ./app
COPY student_private.pem student_public.pem instructor_public.pem ./
COPY scripts ./scripts
COPY cron/totp_cron /etc/cron.d/totp_cron

# ---- Stage 2: runtime ----
FROM python:3.11-slim AS runtime
LABEL maintainer="student"
ENV TZ=UTC
ENV DATA_DIR=/data
WORKDIR /srv/app

# Install runtime system deps (cron, tzdata)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    cron tzdata ca-certificates \
  && ln -snf /usr/share/zoneinfo/UTC /etc/localtime && echo "UTC" > /etc/timezone \
  && rm -rf /var/lib/apt/lists/*

# Create directories for persistent volumes and logs
RUN mkdir -p /data /cron /srv/app && chmod 0755 /data /cron

# Copy python packages installed in builder
COPY --from=builder /app/vendor /srv/app/vendor
ENV PYTHONPATH=/srv/app/vendor

# Copy app code, keys, scripts, cron config
COPY --from=builder /app/app ./app
COPY --from=builder /app/student_private.pem ./student_private.pem
COPY --from=builder /app/student_public.pem ./student_public.pem
COPY --from=builder /app/instructor_public.pem ./instructor_public.pem
COPY --from=builder /app/scripts ./scripts

# Copy cron file
COPY --from=builder /etc/cron.d/totp_cron /etc/cron.d/totp_cron

# FIX: remove Windows CRLF and set correct permissions for cron file
RUN sed -i 's/\r$//' /etc/cron.d/totp_cron && chmod 0644 /etc/cron.d/totp_cron

# FIX: remove CRLF from scripts and make executable
RUN sed -i 's/\r$//' ./scripts/run_cron.sh && chmod +x ./scripts/run_cron.sh
RUN sed -i 's/\r$//' ./scripts/run_uvicorn.sh && chmod +x ./scripts/run_uvicorn.sh

# Expose API port
EXPOSE 8080

# Volumes needed by evaluator
VOLUME ["/data", "/cron"]

# Start cron in background then web server in foreground
CMD ["bash", "-c", "service cron start && exec  ./scripts/run_uvicorn.sh"]
