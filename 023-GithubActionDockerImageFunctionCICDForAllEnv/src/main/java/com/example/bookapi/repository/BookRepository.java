package com.example.bookapi.repository;

import com.azure.cosmos.CosmosContainer;
import com.azure.cosmos.models.CosmosQueryRequestOptions;
import com.azure.cosmos.models.SqlParameter;
import com.azure.cosmos.models.SqlQuerySpec;
import com.azure.cosmos.util.CosmosPagedIterable;
import com.example.bookapi.model.Book;
import org.springframework.stereotype.Repository;

import java.util.Arrays;

@Repository
public class BookRepository {

    private final CosmosContainer cosmosContainer;

    public BookRepository(CosmosContainer cosmosContainer) {
        this.cosmosContainer = cosmosContainer;
    }

    public Book findBookByNumber(String number) {
        String query = "SELECT * FROM c WHERE c.number = @number";

        SqlQuerySpec querySpec = new SqlQuerySpec(query)
                .setParameters(Arrays.asList(new SqlParameter("@number", number)));

        CosmosQueryRequestOptions options = new CosmosQueryRequestOptions();

        CosmosPagedIterable<Book> result = cosmosContainer.queryItems(querySpec, options, Book.class);

        return result.stream().findFirst().orElse(null);
    }

    public void save(Book book) {
        cosmosContainer.upsertItem(book);
    }
}