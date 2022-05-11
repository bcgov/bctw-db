# FROM openjdk:8

# COPY metabase.jar /app.jar

# EXPOSE 3000

# CMD ["java", "-jar", "/app.jar"]

FROM openjdk:8-alpine

VOLUME /tmp

ARG JAR_FILE

COPY ${JAR_FILE} src/metabase.jar
# COPY src/metabase.jar /app.jar

ENTRYPOINT ["java", "-jar", "src/metabase.jar"]
