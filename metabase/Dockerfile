FROM openjdk:8

COPY metabase.jar /app
WORKDIR /app

EXPOSE 3000

ENTRYPOINT ["java","/app"]

CMD ["java -jar metabase.jar"]