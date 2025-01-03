# Step 1: Use the latest Maven image with OpenJDK
FROM maven:3.8-openjdk-17 AS build

# Set the working directory
WORKDIR /app

# Copy the pom.xml file and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy the source code into the container
COPY src ./src

# Build the project
RUN mvn package -DskipTests

# Step 2: Use a lightweight OpenJDK image to run the application
FROM openjdk:17-jdk-slim

# Set the working directory
WORKDIR /app

# Copy the built JAR file from the build stage
COPY --from=build /app/target/CurrentTimeProject-1.0-SNAPSHOT.jar app.jar

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
