# Eclipse render worker: ffmpeg and the Python picture libraries, plus an SSH
# door that accepts exactly one key. It contains no application source, font,
# model, credential or footage; each job brings what it needs and takes its
# result back.
# Debian's ffmpeg build already lists the NVIDIA encoder, which works when the
# host passes in a card that has an encoder chip.
FROM python:3.12-slim-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg libsndfile1 libgomp1 libglib2.0-0 ca-certificates \
    openssh-server rsync proot tini \
    && rm -rf /var/lib/apt/lists/* /etc/ssh/ssh_host_*
# Pillow draws the captions: it is kept at the version the studio renders with,
# so the same job gives the same picture in both places.
RUN python -m pip install --no-cache-dir \
    numpy==2.2.6 Pillow==11.1.0 opencv-python-headless==4.12.0.88 \
    scipy==1.15.3
ARG WORKER_VERSION=0.1.0
RUN echo "eclipse-remote-worker:${WORKER_VERSION}" > /etc/eclipse-worker-image
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,video,utility
COPY entrypoint.sh /usr/local/bin/eclipse-worker
RUN chmod 755 /usr/local/bin/eclipse-worker
EXPOSE 22
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/eclipse-worker"]
