# docker run -p 8080:8080 --name hello-world hello-world:develop
FROM python:3.8-alpine

RUN mkdir /app

COPY . /app

WORKDIR /app

RUN pip install -r requirements.txt

EXPOSE 8080

CMD ["python", "app.py"]

