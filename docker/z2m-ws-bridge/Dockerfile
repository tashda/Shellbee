FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir paho-mqtt websockets
COPY bridge.py healthcheck.py .
CMD ["python", "-u", "bridge.py"]
