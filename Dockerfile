# Use an official Java runtime as a parent image
FROM openjdk:latest

# Who is responsible for this project?
MAINTAINER Manuele Vaccari <manuele.vaccari@gmail.com>

# Volumes to use which stay between updates
VOLUME ["/data"]

# Set the working directory to /app
WORKDIR /app

# Copy the source's directory contents into the container at /app
COPY ./src /app
RUN chmod +x *.sh

# Make port 25577 available to the world outside this container
EXPOSE 25577

# Run bungeecord.jar when the container launches
CMD ["./start.sh"]
