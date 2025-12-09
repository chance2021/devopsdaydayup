# First stage: complete build environment
FROM maven:3.6.3-openjdk-17 AS builder
# add pom.xml and source code
ADD ./pom.xml pom.xml
ADD ./src src/
# package jar
RUN mvn clean package
# Second stage: minimal runtime environment
From maven:3.6.3-openjdk-17
# copy jar from the first stage
COPY --from=builder target/file-monitor-1.0.0.jar file-monitor-1.0.0.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "file-monitor-1.0.0.jar"]
#CMD ["/config/game.properties", "3"]
