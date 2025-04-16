# Dockerfile to build Flask App
FROM python:3.9-slim
WORKDIR /app
COPY . /app
# Install dependencies from requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
EXPOSE 5000
CMD ["python", "app.py"]
