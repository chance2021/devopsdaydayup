package com.example;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.time.LocalTime;

public class CurrentTimeServer {
    public static void main(String[] args) throws IOException {
        // Create an HTTP server listening on port 80
        HttpServer server = HttpServer.create(new InetSocketAddress(80), 0);

        // Define the handler for the root path
        server.createContext("/", exchange -> {
            String response = "Current Time: " + LocalTime.now();
            exchange.sendResponseHeaders(200, response.getBytes().length);
            OutputStream os = exchange.getResponseBody();
            os.write(response.getBytes());
            os.close();
        });

        // Start the server
        System.out.println("Server is running...");
        server.start();
    }
}