# FROM openjdk:8

# COPY metabase.jar /app.jar

# EXPOSE 3000

# CMD ["java", "-jar", "/app.jar"]

FROM openjdk:8-alpine

COPY src/metabase.jar /app.jar

EXPOSE 3000

CMD ["java", "-jar", "/app.jar"]