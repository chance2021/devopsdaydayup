package com.example.bookapi.config;

import com.azure.cosmos.*;
import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.core.credential.TokenCredential;
import com.azure.core.credential.TokenRequestContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class CosmosDBConfig {

    private static final Logger logger = LoggerFactory.getLogger(CosmosDBConfig.class);

    @Value("${azure.cosmos.uri}")
    private String cosmosUri;

    @Value("${azure.cosmos.database}")
    private String databaseName;

    @Value("${azure.cosmos.container}")
    private String containerName;

    @Bean
    public CosmosClient cosmosClient() {
        try {
            TokenCredential credential = new DefaultAzureCredentialBuilder().build();
            // Test the credential (ensure it works)
            credential.getToken(new TokenRequestContext().addScopes("https://cosmos.azure.com/.default")).block();
            logger.info("Using Managed Identity for Cosmos DB authentication.");

            return new CosmosClientBuilder()
                    .endpoint(cosmosUri)
                    .credential(credential)
                    .consistencyLevel(ConsistencyLevel.EVENTUAL)
                    .buildClient();
        } catch (Exception e) {
            logger.error("Failed to authenticate with Managed Identity.", e);
            throw new RuntimeException("Unable to authenticate Cosmos DB client.", e);
        }
    }

    @Bean
    public CosmosContainer cosmosContainer(CosmosClient cosmosClient) {
        return cosmosClient.getDatabase(databaseName).getContainer(containerName);
    }
}