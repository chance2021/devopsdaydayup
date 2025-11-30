package com.example.bookapi.controller;

import com.example.bookapi.model.Book;
import com.example.bookapi.model.Comment;
import com.example.bookapi.repository.BookRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;

@RestController
@RequestMapping("/book")
public class BookController {

    private final BookRepository bookRepository;

    public BookController(BookRepository bookRepository) {
        this.bookRepository = bookRepository;
    }

    @GetMapping("/{number}")
    public ResponseEntity<String> getBookName(@PathVariable String number) {
        Book book = bookRepository.findBookByNumber(number);
        if (book == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(book.getName());
    }

    @PostMapping
    public ResponseEntity<String> saveBook(@RequestBody Book book) {
        bookRepository.save(book);
        return ResponseEntity.ok("Book saved successfully!");
    }

    @PostMapping("/{number}/comment")
    public ResponseEntity<String> addCommentToBook(@PathVariable String number, @RequestBody Comment comment) {
        Book book = bookRepository.findBookByNumber(number);
        if (book == null) {
            return ResponseEntity.notFound().build();
        }
        if (book.getComments() == null) {
            book.setComments(new ArrayList<>());
        }
        book.getComments().add(comment);
        bookRepository.save(book);
        return ResponseEntity.ok("Comment added successfully!");
    }
}