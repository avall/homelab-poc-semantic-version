FROM eclipse-temurin:25-jre

RUN groupadd --system app && useradd --system --gid app --no-create-home app

WORKDIR /app
COPY hello-service/target/hello-service-*.jar /app/app.jar

USER app
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
