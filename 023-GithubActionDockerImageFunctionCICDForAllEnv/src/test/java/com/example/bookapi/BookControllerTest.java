package com.example.bookapi.controller;

import com.example.bookapi.model.Book;
import com.example.bookapi.model.Comment;
import com.example.bookapi.repository.BookRepository;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.ArrayList;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(BookController.class)
public class BookControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private BookRepository bookRepository;

    @Test
    public void testGetBookName() throws Exception {
        Book mockBook = new Book("123", "Test Book", null);
        when(bookRepository.findBookByNumber("123")).thenReturn(mockBook);

        mockMvc.perform(get("/book/123"))
                .andExpect(status().isOk())
                .andExpect(content().string("Test Book"));
    }

    @Test
    public void testGetBookNotFound() throws Exception {
        when(bookRepository.findBookByNumber("999")).thenReturn(null);

        mockMvc.perform(get("/book/999"))
                .andExpect(status().isNotFound());
    }

    @Test
    public void testSaveBook() throws Exception {
        String bookJson = "{\"number\": \"123\", \"name\": \"New Book\", \"comments\": []}";

        mockMvc.perform(post("/book")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookJson))
                .andExpect(status().isOk())
                .andExpect(content().string("Book saved successfully!"));

        verify(bookRepository).save(any(Book.class));
    }

    @Test
    public void testAddCommentToBook() throws Exception {
        Book book = new Book("123", "Test Book", new ArrayList<>());
        when(bookRepository.findBookByNumber("123")).thenReturn(book);

        String commentJson = "{\"text\": \"Great book!\"}";

        mockMvc.perform(post("/book/123/comment")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(commentJson))
                .andExpect(status().isOk())
                .andExpect(content().string("Comment added successfully!"));

        verify(bookRepository).findBookByNumber("123");
        verify(bookRepository).save(book);
    }
}