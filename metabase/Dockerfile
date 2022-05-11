FROM openjdk:8

COPY metabase.jar /app
WORKDIR /app

EXPOSE 3000

ENTRYPOINT ["java","metabase.jar"]

CMD ["java -jar metabase.jar"]