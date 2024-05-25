# Stage 1: Build
FROM maven:3.8.1-openjdk-11 as build

# Set the working directory in the image
WORKDIR /app

# Copy the pom.xml file
COPY pom.xml .

# Download all required dependencies into one layer
RUN mvn dependency:go-offline -B

# Copy your other files
COPY src ./src

# Build the project
RUN mvn clean package -DskipTests

# Stage 2: Application
FROM openjdk:11-jre-slim

# Set the working directory in the image
WORKDIR /app

# Copy the jar file from the build stage
COPY --from=build /app/target/helloworld-1.0-SNAPSHOT.jar ./app.jar

# Run the jar file
ENTRYPOINT ["java","-jar","app.jar"]
