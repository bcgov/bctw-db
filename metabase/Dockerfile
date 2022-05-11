FROM openjdk:8

# WORKDIR /app
# COPY metabase.jar /app
# COPY src/ /app/src

# ADD metabase.jar metabase.jar

COPY metabase.jar /app.jar

EXPOSE 3000

#CMD ["java -jar metabase.jar"]
CMD ["java", "-jar", "/app.jar"]