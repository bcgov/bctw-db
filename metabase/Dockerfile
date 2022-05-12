FROM openjdk:8

#COPY src/metabase.jar /app.jar
WORKDIR /app

COPY . .

EXPOSE 3000


CMD ["java", "-jar", "src/metabase.jar"]

# FROM openjdk:8-alpine
# WORKDIR /src

# EXPOSE 3000
# ENTRYPOINT ["java", "-jar", "/app.jar"]

# FROM openjdk:8-alpine
# WORKDIR /src

# EXPOSE 3000
# ENTRYPOINT ["java", "-jar", "/app.jar"]
