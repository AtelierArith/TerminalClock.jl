FROM ghcr.io/juliaregistries/tagbot:1.25.15@sha256:3602b53caa61f631030f5dbc396140ff6c3e96b372cbc0dcb33dfd7bd6b0cfd5
COPY patch_tagbot.py /tmp/patch_tagbot.py
RUN python /tmp/patch_tagbot.py
# Preserve the official image command: python -m tagbot.action.
